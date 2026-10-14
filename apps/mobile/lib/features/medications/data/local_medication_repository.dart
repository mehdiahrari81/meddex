import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart' as db;
import '../../prescription/domain/prescription_models.dart';
import '../domain/medication_models.dart';
import '../domain/medication_repository.dart';

class LocalMedicationRepository implements MedicationRepository {
  factory LocalMedicationRepository({
    required db.AppDatabase database,
    Uuid uuid = const Uuid(),
    DateTime Function()? clock,
  }) => LocalMedicationRepository._(database, uuid, clock ?? _utcNow);

  LocalMedicationRepository._(this._database, this._uuid, this._clock);

  final db.AppDatabase _database;
  final Uuid _uuid;
  final DateTime Function() _clock;

  static DateTime _utcNow() => DateTime.now().toUtc();

  @override
  Stream<List<MedicationPlanDetails>> watchPlans({MedicationStatus? status}) {
    final query =
        _database.select(_database.medicationPlans).join([
            innerJoin(
              _database.userMedications,
              _database.userMedications.id.equalsExp(
                _database.medicationPlans.medicationId,
              ),
            ),
          ])
          ..where(
            _database.medicationPlans.deletedAt.isNull() &
                _database.userMedications.deletedAt.isNull(),
          )
          ..orderBy([
            OrderingTerm.desc(_database.medicationPlans.active),
            OrderingTerm.desc(_database.medicationPlans.updatedAt),
          ]);
    if (status != null) {
      query.where(_database.userMedications.status.equals(status.name));
    }
    return query.watch().asyncMap((rows) async {
      final output = <MedicationPlanDetails>[];
      for (final row in rows) {
        final plan = row.readTable(_database.medicationPlans);
        final details = await getPlan(plan.id);
        if (details != null) output.add(details);
      }
      return output;
    });
  }

  @override
  Future<MedicationPlanDetails?> getPlan(String planId) async {
    final planRow =
        await (_database.select(_database.medicationPlans)
              ..where((row) => row.id.equals(planId) & row.deletedAt.isNull()))
            .getSingleOrNull();
    if (planRow == null) return null;
    final medicationRow =
        await (_database.select(_database.userMedications)..where(
              (row) =>
                  row.id.equals(planRow.medicationId) & row.deletedAt.isNull(),
            ))
            .getSingleOrNull();
    final sourceRow = await (_database.select(
      _database.medicationPlanSources,
    )..where((row) => row.medicationPlanId.equals(planId))).getSingleOrNull();
    if (medicationRow == null || sourceRow == null) return null;
    final schedules = await (_database.select(
      _database.medicationSchedules,
    )..where((row) => row.medicationPlanId.equals(planId))).get();
    final scheduleModels = <MedicationSchedule>[];
    for (final schedule in schedules) {
      final times =
          await (_database.select(_database.reminderTimes)
                ..where((row) => row.scheduleId.equals(schedule.id))
                ..orderBy([(row) => OrderingTerm.asc(row.position)]))
              .get();
      scheduleModels.add(
        MedicationSchedule(
          id: schedule.id,
          type: MedicationScheduleType.values.byName(schedule.scheduleType),
          intervalHours: schedule.intervalHours,
          intervalAnchor: schedule.intervalAnchor,
          times: times.map((value) => value.minutesAfterMidnight).toList(),
          weekdays: (jsonDecode(schedule.weekdaysJson) as List)
              .cast<num>()
              .map((value) => value.toInt())
              .toSet(),
          asNeeded: schedule.asNeeded,
          active: schedule.active,
        ),
      );
    }
    final noteRows =
        await (_database.select(_database.medicationNotes)..where(
              (row) =>
                  row.medicationId.equals(medicationRow.id) &
                  row.deletedAt.isNull(),
            ))
            .get();
    return MedicationPlanDetails(
      medication: _medication(medicationRow),
      plan: _plan(planRow),
      source: MedicationPlanSource(
        sourceType: MedicationSourceType.values.byName(sourceRow.sourceType),
        rawPrescriptionInstruction: sourceRow.rawPrescriptionInstruction,
        confirmedInstruction: sourceRow.confirmedInstruction,
        confirmedAt: sourceRow.confirmedAt,
      ),
      schedules: scheduleModels,
      notes: noteRows
          .map(
            (row) => MedicationNote(
              id: row.id,
              medicationId: row.medicationId,
              note: row.note,
              createdAt: row.createdAt,
              updatedAt: row.updatedAt,
            ),
          )
          .toList(),
    );
  }

