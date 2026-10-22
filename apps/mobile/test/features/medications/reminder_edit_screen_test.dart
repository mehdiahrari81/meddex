import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mediexplain/core/database/app_database.dart' show AppDatabase;
import 'package:mediexplain/core/notifications/notification_service.dart';
import 'package:mediexplain/core/sync/sync_coordinator.dart';
import 'package:mediexplain/domain/models/confidence_result.dart';
import 'package:mediexplain/features/auth/application/auth_controller.dart';
import 'package:mediexplain/features/home/presentation/home_screen.dart';
import 'package:mediexplain/features/medications/application/medication_providers.dart';
import 'package:mediexplain/features/medications/data/local_medication_repository.dart';
import 'package:mediexplain/features/medications/domain/medication_models.dart';
import 'package:mediexplain/features/medications/presentation/medication_screens.dart';
import 'package:mediexplain/features/prescription/data/local_prescription_repository.dart';
import 'package:mediexplain/features/prescription/domain/prescription_models.dart';
import 'package:mediexplain/features/prescription/domain/prescription_providers.dart';
import 'package:mediexplain/l10n/app_localizations.dart';
import 'package:timezone/data/latest.dart' as tz_data;

class _NoNotifications implements NotificationPermissionService {
  _NoNotifications([this.permission = NotificationPermissionState.denied]);
  final NotificationPermissionState permission;
  @override
  Future<NotificationPermissionState> status() async => permission;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Images implements PrescriptionImageStore {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Guest extends AuthController {
  @override
  Future<AuthState> build() async => const AuthState.guest();
}

class _Scheduler implements NotificationScheduler {
  final scheduled = <ReminderNotification>[];
  @override
  Future<void> cancelAll() async => scheduled.clear();
  @override
  Future<void> cancel(int id) async {}
  @override
  Future<void> schedule(ReminderNotification reminder) async =>
      scheduled.add(reminder);
}

void main() {
  setUpAll(tz_data.initializeTimeZones);
  for (final permission in [
    NotificationPermissionState.granted,
    NotificationPermissionState.denied,
  ]) {
    testWidgets('Set reminder shows a confirmed scan on Home ($permission)', (
      tester,
    ) async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      final repo = LocalMedicationRepository(database: database);
      final prescriptions = LocalPrescriptionRepository(
        database: database,
        imageStore: _Images(),
        sync: SyncCoordinator(
          database: database,
          transport: const DisabledSyncTransport(),
        ),
      );
      final draft = await prescriptions.createManualDraft();
      final now = DateTime.now().toUtc();
      await prescriptions.addManualItem(
        draft.prescription.id,
        PrescriptionItem(
          id: 'reviewed-scan',
          prescriptionId: draft.prescription.id,
          rawMedicationText: 'Metformin',
          sourceText: 'Metformin 500 mg, 1 tablet daily',
          pageNumber: 1,
          lineNumber: 1,
          fields: {
            for (final entry in {
              PrescriptionFieldType.medicationName: 'Metformin',
              PrescriptionFieldType.strength: '500 mg',
              PrescriptionFieldType.dosageForm: 'tablet',
              PrescriptionFieldType.dose: '1 tablet',
              PrescriptionFieldType.frequency: 'once daily',
            }.entries)
              entry.key: ParsedField(
                type: entry.key,
                originalValue: entry.value,
                currentValue: entry.value,
                source: FieldValueSource.user,
                confidence: ConfidenceBand.unknown,
                ambiguous: false,
                userConfirmed: true,
              ),
          },
          state: PrescriptionItemState.readyForLookup,
          createdAt: now,
          updatedAt: now,
        ),
      );
      await prescriptions.confirmPrescription(draft.prescription.id);
      final saved = (await repo.saveConfirmedPrescription(
        draft.prescription.id,
      )).single;
      expect(saved.plan.active, isFalse);
      final scheduler = _Scheduler();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('flutter_timezone'),
            (_) async => 'Asia/Karachi',
          );
      final router = GoRouter(
        routes: [
          GoRoute(path: '/', builder: (_, _) => const HomeScreen()),
          GoRoute(
            path: '/medications',
            builder: (_, _) => const MyMedicationsScreen(),
          ),
          GoRoute(
            path: '/medications/:id',
            builder: (_, state) =>
                MedicationPlanDetailScreen(planId: state.pathParameters['id']!),
          ),
          GoRoute(
            path: '/medications/:id/edit',
            builder: (_, state) =>
                EditReminderScreen(planId: state.pathParameters['id']!),
          ),
        ],
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            medicationRepositoryProvider.overrideWithValue(repo),
            medicationTimezoneReviewProvider.overrideWith((ref) async => false),
            notificationPermissionProvider.overrideWithValue(
              _NoNotifications(permission),
            ),
            notificationSchedulerProvider.overrideWithValue(scheduler),
            authControllerProvider.overrideWith(_Guest.new),
          ],
          child: MaterialApp.router(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('No upcoming fixed reminder'), findsOneWidget);
      router.push('/medications');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Metformin'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Set reminder'), 250);
      expect(find.text('Edit reminder'), findsNothing);
      await tester.tap(find.text('Set reminder'));
      await tester.pumpAndSettle();
      expect(find.text('Set Reminder'), findsOneWidget);
      expect(find.text('Timezone: Asia/Karachi'), findsOneWidget);
      await tester.tap(find.text('Save reminder times'));
      await tester.pumpAndSettle();
      final updated = (await tester.runAsync(
        () => repo.getPlan(saved.plan.id),
      ))!;
      expect(updated.plan.active, isTrue);
      expect(updated.schedules.single.active, isTrue);
      expect(updated.schedules.single.times, [480]);
      expect(
        updated.source.confirmedInstruction,
        saved.source.confirmedInstruction,
      );
      final operations = (await tester.runAsync(
        () => database.select(database.syncOperations).get(),
      ))!;
      final payload = jsonDecode(operations.last.payload) as Map;
      expect(payload['active'], isTrue);
      expect(payload['schedule']['reminder_times'], [480]);
      if (permission == NotificationPermissionState.granted) {
        expect(scheduler.scheduled, isNotEmpty);
        expect(scheduler.scheduled.first.planId, saved.plan.id);
        expect(scheduler.scheduled.first.timezone, 'Asia/Karachi');
      } else {
        expect(scheduler.scheduled, isEmpty);
      }
      router.pop();
      await tester.pumpAndSettle();
      router.pop();
      await tester.pumpAndSettle();
      expect(find.textContaining('Metformin •'), findsOneWidget);
      expect(find.text('No upcoming fixed reminder'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      router.dispose();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump();
      await tester.runAsync(database.close);
    });
  }
  testWidgets('Home shows a weekly reminder more than two days away', (
    tester,
  ) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final repo = LocalMedicationRepository(database: database);
    final now = DateTime.now().toUtc();
    final nextDay = now.add(const Duration(days: 5));
    await repo.createPlan(
      CreateMedicationPlanRequest(
        sourceType: MedicationSourceType.manualEntry,
        displayName: 'Weekly medicine',
        confirmedDoseText: 'Reviewed dose',
        confirmedFrequency: 'once weekly',
        confirmedInstruction: 'Reviewed weekly instructions',
        startDate: now,
        timezone: 'UTC',
        scheduleType: MedicationScheduleType.selectedWeekdays,
        weekdays: {nextDay.weekday},
        reminderTimes: [480],
      ),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          medicationRepositoryProvider.overrideWithValue(repo),
          medicationTimezoneReviewProvider.overrideWith((ref) async => false),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const HomeScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Weekly medicine •'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump();
    await tester.runAsync(database.close);
  });

