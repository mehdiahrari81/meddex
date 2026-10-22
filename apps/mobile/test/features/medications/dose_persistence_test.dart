import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediexplain/core/database/app_database.dart';
import 'package:mediexplain/features/medications/data/local_medication_repository.dart';
import 'package:mediexplain/features/medications/domain/dose_history.dart';
import 'package:mediexplain/features/medications/domain/medication_models.dart';

void main() {
  test(
    'taken and skipped dates persist across database reopen with corrections intact',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'meddex-dose-fixture-',
      );
      final file = File('${directory.path}/medication.sqlite');
      var database = AppDatabase.forTesting(NativeDatabase(file));
      var now = DateTime.utc(2026, 10, 19, 8);
      LocalMedicationRepository repository() =>
          LocalMedicationRepository(database: database, clock: () => now);
      try {
        final plan = await repository().createPlan(
          CreateMedicationPlanRequest(
            sourceType: MedicationSourceType.manualEntry,
            displayName: 'Metformin',
            confirmedDoseText: '1 tablet',
            confirmedFrequency: 'twice daily',
            confirmedInstruction: 'Synthetic engineering fixture',
            startDate: now,
            timezone: 'UTC',
            scheduleType: MedicationScheduleType.twiceDaily,
            reminderTimes: [480, 1200],
          ),
        );
        final taken = await repository().recordDose(
          planId: plan.plan.id,
          logicalDoseId: 'dose-1',
          scheduledAt: now,
          action: DoseAction.taken,
          source: DoseEventSource.app,
        );
        now = now.add(const Duration(hours: 4));
        await repository().recordDose(
          planId: plan.plan.id,
          logicalDoseId: 'dose-2',
          scheduledAt: now,
          action: DoseAction.skipped,
          source: DoseEventSource.app,
        );
        await database.close();
        database = AppDatabase.forTesting(NativeDatabase(file));
        var history = currentDoseEvents(
          await repository().doseHistory(planId: plan.plan.id),
        );
        expect(history.map((event) => event.action), [
          DoseAction.skipped,
          DoseAction.taken,
        ]);
        expect(history.last.recordedAt.toUtc(), DateTime.utc(2026, 10, 19, 8));
        expect(
          history.first.recordedAt.toUtc(),
          DateTime.utc(2026, 10, 19, 12),
        );
        now = now.add(const Duration(minutes: 1));
        await repository().correctDose(
          eventId: taken.id,
          action: DoseAction.skipped,
        );
        history = currentDoseEvents(
          await repository().doseHistory(planId: plan.plan.id),
        );
        expect(history, hasLength(2));
        expect(history.first.revision, 2);
        expect(history.first.recordedAt.toUtc(), now);
        expect(
          await repository().doseHistory(planId: plan.plan.id),
          hasLength(3),
        );
      } finally {
        await database.close();
        await directory.delete(recursive: true);
      }
    },
  );

  test(
    'simultaneous app and notification taps save one dose and notify open history',
    () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      final repo = LocalMedicationRepository(database: database);
      final now = DateTime.now().toUtc();
      final plan = await repo.createPlan(
        CreateMedicationPlanRequest(
          sourceType: MedicationSourceType.manualEntry,
          displayName: 'Metformin',
          confirmedDoseText: '1 tablet',
          confirmedFrequency: 'daily',
          confirmedInstruction: 'Synthetic engineering fixture',
          startDate: now,
          timezone: 'UTC',
          scheduleType: MedicationScheduleType.onceDaily,
          reminderTimes: [480],
        ),
      );
      final initial = Completer<void>();
      final updated = Completer<void>();
      final subscription = repo.watchDoseHistory(planId: plan.plan.id).listen((
        events,
      ) {
        if (events.isEmpty && !initial.isCompleted) initial.complete();
        if (events.length == 1 && !updated.isCompleted) updated.complete();
      });
      try {
        await initial.future;
        final events = await Future.wait([
          for (final source in [
            DoseEventSource.app,
            DoseEventSource.notificationAction,
          ])
            repo.recordDose(
              planId: plan.plan.id,
              logicalDoseId: 'dose',
              scheduledAt: now,
              action: DoseAction.taken,
              source: source,
            ),
        ]);
        await updated.future;
        expect(events.first.id, events.last.id);
        expect(await repo.doseHistory(), hasLength(1));
        // Same second: the newest distinct dose must still be displayed first.
        await repo.recordDose(
          planId: plan.plan.id,
          logicalDoseId: 'dose-2',
          scheduledAt: now,
          action: DoseAction.skipped,
          source: DoseEventSource.app,
        );
        expect(
          currentDoseEvents(await repo.doseHistory()).first.action,
          DoseAction.skipped,
        );
      } finally {
        await subscription.cancel();
        await database.close();
      }
    },
  );
}