  @override
  Future<MedicationPlanDetails> createPlan(
    CreateMedicationPlanRequest request,
  ) async {
    _validateRequest(request);
    if (request.sourceType == MedicationSourceType.confirmedPrescription) {
      await _requireConfirmedPrescriptionItem(request.prescriptionItemId!);
    }
    final now = _clock();
    final medicationId = _uuid.v4();
    final planId = _uuid.v4();
    final scheduleId = _uuid.v4();
    await _database.transaction(() async {
      await _database
          .into(_database.userMedications)
          .insert(
            db.UserMedicationsCompanion.insert(
              id: medicationId,
              prescriptionItemId: Value(request.prescriptionItemId),
              sourceType: request.sourceType.name,
              displayName: request.displayName.trim(),
              strength: Value(_nullable(request.strength)),
              dosageForm: Value(_nullable(request.dosageForm)),
              informationStatus: MedicineInformationStatus.unavailable.name,
              status: MedicationStatus.active.name,
              createdAt: now,
              updatedAt: now,
            ),
          );
      await _database
          .into(_database.medicationPlans)
          .insert(
            db.MedicationPlansCompanion.insert(
              id: planId,
              medicationId: medicationId,
              prescriptionItemId: Value(request.prescriptionItemId),
              confirmedDoseText: request.confirmedDoseText.trim(),
              confirmedFrequency: request.confirmedFrequency.trim(),
              confirmedDuration: Value(_nullable(request.confirmedDuration)),
              startDate: _dateAsUtc(request.startDate),
              endDate: Value(
                request.endDate == null ? null : _dateAsUtc(request.endDate!),
              ),
              instructions: Value(_nullable(request.instructions)),
              timezone: request.timezone,
              createdAt: now,
              updatedAt: now,
            ),
          );
      await _database
          .into(_database.medicationPlanSources)
          .insert(
            db.MedicationPlanSourcesCompanion.insert(
              id: _uuid.v4(),
              medicationPlanId: planId,
              sourceType: request.sourceType.name,
              rawPrescriptionInstruction: Value(
                _nullable(request.rawPrescriptionInstruction),
              ),
              confirmedInstruction: request.confirmedInstruction.trim(),
              confirmedAt: now,
            ),
          );
      await _insertSchedule(
        scheduleId: scheduleId,
        planId: planId,
        type: request.scheduleType,
        reminderTimes: request.reminderTimes,
        weekdays: request.weekdays,
        intervalHours: request.intervalHours,
        intervalAnchor: request.intervalAnchor,
        asNeeded: request.asNeeded,
        now: now,
      );
      await _history(planId, 'schedule_created', now, {
        'schedule_type': request.scheduleType.name,
        'reminder_count': request.reminderTimes.length,
      });
      await _enqueue(
        entityType: 'medication_plan',
        entityId: planId,
        operationType: 'upsert',
        payload: _planPayload(request, medicationId, planId, now),
        now: now,
      );
    });
    return (await getPlan(planId))!;
  }

  void _validateRequest(CreateMedicationPlanRequest request) {
    if (request.displayName.trim().isEmpty ||
        request.confirmedDoseText.trim().isEmpty ||
        request.confirmedFrequency.trim().isEmpty ||
        request.confirmedInstruction.trim().isEmpty) {
      throw ArgumentError(
        'User-confirmed medicine and instructions are required.',
      );
    }
    if (request.sourceType == MedicationSourceType.confirmedPrescription &&
        request.prescriptionItemId == null) {
      throw ArgumentError('A confirmed prescription item is required.');
    }
    if (request.asNeeded && request.reminderTimes.isNotEmpty) {
      throw ArgumentError('As-needed tracking cannot create fixed reminders.');
    }
    if (!request.asNeeded &&
        request.scheduleType != MedicationScheduleType.everyNHours &&
        request.reminderTimes.isEmpty) {
      throw ArgumentError('Choose reminder times explicitly.');
    }
    if (request.scheduleType == MedicationScheduleType.everyNHours &&
        ((request.intervalHours ?? 0) <= 0 || request.intervalAnchor == null)) {
      throw ArgumentError(
        'Every-N-hours schedules require an interval and anchor.',
      );
    }
    if ((request.scheduleType == MedicationScheduleType.selectedWeekdays ||
            request.scheduleType == MedicationScheduleType.specificDays) &&
        request.weekdays.isEmpty) {
      throw ArgumentError('Choose at least one day of the week.');
    }
    if (request.weekdays.any((day) => day < 1 || day > 7)) {
      throw ArgumentError('Weekdays must be between Monday and Sunday.');
    }
    if (request.endDate != null &&
        request.endDate!.isBefore(request.startDate)) {
      throw ArgumentError('End date cannot be before start date.');
    }
  }

