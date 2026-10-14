import '../../../core/notifications/notification_service.dart';
import '../domain/medication_models.dart';
import '../domain/medication_repository.dart';
import 'schedule_engine.dart';

class MedicationReminderService {
  factory MedicationReminderService({
    required MedicationRepository repository,
    required NotificationScheduler scheduler,
    ScheduleEngine engine = const ScheduleEngine(),
  }) => MedicationReminderService._(repository, scheduler, engine);

  const MedicationReminderService._(
    this._repository,
    this._scheduler,
    this._engine,
  );

  final MedicationRepository _repository;
  final NotificationScheduler _scheduler;
  final ScheduleEngine _engine;

  /// Reconstructs a bounded rolling window. Android persists these alarms and
  /// restores them after reboot/app update; app startup rebuilds the window as
  /// a second line of defence. iOS has a 64 pending-notification limit.
  Future<int> rebuild({
    required List<MedicationPlanDetails> plans,
    DateTime? now,
    int maximumPending = 60,
  }) async {
    await _scheduler.cancelAll();
    final start = (now ?? DateTime.now()).toUtc();
    final candidates = <({MedicationPlanDetails details, DateTime time})>[];
    for (final details in plans) {
      if (!details.plan.active ||
          details.medication.status != MedicationStatus.active) {
        continue;
      }
      for (final schedule in details.schedules) {
        for (final occurrence in _engine.occurrences(
          plan: details.plan,
          schedule: schedule,
          from: start,
          to: start.add(const Duration(days: 30)),
        )) {
          candidates.add((details: details, time: occurrence));
        }
      }
    }
    candidates.sort((left, right) => left.time.compareTo(right.time));
    final privacy = await _repository.loadPrivacy();
    for (final candidate in candidates.take(maximumPending)) {
      final details = candidate.details;
      final logicalId = _engine.logicalDoseId(details.plan.id, candidate.time);
      await _scheduler.schedule(
        ReminderNotification(
          id: stableNotificationId(logicalId),
          planId: details.plan.id,
          logicalDoseId: logicalId,
          medicationName: details.medication.displayName,
          doseText: details.plan.confirmedDoseText,
          scheduledAt: candidate.time,
          timezone: details.plan.timezone,
          privacy: privacy.notificationPrivacy,
        ),
      );
    }
    return candidates.length.clamp(0, maximumPending);
  }

  Future<void> handle(MedicationNotificationResponse response) async {
    switch (response.actionId) {
      case notificationActionTaken:
        await _repository.recordDose(
          planId: response.planId,
          logicalDoseId: response.logicalDoseId,
          scheduledAt: response.scheduledAt,
          action: DoseAction.taken,
          source: DoseEventSource.notificationAction,
        );
      case notificationActionSkip:
        await _repository.recordDose(
          planId: response.planId,
          logicalDoseId: response.logicalDoseId,
          scheduledAt: response.scheduledAt,
          action: DoseAction.skipped,
          source: DoseEventSource.notificationAction,
        );
      // Snooze changes notification timing only. The notification action uses
      // a conservative default; the in-app timeline offers explicit choices.
      case notificationActionSnooze:
        final details = await _repository.getPlan(response.planId);
        if (details == null) return;
        await snooze(
          details: details,
          dose: ScheduledDose(
            logicalDoseId: response.logicalDoseId,
            planId: response.planId,
            medicationName: details.medication.displayName,
            doseText: details.plan.confirmedDoseText,
            scheduledAt: response.scheduledAt,
            action: DoseAction.notRecorded,
          ),
          duration: const Duration(minutes: 10),
        );
      case notificationActionOpen:
        return;
      default:
        return;
    }
  }

  Future<void> snooze({
    required MedicationPlanDetails details,
    required ScheduledDose dose,
    required Duration duration,
  }) async {
    if (duration < const Duration(minutes: 5) ||
        duration > const Duration(hours: 2)) {
      throw ArgumentError('Choose a snooze between 5 minutes and 2 hours.');
    }
    final privacy = await _repository.loadPrivacy();
    final snoozedAt = DateTime.now().toUtc().add(duration);
    await _scheduler.schedule(
      ReminderNotification(
        id: stableNotificationId('${dose.logicalDoseId}:snooze:$snoozedAt'),
        planId: dose.planId,
        logicalDoseId: dose.logicalDoseId,
        medicationName: dose.medicationName,
        doseText: dose.doseText,
        scheduledAt: snoozedAt,
        timezone: details.plan.timezone,
        privacy: privacy.notificationPrivacy,
      ),
    );
  }

  int stableNotificationId(String value) {
    var hash = 0x811c9dc5;
    for (final codeUnit in value.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * 0x01000193) & 0x7fffffff;
    }
    return hash;
  }
}
