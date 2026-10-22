import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediexplain/core/database/app_database.dart' as db;
import 'package:mediexplain/core/notifications/notification_service.dart';
import 'package:mediexplain/core/sync/sync_coordinator.dart';
import 'package:mediexplain/core/sync/sync_provider.dart';
import 'package:mediexplain/features/medications/application/medication_providers.dart';
import 'package:mediexplain/features/medications/data/local_medication_repository.dart';
import 'package:mediexplain/features/medications/domain/medication_models.dart';
import 'package:mediexplain/features/medications/presentation/medication_screens.dart';

class _Notifications
    implements PlatformNotificationAdapter, ActiveNotificationReader {
  final requests = <PendingNotificationRequest>[];
  final delivered = <ActiveNotification>[];
  @override
  Future<List<ActiveNotification>> active() async => delivered;
  final cancelled = <int>[];
  bool failNext = false;
  @override
  Future<List<PendingNotificationRequest>> pending() async {
    if (failNext) {
      failNext = false;
      throw StateError('Synthetic notification error');
    }
    return requests;
  }

  @override
  Future<void> cancel(int id) async {
    cancelled.add(id);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  for (final fail in [false, true]) {
    testWidgets(
      'delete medicine cancels its reminders and snoozes only (retry=$fail)',
      (tester) async {
        final database = db.AppDatabase.forTesting(NativeDatabase.memory());
        final repo = LocalMedicationRepository(database: database);
        Future<MedicationPlanDetails> add(String name) => repo.createPlan(
          CreateMedicationPlanRequest(
            sourceType: MedicationSourceType.manualEntry,
            displayName: name,
            confirmedDoseText: '1 tablet',
            confirmedFrequency: 'daily',
            confirmedInstruction: 'Engineering fixture',
            startDate: DateTime.now(),
            timezone: 'UTC',
            scheduleType: MedicationScheduleType.onceDaily,
            reminderTimes: [480],
          ),
        );
        final target = await add('Target medication');
        final other = await add('Other medication');
        final adapter = _Notifications()..failNext = fail;
        adapter.requests.addAll([
          PendingNotificationRequest(
            11,
            'Private reminder',
            '',
            jsonEncode({
              'plan_id': target.plan.id,
              'logical_dose_id': 'regular',
            }),
          ),
          PendingNotificationRequest(
            12,
            'Snoozed reminder',
            '',
            jsonEncode({
              'plan_id': target.plan.id,
              'logical_dose_id': 'snooze',
            }),
          ),
          PendingNotificationRequest(
            13,
            'Other reminder',
            '',
            jsonEncode({'plan_id': other.plan.id}),
          ),
          const PendingNotificationRequest(
            14,
            'Other notification',
            '',
            'not-json',
          ),
        ]);
        adapter.delivered.addAll([
          ActiveNotification(
            id: 15,
            payload: jsonEncode({'plan_id': target.plan.id}),
          ),
          ActiveNotification(
            id: 16,
            payload: jsonEncode({'plan_id': other.plan.id}),
          ),
        ]);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              medicationRepositoryProvider.overrideWithValue(repo),
              notificationAdapterProvider.overrideWithValue(adapter),
              syncCoordinatorProvider.overrideWithValue(
                SyncCoordinator(
                  database: database,
                  transport: const DisabledSyncTransport(),
                ),
              ),
            ],
            child: const MaterialApp(home: MyMedicationsScreen()),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(ValueKey('delete-medication-${target.medication.id}')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect(await repo.getPlan(target.plan.id), isNotNull);
        expect(adapter.cancelled, isEmpty);
        await tester.tap(
          find.byKey(ValueKey('delete-medication-${target.medication.id}')),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.widgetWithText(FilledButton, 'Delete medication'),
        );
        await tester.pumpAndSettle();
        if (fail) {
          expect(
            find.text('Deletion could not finish. Please retry.'),
            findsOneWidget,
          );
          expect(await repo.getPlan(target.plan.id), isNotNull);
          await tester.tap(find.text('Retry deletion'));
          await tester.pumpAndSettle();
        }
        expect(find.text('Target medication'), findsNothing);
        expect(find.text('Other medication'), findsOneWidget);
        expect(adapter.cancelled, [11, 12, 15]);
        expect(await repo.getPlan(target.plan.id), isNull);
        expect(await repo.getPlan(other.plan.id), isNotNull);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump();
        await tester.runAsync(database.close);
      },
    );
  }
}