  Future<void> _requireConfirmedPrescriptionItem(String itemId) async {
    final item = await (_database.select(
      _database.prescriptionItems,
    )..where((row) => row.id.equals(itemId))).getSingleOrNull();
    if (item == null ||
        item.state != PrescriptionItemState.readyForLookup.name) {
      throw StateError('Unverified OCR data cannot create a medication plan.');
    }
    final prescription =
        await (_database.select(_database.prescriptions)..where(
              (row) =>
                  row.id.equals(item.prescriptionId) & row.deletedAt.isNull(),
            ))
            .getSingleOrNull();
    if (prescription == null ||
        prescription.pipelineState !=
            PrescriptionPipelineState.readyForMedicationLookup.name ||
        prescription.userConfirmedAt == null) {
      throw StateError('The prescription must be confirmed by the user first.');
    }
    final name =
        await (_database.select(_database.prescriptionFieldCandidates)..where(
              (row) =>
                  row.prescriptionItemId.equals(itemId) &
                  row.fieldType.equals(
                    PrescriptionFieldType.medicationName.name,
                  ),
            ))
            .getSingleOrNull();
    if (name == null || !name.userConfirmed || name.currentValue == null) {
      throw StateError('The medicine identity must be confirmed by the user.');
    }
  }

  @override
  Future<void> replaceSchedule(
    String planId, {
    required MedicationScheduleType type,
    required List<int> reminderTimes,
    required Set<int> weekdays,
    int? intervalHours,
    DateTime? intervalAnchor,
    bool asNeeded = false,
  }) async {
    final existing = await getPlan(planId);
    if (existing == null) throw StateError('Medication plan not found.');
    final check = CreateMedicationPlanRequest(
      sourceType: existing.source.sourceType,
      prescriptionItemId: existing.plan.prescriptionItemId,
      displayName: existing.medication.displayName,
      confirmedDoseText: existing.plan.confirmedDoseText,
      confirmedFrequency: existing.plan.confirmedFrequency,
      confirmedInstruction: existing.source.confirmedInstruction,
      startDate: existing.plan.startDate,
      timezone: existing.plan.timezone,
      scheduleType: type,
      reminderTimes: reminderTimes,
      weekdays: weekdays,
      intervalHours: intervalHours,
      intervalAnchor: intervalAnchor,
      asNeeded: asNeeded,
    );
    _validateRequest(check);
    final now = _clock();
    await _database.transaction(() async {
      final scheduleRows = await (_database.select(
        _database.medicationSchedules,
      )..where((row) => row.medicationPlanId.equals(planId))).get();
      for (final schedule in scheduleRows) {
        await (_database.delete(
          _database.reminderTimes,
        )..where((row) => row.scheduleId.equals(schedule.id))).go();
      }
      await (_database.delete(
        _database.medicationSchedules,
      )..where((row) => row.medicationPlanId.equals(planId))).go();
      await _insertSchedule(
        scheduleId: _uuid.v4(),
        planId: planId,
        type: type,
        reminderTimes: reminderTimes,
        weekdays: weekdays,
        intervalHours: intervalHours,
        intervalAnchor: intervalAnchor,
        asNeeded: asNeeded,
        planActive: existing.plan.active,
        now: now,
      );
      final planRow = await (_database.select(
        _database.medicationPlans,
      )..where((row) => row.id.equals(planId))).getSingle();
      await (_database.update(
        _database.medicationPlans,
      )..where((row) => row.id.equals(planId))).write(
        db.MedicationPlansCompanion(
          updatedAt: Value(now),
          revision: Value(planRow.revision + 1),
        ),
      );
      await _history(planId, 'schedule_edited', now, {
        'schedule_type': type.name,
        'reminder_count': reminderTimes.length,
      });
    });
    final updated = await getPlan(planId);
    if (updated == null) throw StateError('Medication plan not found.');
    await _enqueue(
      entityType: 'medication_plan',
      entityId: planId,
      operationType: 'upsert',
      payload: _detailsPayload(updated, now),
      now: now,
    );
  }

