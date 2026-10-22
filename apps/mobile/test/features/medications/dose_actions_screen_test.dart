import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:mediexplain/core/database/app_database.dart' show AppDatabase;
import 'package:mediexplain/core/notifications/notification_service.dart';
import 'package:mediexplain/features/medications/application/medication_providers.dart';
import 'package:mediexplain/features/medications/data/local_medication_repository.dart';
import 'package:mediexplain/features/medications/domain/medication_models.dart';
import 'package:mediexplain/features/medications/domain/medication_repository.dart';
import 'package:mediexplain/features/medications/presentation/medication_screens.dart';

class _Notifications implements NotificationScheduler {
  final cancelled = <int>[];
  @override
  Future<void> cancel(int id) async => cancelled.add(id);
  @override
  Future<void> cancelAll() async {}
  @override
  Future<void> schedule(ReminderNotification reminder) async {}
}

class _RetryRepository implements MedicationRepository {
  _RetryRepository(this.delegate);
  final MedicationRepository delegate;
  var failNext = true;
  @override
  Stream<List<MedicationPlanDetails>> watchPlans({MedicationStatus? status}) =>
      delegate.watchPlans(status: status);
  @override
  Stream<List<DoseEvent>> watchDoseHistory({String? planId}) =>
      delegate.watchDoseHistory(planId: planId);
  @override
  Future<DoseEvent> recordDose({
    required String planId,
    required String logicalDoseId,
    required DateTime? scheduledAt,
    required DoseAction action,
    required DoseEventSource source,
    String? note,
  }) {
    if (failNext) {
      failNext = false;
      throw StateError('Synthetic disk error');
    }
    return delegate.recordDose(
      planId: planId,
      logicalDoseId: logicalDoseId,
      scheduledAt: scheduledAt,
      action: action,
      source: source,
      note: note,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUpAll(tz_data.initializeTimeZones);
  late AppDatabase database;
  late LocalMedicationRepository repo;
  late MedicationPlanDetails plan;
  late DateTime now;
  late _Notifications notifications;
  setUp(() async {
    now = DateTime.now().toUtc();
    database = AppDatabase.forTesting(NativeDatabase.memory());
    repo = LocalMedicationRepository(database: database, clock: () => now);
    notifications = _Notifications();
    plan = await repo.createPlan(
      CreateMedicationPlanRequest(
        sourceType: MedicationSourceType.manualEntry,
        displayName: 'Metformin',
        confirmedDoseText: '1 tablet',
        confirmedFrequency: 'twice daily',
        confirmedInstruction: 'Reviewed fixture instructions',
        startDate: now.subtract(const Duration(days: 1)),
        timezone: 'UTC',
        scheduleType: MedicationScheduleType.twiceDaily,
        reminderTimes: [480, 1200],
      ),
    );
  });
  tearDown(() => database.close());
  Future<void> mount(
    WidgetTester tester,
    Widget screen, {
    MedicationRepository? override,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          medicationRepositoryProvider.overrideWithValue(override ?? repo),
          notificationSchedulerProvider.overrideWithValue(notifications),
        ],
        child: MaterialApp(home: screen),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> select(WidgetTester tester, String label) async {
    await tester.tap(find.byTooltip('Record dose').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text(label).last);
    await tester.pumpAndSettle();
    if (find.text('Confirm').evaluate().isNotEmpty) {
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();
    }
  }

  testWidgets(
    'Taken and Skip show their saved date in timeline and My Medications',
    (tester) async {
      await mount(tester, const TodayMedicationTimelineScreen());
      await select(tester, 'Taken');
      var history = await repo.doseHistory(planId: plan.plan.id);
      expect(history.single.action, DoseAction.taken);
      expect(find.textContaining('Taken •'), findsOneWidget);
      final date = DateFormat.yMMMd().add_jm().format(now.toLocal());
      expect(find.textContaining(date), findsWidgets);
      await select(tester, 'Skip');
      history = await repo.doseHistory(planId: plan.plan.id);
      expect(history, hasLength(2));
      expect(
        history.any(
          (event) => event.action == DoseAction.skipped && event.revision == 2,
        ),
        isTrue,
      );
      expect(find.textContaining('Skipped •'), findsOneWidget);
      expect(find.textContaining('Taken •'), findsNothing);
      expect(notifications.cancelled, hasLength(2));
      await mount(tester, const MyMedicationsScreen());
      expect(find.textContaining('Skipped • $date'), findsOneWidget);
      expect(find.text('Dose history'), findsOneWidget);
      await mount(tester, DoseHistoryScreen(planId: plan.plan.id));
      expect(find.text('Skipped'), findsOneWidget);
      expect(find.text('Taken'), findsNothing);
      expect(find.textContaining(date), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump();
      await tester.runAsync(database.close);
    },
  );
  testWidgets(
    'notification dose updates an already open My Medications screen',
    (tester) async {
      await mount(tester, const MyMedicationsScreen());
      expect(find.textContaining('Taken •'), findsNothing);
      await repo.recordDose(
        planId: plan.plan.id,
        logicalDoseId: 'notification-dose',
        scheduledAt: now,
        action: DoseAction.taken,
        source: DoseEventSource.notificationAction,
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Taken •'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump();
      await tester.runAsync(database.close);
    },
  );
  testWidgets('failed dose action reports error and can be retried', (
    tester,
  ) async {
    await mount(
      tester,
      const TodayMedicationTimelineScreen(),
      override: _RetryRepository(repo),
    );
    await select(tester, 'Taken');
    expect(
      find.text('Could not record this dose. Please retry.'),
      findsOneWidget,
    );
    expect(await repo.doseHistory(), isEmpty);
    await select(tester, 'Taken');
    expect(find.textContaining('Taken •'), findsOneWidget);
    expect(await repo.doseHistory(), hasLength(1));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump();
    await tester.runAsync(database.close);
  });
}
