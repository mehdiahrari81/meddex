import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_provider.dart';
import '../../../core/notifications/notification_service.dart';
import '../../../core/logging/app_logger.dart';
import '../data/local_medication_repository.dart';
import '../domain/medication_models.dart';
import '../domain/medication_repository.dart';
import 'medication_reminder_service.dart';
import 'schedule_engine.dart';

final medicationRepositoryProvider = Provider<MedicationRepository>(
  (ref) => LocalMedicationRepository(database: ref.watch(databaseProvider)),
);

final medicationPlansProvider = StreamProvider<List<MedicationPlanDetails>>(
  (ref) => ref.watch(medicationRepositoryProvider).watchPlans(),
);

final medicationPlanProvider =
    FutureProvider.family<MedicationPlanDetails?, String>(
      (ref, id) => ref.watch(medicationRepositoryProvider).getPlan(id),
    );

final medicationDoseHistoryProvider =
    FutureProvider.family<List<DoseEvent>, String?>(
      (ref, planId) =>
          ref.watch(medicationRepositoryProvider).doseHistory(planId: planId),
    );

final medicationActivityProvider =
    FutureProvider.family<List<MedicationActivity>, String?>(
      (ref, planId) => ref
          .watch(medicationRepositoryProvider)
          .activityHistory(planId: planId),
    );

final medicationPrivacyProvider = FutureProvider<MedicationPrivacyPreferences>(
  (ref) => ref.watch(medicationRepositoryProvider).loadPrivacy(),
);

final medicationTimezoneReviewProvider = FutureProvider<bool>((ref) async {
  final database = ref.watch(databaseProvider);
  return await database.getMetadata('medication.timezone_review_required') ==
      'true';
});

Future<void> acknowledgeMedicationTimezoneReview(WidgetRef ref) async {
  await ref
      .read(databaseProvider)
      .setMetadata('medication.timezone_review_required', 'false');
  ref.invalidate(medicationTimezoneReviewProvider);
}

final flutterLocalNotificationsProvider = Provider(
  (ref) => FlutterLocalNotificationsPlugin(),
);

final notificationAdapterProvider = Provider<PlatformNotificationAdapter>(
  (ref) => FlutterLocalNotificationAdapter(
    ref.watch(flutterLocalNotificationsProvider),
  ),
);

final notificationPermissionProvider = Provider<NotificationPermissionService>(
  (ref) => DeviceNotificationPermissionService(
    ref.watch(flutterLocalNotificationsProvider),
  ),
);

final notificationSchedulerProvider = Provider<NotificationScheduler>(
  (ref) => MedicationNotificationScheduler(
    ref.watch(notificationAdapterProvider),
    ref.watch(notificationPermissionProvider),
  ),
);

final medicationReminderServiceProvider = Provider<MedicationReminderService>(
  (ref) => MedicationReminderService(
    repository: ref.watch(medicationRepositoryProvider),
    scheduler: ref.watch(notificationSchedulerProvider),
    engine: const ScheduleEngine(),
  ),
);

final accountReminderCoordinatorProvider = Provider(
  (ref) => AccountReminderCoordinator(() async {
    final service = ref.read(medicationReminderServiceProvider);
    await ref.read(notificationAdapterProvider).initialize(service.handle);
    await service.rebuild(
      plans: await ref.read(medicationPlansProvider.future),
    );
  }),
);

class AccountReminderCoordinator {
  AccountReminderCoordinator(this._refresh);
  final Future<void> Function() _refresh;
  Future<void> _pending = Future.value();

  Future<void> refresh() =>
      _pending = _pending.then((_) => _refresh()).catchError((Object error) {
        AppLogger().log(
          LogLevel.warning,
          'account_reminder_refresh_failed',
          fields: {'error_type': error.runtimeType.toString()},
        );
      });
}