  Future<void> _insertSchedule({
    required String scheduleId,
    required String planId,
    required MedicationScheduleType type,
    required List<int> reminderTimes,
    required Set<int> weekdays,
    required int? intervalHours,
    required DateTime? intervalAnchor,
    required bool asNeeded,
    bool planActive = true,
    required DateTime now,
  }) async {
    await _database
        .into(_database.medicationSchedules)
        .insert(
          db.MedicationSchedulesCompanion.insert(
            id: scheduleId,
            medicationPlanId: planId,
            scheduleType: type.name,
            intervalHours: Value(intervalHours),
            intervalAnchor: Value(intervalAnchor?.toUtc()),
            weekdaysJson: Value(jsonEncode(weekdays.toList()..sort())),
            asNeeded: Value(asNeeded),
            active: Value(planActive && !asNeeded),
            createdAt: now,
            updatedAt: now,
          ),
        );
    for (var index = 0; index < reminderTimes.length; index++) {
      final minutes = reminderTimes[index];
      if (minutes < 0 || minutes >= 24 * 60) {
        throw ArgumentError('Reminder time is outside a calendar day.');
      }
      await _database
          .into(_database.reminderTimes)
          .insert(
            db.ReminderTimesCompanion.insert(
              id: _uuid.v4(),
              scheduleId: scheduleId,
              minutesAfterMidnight: minutes,
              position: index,
              createdAt: now,
            ),
          );
    }
  }

  @override
  Future<void> setPlanActive(String planId, bool active) async {
    final now = _clock();
    await _database.transaction(() async {
      final planRow =
          await (_database.select(
                _database.medicationPlans,
              )..where((row) => row.id.equals(planId) & row.deletedAt.isNull()))
              .getSingleOrNull();
      if (planRow == null) throw StateError('Medication plan not found.');
      await (_database.update(
        _database.medicationPlans,
      )..where((row) => row.id.equals(planId) & row.deletedAt.isNull())).write(
        db.MedicationPlansCompanion(
          active: Value(active),
          updatedAt: Value(now),
          revision: Value(planRow.revision + 1),
        ),
      );
      await (_database.update(
        _database.medicationSchedules,
      )..where((row) => row.medicationPlanId.equals(planId))).write(
        db.MedicationSchedulesCompanion(
          active: Value(active),
          updatedAt: Value(now),
        ),
      );
      final medicationRow = await (_database.select(
        _database.userMedications,
      )..where((row) => row.id.equals(planRow.medicationId))).getSingle();
      await (_database.update(
        _database.userMedications,
      )..where((row) => row.id.equals(planRow.medicationId))).write(
        db.UserMedicationsCompanion(
          status: Value(
            active
                ? MedicationStatus.active.name
                : MedicationStatus.pausedByUser.name,
          ),
          revision: Value(medicationRow.revision + 1),
          updatedAt: Value(now),
        ),
      );
      await _history(
        planId,
        active ? 'reminder_resumed' : 'reminder_paused',
        now,
      );
    });
    final updated = await getPlan(planId);
    if (updated == null) throw StateError('Medication plan not found.');
    await _enqueue(
      entityType: 'medication_plan',
      entityId: planId,
      operationType: 'upsert',
      payload: _detailsPayload(updated, now),
      now: now,
    );
  }

  @override
  Future<void> setMedicationStatus(
    String medicationId,
    MedicationStatus status,
  ) async {
    final now = _clock();
    final plans = await (_database.select(
      _database.medicationPlans,
    )..where((row) => row.medicationId.equals(medicationId))).get();
    final medicationRow =
        await (_database.select(_database.userMedications)..where(
              (row) => row.id.equals(medicationId) & row.deletedAt.isNull(),
            ))
            .getSingleOrNull();
    if (medicationRow == null) throw StateError('Medication not found.');
    await _database.transaction(() async {
      await (_database.update(_database.userMedications)..where(
            (row) => row.id.equals(medicationId) & row.deletedAt.isNull(),
          ))
          .write(
            db.UserMedicationsCompanion(
              status: Value(status.name),
              revision: Value(medicationRow.revision + 1),
              updatedAt: Value(now),
            ),
          );
      final deactivate = status != MedicationStatus.active;
      for (final plan in plans) {
        if (deactivate) {
          await (_database.update(
            _database.medicationPlans,
          )..where((row) => row.id.equals(plan.id))).write(
            db.MedicationPlansCompanion(
              active: const Value(false),
              revision: Value(plan.revision + 1),
              updatedAt: Value(now),
            ),
          );
          await (_database.update(
            _database.medicationSchedules,
          )..where((row) => row.medicationPlanId.equals(plan.id))).write(
            db.MedicationSchedulesCompanion(
              active: const Value(false),
              updatedAt: Value(now),
            ),
          );
        }
        await _history(plan.id, 'medication_${status.name}', now);
      }
    });
    for (final plan in plans) {
      final updated = await getPlan(plan.id);
      if (updated == null) continue;
      await _enqueue(
        entityType: 'medication_plan',
        entityId: plan.id,
        operationType: 'upsert',
        payload: _detailsPayload(updated, now),
        now: now,
      );
    }
  }

