import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mediexplain/app/app.dart';
import 'package:mediexplain/app/bootstrap/bootstrap_provider.dart';
import 'package:mediexplain/app/bootstrap/startup_coordinator.dart';
import 'package:mediexplain/app/router/app_router.dart';
import 'package:mediexplain/core/connectivity/connectivity_service.dart';
import 'package:mediexplain/core/database/app_database.dart';
import 'package:mediexplain/core/notifications/notification_service.dart';
import 'package:mediexplain/features/auth/application/auth_controller.dart';
import 'package:mediexplain/features/medications/application/medication_providers.dart';
import 'package:mediexplain/features/medications/data/local_medication_repository.dart';
import 'package:mediexplain/features/medications/domain/medication_models.dart';
import 'package:mediexplain/features/settings/application/settings_controller.dart';
import 'package:mediexplain/features/settings/data/settings_repository.dart';
import 'package:mediexplain/features/settings/domain/app_settings.dart';
import 'package:mediexplain/features/terminology/application/terminology_providers.dart';
import 'package:mediexplain/features/terminology/data/content_update_service.dart';

class _Preferences implements SettingsRepository {
  AppSettings value = const AppSettings.defaults().copyWith(
    onboardingComplete: true,
  );
  @override
  Future<AppSettings> load() async => value;
  @override
  Future<void> save(AppSettings settings) async {
    value = settings;
  }

  @override
  Future<void> resetOnboarding() async {}
  @override
  Future<void> clearLocalPreferences() async {}
}

class _Scheduler implements NotificationScheduler {
  final scheduled = <ReminderNotification>[];
  int cancellations = 0;
  @override
  Future<void> cancel(int id) async {
    scheduled.removeWhere((r) => r.id == id);
  }

  @override
  Future<void> cancelAll() async {
    cancellations++;
    scheduled.clear();
  }

  @override
  Future<void> schedule(ReminderNotification reminder) async {
    scheduled.add(reminder);
  }
}

