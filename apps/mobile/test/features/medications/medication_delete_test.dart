import 'dart:io';
import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediexplain/core/database/app_database.dart' as db;
import 'package:mediexplain/features/medications/data/local_medication_repository.dart';
import 'package:mediexplain/features/medications/domain/medication_models.dart';

void main() {
  test(
    'full medication deletion purges its records, preserves others and stays deleted after reopen',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'meddex-delete-med-fixture-',
      );
      final file = File('${directory.path}/medications.sqlite');
      var database = db.AppDatabase.forTesting(NativeDatabase(file));
      LocalMedicationRepository repository() =>
          LocalMedicationRepository(database: database);
      Future<MedicationPlanDetails> add(String name) => repository().createPlan(
        CreateMedicationPlanRequest(
          sourceType: MedicationSourceType.manualEntry,
          displayName: name,
          confirmedDoseText: '1 tablet',
          confirmedFrequency: 'daily',
          confirmedInstruction: 'Synthetic engineering fixture',
          startDate: DateTime.now().toUtc(),
          timezone: 'UTC',
          scheduleType: MedicationScheduleType.onceDaily,
          reminderTimes: [480],
        ),
      );
      try {
        final target = await add('Delete target fixture');
        final other = await add('Keep other fixture');
        await repository().savePrivacy(
          const MedicationPrivacyPreferences.defaults().copyWith(
            syncMedicationHistory: true,
          ),
        );
        await repository().addNote(target.medication.id, 'Target fixture note');
        await repository().saveRefill(
          planId: target.plan.id,
          reminderDate: DateTime.now(),
          startingQuantity: 20,
        );
        final event = await repository().recordDose(
          planId: target.plan.id,
          logicalDoseId: 'target-dose',
          scheduledAt: DateTime.now().toUtc(),
          action: DoseAction.taken,
          source: DoseEventSource.app,
        );
        await repository().correctDose(
          eventId: event.id,
          action: DoseAction.skipped,
        );
        expect(await repository().medicationPlanIds(target.medication.id), [
          target.plan.id,
        ]);
        await repository().deleteMedication(target.medication.id);
        expect(await repository().getPlan(target.plan.id), isNull);
        expect(await repository().getPlan(other.plan.id), isNotNull);
        expect(await repository().doseHistory(), isEmpty);
        expect(
          await repository().activityHistory(planId: target.plan.id),
          isEmpty,
        );
        expect(await database.select(database.medicationNotes).get(), isEmpty);
        expect(await database.select(database.refillReminders).get(), isEmpty);
        expect(
          await database.select(database.medicationPlans).get(),
          hasLength(1),
        );
        expect(
          await database.select(database.medicationPlanSources).get(),
          hasLength(1),
        );
        expect(
          await database.select(database.medicationSchedules).get(),
          hasLength(1),
        );
        expect(
          await database.select(database.reminderTimes).get(),
          hasLength(1),
        );
        final operations = await database.select(database.syncOperations).get();
        expect(
          operations.any(
            (op) =>
                op.payload.contains('Delete target fixture') ||
                op.payload.contains('Target fixture note'),
          ),
          isFalse,
        );
        final deletion = operations.singleWhere(
          (op) => op.entityType == 'user_medication',
        );
        expect(deletion.tombstone, isTrue);
        expect(jsonDecode(deletion.payload), {'id': target.medication.id});
        await repository().deleteMedication(target.medication.id);
        expect(
          (await database.select(database.syncOperations).get()).where(
            (op) => op.entityType == 'user_medication',
          ),
          hasLength(1),
        );
        await database.close();
        database = db.AppDatabase.forTesting(NativeDatabase(file));
        expect(await repository().getPlan(target.plan.id), isNull);
        expect(await repository().getPlan(other.plan.id), isNotNull);
        expect(
          await database.customSelect('PRAGMA foreign_key_check').get(),
          isEmpty,
        );
      } finally {
        await database.close();
        await directory.delete(recursive: true);
      }
    },
  );
}