  @override
  Future<void> deletePlan(String planId, {required bool deleteLogs}) async {
    final now = _clock();
    await _database.transaction(() async {
      if (deleteLogs) {
        await (_database.delete(
          _database.doseEvents,
        )..where((row) => row.medicationPlanId.equals(planId))).go();
      }
      await (_database.update(
        _database.medicationPlans,
      )..where((row) => row.id.equals(planId))).write(
        db.MedicationPlansCompanion(
          active: const Value(false),
          deletedAt: Value(now),
          updatedAt: Value(now),
        ),
      );
      await _enqueue(
        entityType: 'medication_plan',
        entityId: planId,
        operationType: 'delete',
        payload: {'id': planId, 'deleted_at': now.toIso8601String()},
        tombstone: true,
        now: now,
      );
    });
  }

  @override
  Future<DoseEvent> recordDose({
    required String planId,
    required String logicalDoseId,
    required DateTime? scheduledAt,
    required DoseAction action,
    required DoseEventSource source,
    String? note,
  }) async {
    if (source != DoseEventSource.manualEntry && scheduledAt == null) {
      throw ArgumentError('Scheduled dose actions need their scheduled time.');
    }
    final existing = await _latestDose(logicalDoseId);
    if (existing != null &&
        existing.action == action &&
        existing.source == source) {
      return existing;
    }
    final now = _clock();
    final event = DoseEvent(
      id: _uuid.v4(),
      medicationPlanId: planId,
      logicalDoseId: logicalDoseId,
      scheduledAt: scheduledAt?.toUtc(),
      action: action,
      recordedAt: now,
      source: source,
      note: _nullable(note),
      supersedesEventId: existing?.id,
      revision: (existing?.revision ?? 0) + 1,
    );
    await _database.transaction(() async {
      await _insertDose(event);
      await _history(
        planId,
        existing == null ? 'dose_recorded' : 'dose_corrected',
        now,
        {
          'action': action.name,
          if (existing != null) 'previous_action': existing.action.name,
        },
      );
      final privacy = await loadPrivacy();
      if (privacy.syncMedicationHistory) {
        await _enqueue(
          entityType: 'dose_event',
          entityId: event.id,
          operationType: 'upsert',
          payload: _dosePayload(event),
          now: now,
        );
      }
    });
    return event;
  }

  @override
  Future<DoseEvent> correctDose({
    required String eventId,
    required DoseAction action,
    String? note,
  }) async {
    final row = await (_database.select(
      _database.doseEvents,
    )..where((value) => value.id.equals(eventId))).getSingleOrNull();
    if (row == null) throw StateError('Dose event not found.');
    return recordDose(
      planId: row.medicationPlanId,
      logicalDoseId: row.logicalDoseId,
      scheduledAt: row.scheduledAt,
      action: action,
      source: DoseEventSource.app,
      note: note,
    );
  }

  Future<DoseEvent?> _latestDose(String logicalDoseId) async {
    final row =
        await (_database.select(_database.doseEvents)
              ..where(
                (value) =>
                    value.logicalDoseId.equals(logicalDoseId) &
                    value.deletedAt.isNull(),
              )
              ..orderBy([
                (value) => OrderingTerm.desc(value.revision),
                (value) => OrderingTerm.desc(value.recordedAt),
              ])
              ..limit(1))
            .getSingleOrNull();
    return row == null ? null : _dose(row);
  }

