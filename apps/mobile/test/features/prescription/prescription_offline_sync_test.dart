import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediexplain/core/database/app_database.dart' as db;
import 'package:mediexplain/core/sync/sync_coordinator.dart';
import 'package:mediexplain/domain/models/confidence_result.dart';
import 'package:mediexplain/features/medications/data/local_medication_repository.dart';
import 'package:mediexplain/features/prescription/data/local_prescription_repository.dart';
import 'package:mediexplain/features/prescription/domain/prescription_models.dart';
import 'package:mediexplain/features/prescription/domain/prescription_providers.dart';

class _NoImages implements PrescriptionImageStore {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Server implements SyncTransport {
  bool failSource = false;
  final sources = <String, Set<String>>{};
  final saved = <String>{};
  final actions = <String>[];
  @override
  Future<SyncReceipt> send(db.SyncOperation operation) async {
    final payload = jsonDecode(operation.payload) as Map;
    if (operation.entityType == 'prescription' &&
        operation.operationType == 'upsert') {
      if (failSource) {
        failSource = false;
        throw StateError('offline');
      }
      sources[operation.entityId] = (payload['items'] as List)
          .map((item) => (item as Map)['id'] as String)
          .toSet();
      actions.add('source');
    } else if (operation.entityType == 'medication_plan') {
      final item = payload['prescription_item_id'];
      if (!sources.values.any((ids) => ids.contains(item))) {
        throw StateError('source missing');
      }
      saved.add(operation.entityId);
      actions.add('medicine');
    } else if (operation.operationType == 'delete') {
      sources.remove(operation.entityId);
      actions.add('delete');
    }
    return const SyncReceipt(serverRevision: '1');
  }
}

void main() {
  for (final retry in [false, true]) {
    test(
      'offline save then delete syncs source, saved medicine, tombstone (retry=$retry)',
      () async {
        final database = db.AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(database.close);
        final server = _Server()..failSource = retry;
        final sync = SyncCoordinator(database: database, transport: server);
        final repo = LocalPrescriptionRepository(
          database: database,
          imageStore: _NoImages(),
          sync: sync,
        );
        final meds = LocalMedicationRepository(database: database);
        final draft = await repo.createManualDraft();
        final now = DateTime.now().toUtc();
        await repo.addManualItem(
          draft.prescription.id,
          PrescriptionItem(
            id: 'reviewed-medicine',
            prescriptionId: draft.prescription.id,
            rawMedicationText: 'Metformin',
            sourceText: 'Metformin',
            pageNumber: 0,
            lineNumber: 0,
            fields: {
              PrescriptionFieldType.medicationName: ParsedField(
                type: PrescriptionFieldType.medicationName,
                originalValue: null,
                currentValue: 'Metformin',
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
        await repo.confirmPrescription(draft.prescription.id);
        final plans = await meds.saveConfirmedPrescription(
          draft.prescription.id,
        );
        await repo.deletePrescription(draft.prescription.id);
        expect(await repo.get(draft.prescription.id), isNull);
        expect(
          (await meds.getPlan(plans.single.plan.id))!.plan.prescriptionItemId,
          isNull,
        );
        await sync.synchronize();
        if (retry) {
          expect(
            server.actions,
            isEmpty,
            reason: 'Dependants must not run after a failed prerequisite.',
          );
          await (database.update(database.syncOperations)).write(
            const db.SyncOperationsCompanion(nextAttemptAt: Value(null)),
          );
          await sync.synchronize();
        }
        expect(server.actions, ['source', 'medicine', 'delete']);
        expect(server.saved, contains(plans.single.plan.id));
        expect(server.sources, isEmpty);
        expect(
          (await database.select(database.syncOperations).get()).every(
            (op) => op.syncState == 'synced',
          ),
          isTrue,
        );
        expect(await meds.getPlan(plans.single.plan.id), isNotNull);
        expect(
          await database.customSelect('PRAGMA foreign_key_check').get(),
          isEmpty,
        );
      },
    );
  }
  test(
    'deleting saved medicine before first sync cancels its deleted-source snapshot',
    () async {
      final database = db.AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      final server = _Server();
      final sync = SyncCoordinator(database: database, transport: server);
      final repo = LocalPrescriptionRepository(
        database: database,
        imageStore: _NoImages(),
        sync: sync,
      );
      final meds = LocalMedicationRepository(database: database);
      final draft = await repo.createManualDraft();
      final now = DateTime.now().toUtc();
      await repo.addManualItem(
        draft.prescription.id,
        PrescriptionItem(
          id: 'deleted-medicine',
          prescriptionId: draft.prescription.id,
          rawMedicationText: 'Metformin',
          sourceText: 'Metformin',
          pageNumber: 0,
          lineNumber: 0,
          fields: {
            PrescriptionFieldType.medicationName: ParsedField(
              type: PrescriptionFieldType.medicationName,
              originalValue: null,
              currentValue: 'Metformin',
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
      await repo.confirmPrescription(draft.prescription.id);
      final saved = await meds.saveConfirmedPrescription(draft.prescription.id);
      await repo.deletePrescription(draft.prescription.id);
      await meds.deleteMedication(saved.single.medication.id);
      await sync.synchronize();
      expect(server.actions, ['delete', 'delete']);
      expect(server.saved, isEmpty);
      expect(server.sources, isEmpty);
      expect(
        (await database.select(database.syncOperations).get()).every(
          (op) => op.syncState == 'synced',
        ),
        isTrue,
      );
      expect(
        (await database.select(database.syncOperations).get()).any(
          (op) => op.payload.contains('Metformin'),
        ),
        isFalse,
      );
    },
  );
}
