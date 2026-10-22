// Opt-in, synthetic engineering fixture; no patient records or cloud AI calls.
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediexplain/core/auth/auth_repository.dart';
import 'package:mediexplain/core/database/app_database.dart' as db;
import 'package:mediexplain/core/network/api_client.dart';
import 'package:mediexplain/core/storage/session_vault.dart';
import 'package:mediexplain/core/sync/sync_coordinator.dart';
import 'package:mediexplain/domain/models/confidence_result.dart';
import 'package:mediexplain/domain/models/session.dart';
import 'package:mediexplain/features/medications/data/local_medication_repository.dart';
import 'package:mediexplain/features/prescription/data/local_prescription_repository.dart';
import 'package:mediexplain/features/prescription/domain/prescription_models.dart';
import 'package:mediexplain/features/prescription/domain/prescription_providers.dart';

class _Vault implements SessionVault {
  Session? session;
  @override
  Future<Session?> read() async => session;
  @override
  Future<void> write(Session value) async => session = value;
  @override
  Future<void> clear() async => session = null;
}

class _Images implements PrescriptionImageStore {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  const base = String.fromEnvironment('LIVE_API_BASE_URL');
  test(
    'live auth and offline save-delete sync over LAN',
    () async {
      HttpOverrides.global = null;
      final manager = SessionManager(
        refreshClient: Dio(),
        vault: _Vault(),
        baseUrl: Uri.parse(base),
      );
      final api = ApiClient(baseUrl: Uri.parse(base), sessionManager: manager);
      final auth = ApiAuthRepository(api, manager);
      final database = db.AppDatabase.forTesting(NativeDatabase.memory());
      final email =
          'offline-delete-${DateTime.now().microsecondsSinceEpoch}@example.com';
      final password =
          'TemporaryFixture!${DateTime.now().microsecondsSinceEpoch}';
      try {
        await auth.register(
          email: email,
          password: password,
          displayName: 'Temporary engineering QA',
        );
        expect(await auth.restoreSession(), isNotNull);
        expect(await manager.refresh(), isNotNull);
        final sync = SyncCoordinator(
          database: database,
          transport: ApiSyncTransport(api),
        );
        final repo = LocalPrescriptionRepository(
          database: database,
          imageStore: _Images(),
          sync: sync,
        );
        final meds = LocalMedicationRepository(database: database);
        final draft = await repo.createManualDraft(userId: api.currentUserId);
        final now = DateTime.now().toUtc();
        await repo.addManualItem(
          draft.prescription.id,
          PrescriptionItem(
            id: 'reviewed-fixture-${now.microsecondsSinceEpoch}',
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
        final saved = await meds.saveConfirmedPrescription(
          draft.prescription.id,
        );
        await repo.deletePrescription(draft.prescription.id);
        await sync.synchronize();
        expect(
          (await database.select(database.syncOperations).get()).map(
            (op) => op.syncState,
          ),
          everyElement('synced'),
        );
        expect(await api.getJsonList('prescriptions'), isEmpty);
        final remote = (await api.getJsonList('medications/plans')).single;
        expect(remote['id'], saved.single.plan.id);
        expect(remote['display_name'], 'Metformin');
        expect(remote['active'], isFalse);
        // Deleting a never-synced scan must also clear its remote tombstone safely.
        final unsynced = await repo.createManualDraft();
        await repo.deletePrescription(unsynced.prescription.id);
        await sync.synchronize();
        expect(
          (await database.select(database.syncOperations).get()).map(
            (op) => op.syncState,
          ),
          everyElement('synced'),
        );
        // Full medicine deletion also removes the previously synced copy,
        // even when ordinary backup uploads are disabled.
        await meds.deleteMedication(saved.single.medication.id);
        final deletionSync = SyncCoordinator(
          database: database,
          transport: DeletionOnlySyncTransport(ApiSyncTransport(api)),
        );
        await deletionSync.synchronize();
        expect(await api.getJsonList('medications/plans'), isEmpty);
        expect(await meds.getPlan(saved.single.plan.id), isNull);
        expect(
          (await database.select(database.syncOperations).get())
              .where((op) => op.entityType == 'user_medication')
              .single
              .syncState,
          'synced',
        );
        await auth.signOut();
        expect(manager.current, isNull);
        await auth.signIn(email: email, password: password);
        expect((await auth.currentUser()).email, email);
        await api.delete('users/me');
      } finally {
        await auth.signOut();
        api.dio.close(force: true);
        await database.close();
      }
    },
    skip: base.isEmpty,
    timeout: const Timeout(Duration(minutes: 1)),
  );
}