  Future<void> _insertDose(DoseEvent event) => _database
      .into(_database.doseEvents)
      .insert(
        db.DoseEventsCompanion.insert(
          id: event.id,
          medicationPlanId: event.medicationPlanId,
          logicalDoseId: event.logicalDoseId,
          scheduledAt: Value(event.scheduledAt),
          action: event.action.name,
          recordedAt: event.recordedAt,
          source: event.source.name,
          note: Value(event.note),
          supersedesEventId: Value(event.supersedesEventId),
          revision: Value(event.revision),
        ),
      );

  @override
  Future<List<DoseEvent>> doseHistory({
    String? planId,
    DateTime? from,
    DateTime? to,
  }) async {
    final query = _database.select(_database.doseEvents)
      ..where((row) => row.deletedAt.isNull())
      ..orderBy([(row) => OrderingTerm.desc(row.recordedAt)]);
    if (planId != null) {
      query.where((row) => row.medicationPlanId.equals(planId));
    }
    if (from != null) {
      query.where((row) => row.recordedAt.isBiggerOrEqualValue(from.toUtc()));
    }
    if (to != null) {
      query.where((row) => row.recordedAt.isSmallerThanValue(to.toUtc()));
    }
    return (await query.get()).map(_dose).toList();
  }

  @override
  Future<void> addNote(String medicationId, String note) async {
    if (note.trim().isEmpty) throw ArgumentError('Note cannot be empty.');
    final now = _clock();
    await _database
        .into(_database.medicationNotes)
        .insert(
          db.MedicationNotesCompanion.insert(
            id: _uuid.v4(),
            medicationId: medicationId,
            note: note.trim(),
            createdAt: now,
            updatedAt: now,
          ),
        );
  }

  @override
  Future<void> saveRefill({
    required String planId,
    DateTime? reminderDate,
    double? startingQuantity,
    double? quantityPerTakenDose,
    double? alertAtRemaining,
  }) async {
    if (reminderDate == null && startingQuantity == null) {
      throw ArgumentError('Enter a date or starting quantity.');
    }
    if (startingQuantity != null && startingQuantity < 0 ||
        quantityPerTakenDose != null && quantityPerTakenDose <= 0) {
      throw ArgumentError('Quantities must be positive.');
    }
    final now = _clock();
    final existing = await (_database.select(
      _database.refillReminders,
    )..where((row) => row.medicationPlanId.equals(planId))).getSingleOrNull();
    final companion = db.RefillRemindersCompanion.insert(
      id: existing?.id ?? _uuid.v4(),
      medicationPlanId: planId,
      reminderDate: Value(reminderDate?.toUtc()),
      startingQuantity: Value(startingQuantity),
      quantityPerTakenDose: Value(quantityPerTakenDose),
      alertAtRemaining: Value(alertAtRemaining),
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    );
    await _database
        .into(_database.refillReminders)
        .insertOnConflictUpdate(companion);
    await _history(planId, 'refill_reminder_updated', now);
  }

  @override
  Future<double?> estimatedRemaining(String planId) async {
    final refill =
        await (_database.select(_database.refillReminders)..where(
              (row) =>
                  row.medicationPlanId.equals(planId) & row.active.equals(true),
            ))
            .getSingleOrNull();
    if (refill?.startingQuantity == null) return null;
    final events = await doseHistory(planId: planId);
    final latest = <String, DoseEvent>{};
    for (final event in events) {
      final current = latest[event.logicalDoseId];
      if (current == null || event.revision > current.revision) {
        latest[event.logicalDoseId] = event;
      }
    }
    final taken = latest.values
        .where(
          (event) =>
              event.action == DoseAction.taken ||
              event.action == DoseAction.late,
        )
        .length;
    final remaining =
        refill!.startingQuantity! - taken * (refill.quantityPerTakenDose ?? 1);
    return remaining < 0 ? 0 : remaining;
  }

  @override
  Future<List<MedicationActivity>> activityHistory({String? planId}) async {
    final query = _database.select(_database.medicationPlanHistory)
      ..orderBy([(row) => OrderingTerm.desc(row.occurredAt)]);
    if (planId != null) {
      query.where((row) => row.medicationPlanId.equals(planId));
    }
    return (await query.get())
        .map(
          (row) => MedicationActivity(
            id: row.id,
            planId: row.medicationPlanId,
            action: row.action,
            occurredAt: row.occurredAt,
            safeDetails: (jsonDecode(row.safeDetailsJson) as Map)
                .cast<String, Object?>(),
          ),
        )
        .toList();
  }