  for (final type in [
    MedicationScheduleType.selectedWeekdays,
    MedicationScheduleType.everyNHours,
    MedicationScheduleType.asNeeded,
    MedicationScheduleType.custom,
  ]) {
    testWidgets(
      'editing reminder preserves $type and its source instructions',
      (tester) async {
        final database = AppDatabase.forTesting(NativeDatabase.memory());
        final repo = LocalMedicationRepository(database: database);
        final interval = type == MedicationScheduleType.everyNHours;
        final asNeeded = type == MedicationScheduleType.asNeeded;
        final firstSchedule = type == MedicationScheduleType.custom;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              const MethodChannel('flutter_timezone'),
              (_) async => 'Asia/Tehran',
            );
        final anchor = DateTime.utc(2026, 10, 18, 8);
        final created = await repo.createPlan(
          CreateMedicationPlanRequest(
            sourceType: MedicationSourceType.manualEntry,
            displayName: 'Metformin',
            confirmedDoseText: '1 tablet',
            confirmedFrequency: asNeeded ? 'as needed' : 'as prescribed',
            confirmedInstruction: 'Explicitly reviewed fixture instructions',
            startDate: anchor,
            timezone: 'UTC',
            scheduleType: type,
            reminderTimes: interval || asNeeded || firstSchedule ? [] : [480],
            weekdays: type == MedicationScheduleType.selectedWeekdays
                ? {1, 4}
                : {},
            intervalHours: interval ? 6 : null,
            intervalAnchor: interval ? anchor : null,
            asNeeded: asNeeded,
            remindersEnabled: !firstSchedule,
          ),
        );
        final router = GoRouter(
          routes: [
            GoRoute(
              path: '/',
              builder: (_, _) =>
                  const Scaffold(body: Text('Back from reminder')),
            ),
            GoRoute(
              path: '/edit',
              builder: (_, _) => EditReminderScreen(planId: created.plan.id),
            ),
          ],
        );
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              medicationRepositoryProvider.overrideWithValue(repo),
              notificationPermissionProvider.overrideWithValue(
                _NoNotifications(),
              ),
            ],
            child: MaterialApp.router(routerConfig: router),
          ),
        );
        router.push('/edit');
        await tester.pumpAndSettle();
        expect(
          find.text('Timezone: ${firstSchedule ? 'Asia/Tehran' : 'UTC'}'),
          findsOneWidget,
        );
        await tester.tap(find.text('Save reminder times'));
        await tester.pumpAndSettle();
        expect(find.text('Back from reminder'), findsOneWidget);
        final updated = (await repo.getPlan(created.plan.id))!;
        expect(updated.schedules.single.type, type);
        expect(
          updated.schedules.single.weekdays,
          created.schedules.single.weekdays,
        );
        expect(updated.schedules.single.intervalHours, interval ? 6 : null);
        expect(
          updated.schedules.single.intervalAnchor?.toUtc(),
          interval ? anchor : null,
        );
        expect(updated.schedules.single.asNeeded, asNeeded);
        expect(updated.plan.timezone, firstSchedule ? 'Asia/Tehran' : 'UTC');
        expect(
          updated.source.confirmedInstruction,
          created.source.confirmedInstruction,
        );
        expect(updated.plan.confirmedDoseText, '1 tablet');
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        router.dispose();
        await tester.runAsync(database.close);
      },
    );
  }
  testWidgets(
    'medicine with missing dose stays saved and reminder explains what is missing',
    (tester) async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      final repo = LocalMedicationRepository(database: database);
      final created = await repo.createPlan(
        CreateMedicationPlanRequest(
          sourceType: MedicationSourceType.manualEntry,
          displayName: 'Metformin',
          confirmedDoseText: '',
          confirmedFrequency: '',
          confirmedInstruction: 'Medicine name reviewed',
          startDate: DateTime.utc(2026, 10, 18),
          timezone: 'UTC',
          scheduleType: MedicationScheduleType.custom,
          remindersEnabled: false,
        ),
      );
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('flutter_timezone'),
            (_) async => 'Asia/Tehran',
          );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [medicationRepositoryProvider.overrideWithValue(repo)],
          child: MaterialApp(home: EditReminderScreen(planId: created.plan.id)),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.textContaining('A reminder needs a confirmed dose and frequency'),
        findsOneWidget,
      );
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Save reminder times'),
            )
            .onPressed,
        isNull,
      );
      expect((await repo.getPlan(created.plan.id))!.plan.active, isFalse);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(database.close);
    },
  );
}