class _Adapter implements PlatformNotificationAdapter {
  MedicationNotificationResponseHandler? handler;
  @override
  Future<void> initialize(
    MedicationNotificationResponseHandler callback,
  ) async {
    handler = callback;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Guest extends AuthController {
  @override
  Future<AuthState> build() async => const AuthState.guest();
}

void main() {
  test(
    'master preference blocks rebuild and snooze but permits recording doses',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      final repo = LocalMedicationRepository(database: db);
      final scheduler = _Scheduler();
      final preferences = _Preferences();
      final container = ProviderContainer(
        overrides: [
          settingsRepositoryProvider.overrideWithValue(preferences),
          medicationRepositoryProvider.overrideWithValue(repo),
          notificationSchedulerProvider.overrideWithValue(scheduler),
        ],
      );
      try {
        await container.read(settingsControllerProvider.future);
        final now = DateTime.now().toUtc();
        final details = await repo.createPlan(
          CreateMedicationPlanRequest(
            sourceType: MedicationSourceType.manualEntry,
            displayName: 'Engineering fixture',
            confirmedDoseText: 'Reviewed fixture',
            confirmedFrequency: 'daily',
            confirmedInstruction: 'Fixture only',
            startDate: now,
            timezone: 'UTC',
            scheduleType: MedicationScheduleType.onceDaily,
            reminderTimes: [480],
          ),
        );
        final service = container.read(medicationReminderServiceProvider);
        await service.rebuild(plans: [details], now: now);
        expect(scheduler.scheduled, isNotEmpty);
        await container
            .read(settingsControllerProvider.notifier)
            .persist((s) => s.copyWith(notificationsEnabled: false));
        expect(await service.rebuild(plans: [details], now: now), 0);
        expect(scheduler.scheduled, isEmpty);
        await service.snooze(
          details: details,
          dose: ScheduledDose(
            logicalDoseId: 'fixture-dose',
            planId: details.plan.id,
            medicationName: details.medication.displayName,
            doseText: 'Fixture',
            scheduledAt: now,
            action: DoseAction.notRecorded,
          ),
          duration: const Duration(minutes: 10),
        );
        expect(scheduler.scheduled, isEmpty);
        await service.handle(
          MedicationNotificationResponse(
            actionId: notificationActionTaken,
            planId: details.plan.id,
            logicalDoseId: 'fixture-dose',
            scheduledAt: now,
          ),
        );
        expect((await repo.doseHistory()).single.action, DoseAction.taken);
        await container
            .read(settingsControllerProvider.notifier)
            .persist((s) => s.copyWith(notificationsEnabled: true));
        expect(
          await service.rebuild(plans: [details], now: now),
          greaterThan(0),
        );
        expect(scheduler.scheduled, isNotEmpty);
      } finally {
        container.dispose();
        await db.close();
      }
    },
  );

  test(
    'notification actions resolve the current repository after a profile reset',
    () async {
      final oldDatabase = AppDatabase.forTesting(NativeDatabase.memory());
      final newDatabase = AppDatabase.forTesting(NativeDatabase.memory());
      final oldRepository = LocalMedicationRepository(database: oldDatabase);
      final newRepository = LocalMedicationRepository(database: newDatabase);
      final adapter = _Adapter();
      final scheduler = _Scheduler();
      final container = ProviderContainer(
        overrides: [
          medicationRepositoryProvider.overrideWithValue(oldRepository),
          medicationPlansProvider.overrideWith((ref) => Stream.value([])),
          notificationAdapterProvider.overrideWithValue(adapter),
          notificationSchedulerProvider.overrideWithValue(scheduler),
        ],
      );
      try {
        await container.read(accountReminderCoordinatorProvider).refresh();
        final retainedCallback = adapter.handler!;
        final now = DateTime.now().toUtc();
        final newPlan = await newRepository.createPlan(
          CreateMedicationPlanRequest(
            sourceType: MedicationSourceType.manualEntry,
            displayName: 'New profile fixture',
            confirmedDoseText: 'Reviewed fixture',
            confirmedFrequency: 'daily',
            confirmedInstruction: 'Engineering fixture',
            startDate: now,
            timezone: 'UTC',
            scheduleType: MedicationScheduleType.onceDaily,
            reminderTimes: [480],
          ),
        );
        container.updateOverrides([
          medicationRepositoryProvider.overrideWithValue(newRepository),
          medicationPlansProvider.overrideWith((ref) => Stream.value([])),
          notificationAdapterProvider.overrideWithValue(adapter),
          notificationSchedulerProvider.overrideWithValue(scheduler),
        ]);
        await retainedCallback(
          MedicationNotificationResponse(
            actionId: notificationActionTaken,
            planId: newPlan.plan.id,
            logicalDoseId: 'new-profile-dose',
            scheduledAt: now,
          ),
        );
        expect(
          (await newRepository.doseHistory()).single.action,
          DoseAction.taken,
        );
        expect(await oldRepository.doseHistory(), isEmpty);
      } finally {
        container.dispose();
        await oldDatabase.close();
        await newDatabase.close();
      }
    },
  );

  testWidgets(
    'changing master preference refreshes app reminders immediately',
    (tester) async {
      var enabled = true;
      final refreshes = <bool>[];
      final preferences = _Preferences();
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => const Scaffold(body: Text('App ready')),
          ),
        ],
      );
      final container = ProviderContainer(
        overrides: [
          appRouterProvider.overrideWithValue(router),
          settingsRepositoryProvider.overrideWithValue(preferences),
          authControllerProvider.overrideWith(_Guest.new),
          bootstrapProvider.overrideWith(
            (ref) async =>
                const StartupResult(completedSteps: [], elapsed: Duration.zero),
          ),
          connectivityProvider.overrideWith(
            (ref) => Stream.value(ConnectivityState.offline),
          ),
          referenceContentRefreshProvider.overrideWith(
            (ref) async => const ContentUpdateResult(
              updated: false,
              preservedLocalContent: true,
            ),
          ),
          accountReminderCoordinatorProvider.overrideWithValue(
            AccountReminderCoordinator(() async {
              refreshes.add(enabled);
            }),
          ),
        ],
      );
      try {
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MediExplainApp(),
          ),
        );
        await tester.pumpAndSettle();
        refreshes.clear();
        enabled = false;
        await container
            .read(settingsControllerProvider.notifier)
            .persist((s) => s.copyWith(notificationsEnabled: false));
        await tester.pumpAndSettle();
        expect(refreshes, [false]);
        enabled = true;
        await container
            .read(settingsControllerProvider.notifier)
            .persist((s) => s.copyWith(notificationsEnabled: true));
        await tester.pumpAndSettle();
        expect(refreshes, [false, true]);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox());
        container.dispose();
        router.dispose();
      }
    },
  );
}