  @override
  Future<MedicationPrivacyPreferences> loadPrivacy() async {
    final row = await (_database.select(
      _database.userPrivacyPreferences,
    )..where((value) => value.id.equals('current'))).getSingleOrNull();
    if (row == null) return const MedicationPrivacyPreferences.defaults();
    return MedicationPrivacyPreferences(
      notificationPrivacy: NotificationPrivacy.values.byName(
        row.notificationPrivacy,
      ),
      retainPrescriptionImages: row.retainPrescriptionImages,
      syncMedicationHistory: row.syncMedicationHistory,
      hideMedicineDetails: row.hideMedicineDetails,
      obscureAppPreview: row.obscureAppPreview,
      dailySummaryEnabled: row.dailySummaryEnabled,
    );
  }

  @override
  Future<void> savePrivacy(MedicationPrivacyPreferences preferences) =>
      _database
          .into(_database.userPrivacyPreferences)
          .insertOnConflictUpdate(
            db.UserPrivacyPreferencesCompanion.insert(
              id: 'current',
              notificationPrivacy: preferences.notificationPrivacy.name,
              retainPrescriptionImages: preferences.retainPrescriptionImages,
              syncMedicationHistory: preferences.syncMedicationHistory,
              hideMedicineDetails: preferences.hideMedicineDetails,
              obscureAppPreview: preferences.obscureAppPreview,
              dailySummaryEnabled: preferences.dailySummaryEnabled,
              updatedAt: _clock(),
            ),
          );

  @override
  Future<void> clearMedicationLogs() async {
    await _database.delete(_database.doseEvents).go();
  }

  @override
  Future<void> recordExport({
    required String format,
    required List<String> includedFields,
    required bool shared,
  }) {
    final now = _clock();
    return _database
        .into(_database.medicationExportMetadata)
        .insert(
          db.MedicationExportMetadataCompanion.insert(
            id: _uuid.v4(),
            format: format,
            includedFieldsJson: jsonEncode(includedFields),
            createdAt: now,
            sharedAt: Value(shared ? now : null),
          ),
        );
  }

  Medication _medication(db.UserMedication row) => Medication(
    id: row.id,
    prescriptionItemId: row.prescriptionItemId,
    medicationInformationId: row.medicationInformationId,
    sourceType: MedicationSourceType.values.byName(row.sourceType),
    displayName: row.displayName,
    genericName: row.genericName,
    brandName: row.brandName,
    strength: row.strength,
    dosageForm: row.dosageForm,
    informationStatus: MedicineInformationStatus.values.byName(
      row.informationStatus,
    ),
    status: MedicationStatus.values.byName(row.status),
    createdAt: row.createdAt,
    updatedAt: row.updatedAt,
  );

  MedicationPlan _plan(db.MedicationPlan row) => MedicationPlan(
    id: row.id,
    medicationId: row.medicationId,
    prescriptionItemId: row.prescriptionItemId,
    confirmedDoseText: row.confirmedDoseText,
    confirmedFrequency: row.confirmedFrequency,
    confirmedDuration: row.confirmedDuration,
    startDate: row.startDate,
    endDate: row.endDate,
    instructions: row.instructions,
    timezone: row.timezone,
    active: row.active,
    createdAt: row.createdAt,
    updatedAt: row.updatedAt,
  );

  DoseEvent _dose(db.DoseEvent row) => DoseEvent(
    id: row.id,
    medicationPlanId: row.medicationPlanId,
    logicalDoseId: row.logicalDoseId,
    scheduledAt: row.scheduledAt,
    action: DoseAction.values.byName(row.action),
    recordedAt: row.recordedAt,
    source: DoseEventSource.values.byName(row.source),
    note: row.note,
    supersedesEventId: row.supersedesEventId,
    revision: row.revision,
  );

  Future<void> _history(
    String planId,
    String action,
    DateTime now, [
    Map<String, Object?> details = const {},
  ]) => _database
      .into(_database.medicationPlanHistory)
      .insert(
        db.MedicationPlanHistoryCompanion.insert(
          id: _uuid.v4(),
          medicationPlanId: planId,
          action: action,
          safeDetailsJson: Value(jsonEncode(details)),
          occurredAt: now,
        ),
      );

