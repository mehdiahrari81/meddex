import 'package:drift/native.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediexplain/core/database/app_database.dart';
import 'package:mediexplain/core/notifications/notification_service.dart';
import 'package:mediexplain/features/medications/application/medication_reminder_service.dart';
import 'package:mediexplain/features/medications/data/local_medication_repository.dart';
import 'package:mediexplain/features/medications/domain/medication_models.dart';

void main() {
  late AppDatabase database;
  late LocalMedicationRepository repository;
  late _NotificationAdapter adapter;
  final now = DateTime.utc(2026, 8, 13, 7);

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    repository = LocalMedicationRepository(
      database: database,
      clock: () => now,
    );
    adapter = _NotificationAdapter();
  });

  tearDown(() => database.close());

  Future<MedicationPlanDetails> createPlan() => repository.createPlan(
    CreateMedicationPlanRequest(
      sourceType: MedicationSourceType.manualEntry,
      displayName: 'Private medicine',
      confirmedDoseText: '1 tablet',
      confirmedFrequency: 'once daily',
      confirmedInstruction: 'User entered instruction',
      startDate: now,
      timezone: 'UTC',
      scheduleType: MedicationScheduleType.onceDaily,
      reminderTimes: const [8 * 60],
    ),
  );

  test('permission denied and OS-disabled states prevent scheduling', () async {
    final reminder = _reminder(now.add(const Duration(hours: 1)));
    for (final state in [
      NotificationPermissionState.denied,
      NotificationPermissionState.osDisabled,
    ]) {
      final scheduler = MedicationNotificationScheduler(
        adapter,
        _Permissions(state),
      );
      await expectLater(() => scheduler.schedule(reminder), throwsStateError);
    }
    expect(adapter.scheduled, isEmpty);
  });

  test(
    'granted permission falls back honestly when exact alarms are denied',
    () async {
      final scheduler = MedicationNotificationScheduler(
        adapter,
        _Permissions(NotificationPermissionState.granted, exact: false),
      );
      await scheduler.schedule(_reminder(now.add(const Duration(hours: 1))));
      expect(adapter.scheduled, hasLength(1));
      expect(adapter.exact, [false]);
    },
  );

  test(
    'restart reconstruction clears stale alarms and rebuilds active plan',
    () async {
      final details = await createPlan();
      final service = MedicationReminderService(
        repository: repository,
        scheduler: MedicationNotificationScheduler(
          adapter,
          _Permissions(NotificationPermissionState.granted),
        ),
      );
      final count = await service.rebuild(plans: [details], now: now);
      expect(count, greaterThan(0));
      expect(adapter.cancelAllCount, 1);
      expect(adapter.scheduled.first.logicalDoseId, contains(details.plan.id));

      adapter.scheduled.clear();
      await service.rebuild(plans: [details], now: now);
      expect(adapter.cancelAllCount, 2);
      expect(adapter.scheduled, isNotEmpty);
    },
  );

  test('completed doses are not scheduled again after a restart', () async {
    final details = await createPlan();
    final service = MedicationReminderService(
      repository: repository,
      scheduler: MedicationNotificationScheduler(
        adapter,
        _Permissions(NotificationPermissionState.granted),
      ),
    );
    final scheduled = DateTime.utc(2026, 8, 13, 8);
    final logicalId = '${details.plan.id}:${scheduled.toIso8601String()}';
    await repository.recordDose(
      planId: details.plan.id,
      logicalDoseId: logicalId,
      scheduledAt: scheduled,
      action: DoseAction.skipped,
      source: DoseEventSource.app,
    );
    await service.rebuild(plans: [details], now: now);
    expect(
      adapter.scheduled.any((reminder) => reminder.logicalDoseId == logicalId),
      isFalse,
    );
    expect(adapter.scheduled, isNotEmpty);
  });

  test(
    'tap does not log; taken and skip actions are explicit and idempotent',
    () async {
      final details = await createPlan();
      final service = MedicationReminderService(
        repository: repository,
        scheduler: MedicationNotificationScheduler(
          adapter,
          _Permissions(NotificationPermissionState.granted),
        ),
      );
      final scheduledAt = now.add(const Duration(hours: 1));
      final base = MedicationNotificationResponse(
        actionId: notificationActionOpen,
        planId: details.plan.id,
        logicalDoseId: 'dose',
        scheduledAt: scheduledAt,
      );
      await service.handle(base);
      expect(await repository.doseHistory(), isEmpty);
      await service.handle(
        MedicationNotificationResponse(
          actionId: notificationActionTaken,
          planId: base.planId,
          logicalDoseId: base.logicalDoseId,
          scheduledAt: scheduledAt,
        ),
      );
      await service.handle(
        MedicationNotificationResponse(
          actionId: notificationActionTaken,
          planId: base.planId,
          logicalDoseId: base.logicalDoseId,
          scheduledAt: scheduledAt,
        ),
      );
      expect(await repository.doseHistory(), hasLength(1));
      await service.handle(
        MedicationNotificationResponse(
          actionId: notificationActionSkip,
          planId: base.planId,
          logicalDoseId: base.logicalDoseId,
          scheduledAt: scheduledAt,
        ),
      );
      expect(await repository.doseHistory(), hasLength(2));
    },
  );

  test('snooze creates a new alarm without changing plan schedule', () async {
    final details = await createPlan();
    final service = MedicationReminderService(
      repository: repository,
      scheduler: MedicationNotificationScheduler(
        adapter,
        _Permissions(NotificationPermissionState.granted),
      ),
    );
    await service.handle(
      MedicationNotificationResponse(
        actionId: notificationActionSnooze,
        planId: details.plan.id,
        logicalDoseId: 'dose',
        scheduledAt: now,
      ),
    );
    expect(adapter.scheduled, hasLength(1));
    expect(
      (await repository.getPlan(details.plan.id))!.schedules.single.times,
      [480],
    );
  });
}

ReminderNotification _reminder(DateTime time) => ReminderNotification(
  id: 1,
  planId: 'plan',
  logicalDoseId: 'dose',
  medicationName: 'Medicine',
  doseText: '1 tablet',
  scheduledAt: time,
  timezone: 'UTC',
  privacy: NotificationPrivacy.privateReminder,
);

class _Permissions implements NotificationPermissionService {
  const _Permissions(this.state, {this.exact = true});
  final NotificationPermissionState state;
  final bool exact;

  @override
  Future<bool> canScheduleExactNotifications() async => exact;
  @override
  Future<bool> requestExactAlarmPermission() async => exact;
  @override
  Future<NotificationPermissionState> request() async => state;
  @override
  Future<NotificationPermissionState> status() async => state;
}

class _NotificationAdapter implements PlatformNotificationAdapter {
  final scheduled = <ReminderNotification>[];
  final exact = <bool>[];
  int cancelAllCount = 0;

  @override
  Future<void> cancel(int id) async {}
  @override
  Future<void> cancelAll() async => cancelAllCount++;
  @override
  Future<void> initialize(
    MedicationNotificationResponseHandler handler,
  ) async {}
  @override
  Future<List<PendingNotificationRequest>> pending() async => const [];
  @override
  Future<void> schedule(
    ReminderNotification reminder, {
    required bool exact,
  }) async {
    scheduled.add(reminder);
    this.exact.add(exact);
  }
}
