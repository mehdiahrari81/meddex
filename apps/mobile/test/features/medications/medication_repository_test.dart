import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediexplain/core/database/app_database.dart';
import 'package:mediexplain/features/medications/data/local_medication_repository.dart';
import 'package:mediexplain/features/medications/domain/medication_models.dart';
import 'package:mediexplain/features/prescription/domain/prescription_models.dart';

void main() {
  late AppDatabase database;
  late LocalMedicationRepository repository;
  final now = DateTime.utc(2026, 8, 13, 8);

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    repository = LocalMedicationRepository(
      database: database,
      clock: () => now,
    );
  });
  tearDown(() => database.close());

  CreateMedicationPlanRequest manual() => CreateMedicationPlanRequest(
    sourceType: MedicationSourceType.manualEntry,
    displayName: 'Test medicine',
    confirmedDoseText: '1 tablet',
    confirmedFrequency: 'once daily',
    confirmedInstruction: 'User entered: take 1 tablet once daily',
    startDate: now,
    timezone: 'UTC',
    scheduleType: MedicationScheduleType.onceDaily,
    reminderTimes: const [8 * 60],
  );

  test('manual plan preserves source when reminder is edited', () async {
    final created = await repository.createPlan(manual());
    await repository.replaceSchedule(
      created.plan.id,
      type: MedicationScheduleType.onceDaily,
      reminderTimes: const [10 * 60],
      weekdays: const {},
    );
    final updated = await repository.getPlan(created.plan.id);
    expect(
      updated!.source.confirmedInstruction,
      created.source.confirmedInstruction,
    );
    expect(updated.schedules.single.times, [10 * 60]);
  });

  test('schedule edits and pauses queue complete sync snapshots', () async {
    final created = await repository.createPlan(manual());
    await repository.replaceSchedule(
      created.plan.id,
      type: MedicationScheduleType.twiceDaily,
      reminderTimes: const [8 * 60, 20 * 60],
      weekdays: const {},
    );
    var rows = await database.select(database.syncOperations).get();
    var payload = jsonDecode(rows.last.payload) as Map<String, dynamic>;
    expect(payload['display_name'], 'Test medicine');
    expect(payload['start_date'], '2026-08-13');
    expect(payload['schedule']['reminder_times'], [480, 1200]);
    expect(payload['active'], isTrue);
    expect(
      (await database.select(database.medicationPlans).getSingle()).revision,
      2,
    );

    await repository.setPlanActive(created.plan.id, false);
    rows = await database.select(database.syncOperations).get();
    payload = jsonDecode(rows.last.payload) as Map<String, dynamic>;
    expect(payload['display_name'], 'Test medicine');
    expect(payload['active'], isFalse);
    expect(payload['medication_status'], 'pausedByUser');
    expect(
      (await database.select(database.medicationPlans).getSingle()).revision,
      3,
    );
    expect(
      (await database.select(database.userMedications).getSingle()).status,
      'pausedByUser',
    );
  });

  test('completion deactivates reminders and syncs status', () async {
    final created = await repository.createPlan(manual());
    await repository.setMedicationStatus(
      created.medication.id,
      MedicationStatus.completed,
    );
    final plan = await repository.getPlan(created.plan.id);
    expect(plan!.medication.status, MedicationStatus.completed);
    expect(plan.plan.active, isFalse);
    expect(plan.schedules.single.active, isFalse);
    final operations = await database.select(database.syncOperations).get();
    final payload = jsonDecode(operations.last.payload) as Map<String, dynamic>;
    expect(payload['medication_status'], 'completed');
    expect(payload['active'], isFalse);
  });

  test('unverified OCR item cannot create medication plan', () async {
    await database
        .into(database.prescriptions)
        .insert(
          PrescriptionsCompanion.insert(
            id: 'rx',
            sourceType: 'camera',
            captureDate: now,
            parserVersion: 'test',
            pipelineState: PrescriptionPipelineState.userReviewRequired.name,
            createdAt: now,
            updatedAt: now,
          ),
        );
    await database
        .into(database.prescriptionItems)
        .insert(
          PrescriptionItemsCompanion.insert(
            id: 'item',
            prescriptionId: 'rx',
            rawMedicationText: 'OCR guess',
            sourceText: 'OCR guess',
            pageNumber: 1,
            lineNumber: 1,
            state: PrescriptionItemState.needsReview.name,
            position: 0,
            createdAt: now,
            updatedAt: now,
          ),
        );
    expect(
      () => repository.createPlan(
        CreateMedicationPlanRequest(
          sourceType: MedicationSourceType.confirmedPrescription,
          prescriptionItemId: 'item',
          displayName: 'OCR guess',
          confirmedDoseText: '1',
          confirmedFrequency: 'daily',
          confirmedInstruction: 'guess',
          startDate: now,
          timezone: 'UTC',
          scheduleType: MedicationScheduleType.onceDaily,
          reminderTimes: const [480],
        ),
      ),
      throwsStateError,
    );
  });

  test('dose actions are idempotent and corrections append history', () async {
    final plan = await repository.createPlan(manual());
    final first = await repository.recordDose(
      planId: plan.plan.id,
      logicalDoseId: 'dose',
      scheduledAt: now,
      action: DoseAction.taken,
      source: DoseEventSource.app,
    );
    final duplicate = await repository.recordDose(
      planId: plan.plan.id,
      logicalDoseId: 'dose',
      scheduledAt: now,
      action: DoseAction.taken,
      source: DoseEventSource.app,
    );
    expect(duplicate.id, first.id);
    final corrected = await repository.correctDose(
      eventId: first.id,
      action: DoseAction.skipped,
    );
    expect(corrected.revision, 2);
    expect(corrected.supersedesEventId, first.id);
    expect(await repository.doseHistory(planId: plan.plan.id), hasLength(2));
  });

  test('dose log sync is opt-in and queues exactly one operation', () async {
    final plan = await repository.createPlan(manual());
    final before = await database.select(database.syncOperations).get();
    await repository.recordDose(
      planId: plan.plan.id,
      logicalDoseId: 'local-only',
      scheduledAt: now,
      action: DoseAction.taken,
      source: DoseEventSource.app,
    );
    expect(
      await database.select(database.syncOperations).get(),
      hasLength(before.length),
    );
    await repository.savePrivacy(
      const MedicationPrivacyPreferences.defaults().copyWith(
        syncMedicationHistory: true,
      ),
    );
    await repository.recordDose(
      planId: plan.plan.id,
      logicalDoseId: 'synced',
      scheduledAt: now,
      action: DoseAction.taken,
      source: DoseEventSource.app,
    );
    final operations = await database.select(database.syncOperations).get();
    expect(
      operations.where((value) => value.entityType == 'dose_event'),
      hasLength(1),
    );
  });

  test('export audit stores fields but not sensitive export content', () async {
    await repository.recordExport(
      format: 'pdf',
      includedFields: const ['medicine name', 'confirmed instruction'],
      shared: true,
    );
    final row = await database
        .select(database.medicationExportMetadata)
        .getSingle();
    expect(row.format, 'pdf');
    expect(row.includedFieldsJson, contains('medicine name'));
    expect(row.sharedAt!.toUtc(), now);
    expect(row.includedFieldsJson, isNot(contains('Test medicine')));
  });
}