  Future<void> _enqueue({
    required String entityType,
    required String entityId,
    required String operationType,
    required Map<String, Object?> payload,
    required DateTime now,
    bool tombstone = false,
  }) => _database.enqueue(
    db.SyncOperationsCompanion.insert(
      id: _uuid.v4(),
      entityType: entityType,
      entityId: entityId,
      operationType: operationType,
      payload: jsonEncode(payload),
      idempotencyKey: _uuid.v4(),
      createdAt: now,
      updatedAt: now,
      tombstone: Value(tombstone),
    ),
  );

  Map<String, Object?> _planPayload(
    CreateMedicationPlanRequest request,
    String medicationId,
    String planId,
    DateTime now,
  ) => {
    'id': planId,
    'medication_id': medicationId,
    'prescription_item_id': request.prescriptionItemId,
    'source_type': request.sourceType.name,
    'display_name': request.displayName.trim(),
    'strength': _nullable(request.strength),
    'dosage_form': _nullable(request.dosageForm),
    'confirmed_dose_text': request.confirmedDoseText.trim(),
    'confirmed_frequency': request.confirmedFrequency.trim(),
    'confirmed_duration': _nullable(request.confirmedDuration),
    'raw_prescription_instruction': _nullable(
      request.rawPrescriptionInstruction,
    ),
    'confirmed_instruction': request.confirmedInstruction.trim(),
    'start_date': _dateOnly(request.startDate),
    'end_date': request.endDate == null ? null : _dateOnly(request.endDate!),
    'instructions': _nullable(request.instructions),
    'timezone': request.timezone,
    'schedule': {
      'type': request.scheduleType.name,
      'reminder_times': request.reminderTimes,
      'weekdays': request.weekdays.toList()..sort(),
      'interval_hours': request.intervalHours,
      'interval_anchor': request.intervalAnchor?.toUtc().toIso8601String(),
      'as_needed': request.asNeeded,
    },
    'medication_status': MedicationStatus.active.name,
    'active': true,
    'updated_at': now.toIso8601String(),
  };

  Map<String, Object?> _detailsPayload(
    MedicationPlanDetails details,
    DateTime now,
  ) {
    if (details.schedules.isEmpty) {
      throw StateError('A medication plan must have a schedule.');
    }
    final schedule = details.schedules.first;
    return {
      'id': details.plan.id,
      'medication_id': details.medication.id,
      'prescription_item_id': details.plan.prescriptionItemId,
      'source_type': details.source.sourceType.name,
      'display_name': details.medication.displayName,
      'strength': details.medication.strength,
      'dosage_form': details.medication.dosageForm,
      'confirmed_dose_text': details.plan.confirmedDoseText,
      'confirmed_frequency': details.plan.confirmedFrequency,
      'confirmed_duration': details.plan.confirmedDuration,
      'raw_prescription_instruction': details.source.rawPrescriptionInstruction,
      'confirmed_instruction': details.source.confirmedInstruction,
      'start_date': _dateOnly(details.plan.startDate),
      'end_date': details.plan.endDate == null
          ? null
          : _dateOnly(details.plan.endDate!),
      'instructions': details.plan.instructions,
      'timezone': details.plan.timezone,
      'schedule': {
        'type': schedule.type.name,
        'reminder_times': schedule.times,
        'weekdays': schedule.weekdays.toList()..sort(),
        'interval_hours': schedule.intervalHours,
        'interval_anchor': schedule.intervalAnchor?.toUtc().toIso8601String(),
        'as_needed': schedule.asNeeded,
      },
      'medication_status': details.medication.status.name,
      'active': details.plan.active,
      'updated_at': now.toIso8601String(),
    };
  }

  Map<String, Object?> _dosePayload(DoseEvent event) => {
    'id': event.id,
    'medication_plan_id': event.medicationPlanId,
    'logical_dose_id': event.logicalDoseId,
    'scheduled_at': event.scheduledAt?.toUtc().toIso8601String(),
    'action': event.action.name,
    'recorded_at': event.recordedAt.toUtc().toIso8601String(),
    'source': event.source.name,
    'note': event.note,
    'supersedes_event_id': event.supersedesEventId,
    'revision': event.revision,
  };

  String? _nullable(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  DateTime _dateAsUtc(DateTime value) =>
      DateTime.utc(value.year, value.month, value.day);

  String _dateOnly(DateTime value) {
    final year = value.year.toString().padLeft(4, '0');
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }
}
