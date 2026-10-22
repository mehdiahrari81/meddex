// Opt-in integration test against a running API, using an ephemeral QA account.
import 'dart:io';
import 'package:drift/native.dart';
import 'package:mediexplain/core/database/app_database.dart' as db;
import 'package:mediexplain/core/sync/sync_coordinator.dart';
import 'package:mediexplain/features/medications/data/local_medication_repository.dart';
import 'package:mediexplain/features/medications/domain/medication_models.dart';
import 'package:mediexplain/features/prescription/data/local_prescription_repository.dart';
import 'package:mediexplain/features/prescription/domain/prescription_providers.dart';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:mediexplain/core/auth/auth_repository.dart';
import 'package:mediexplain/core/network/api_client.dart';
import 'package:mediexplain/core/storage/session_vault.dart';
import 'package:mediexplain/domain/models/session.dart';
import 'package:mediexplain/features/prescription/data/api_prescription_text_structurer.dart';
import 'package:mediexplain/features/prescription/domain/prescription_models.dart';
import 'package:mediexplain/features/prescription/presentation/medicine_overview_card.dart';

void main() {
  const base = String.fromEnvironment('LIVE_API_BASE_URL');
  const email = String.fromEnvironment('LIVE_QA_EMAIL');
  test(
    'real mobile transport: auth, Gemini separation and medicine explanation',
    () async {
      HttpOverrides.global = null;
      final url = Uri.parse(base);
      final vault = _Vault();
      final manager = SessionManager(
        refreshClient: Dio(),
        vault: vault,
        baseUrl: url,
      );
      final api = ApiClient(baseUrl: url, sessionManager: manager);
      final auth = ApiAuthRepository(api, manager);
      final password = 'TemporaryQA!${DateTime.now().microsecondsSinceEpoch}';
      await auth.register(
        email: email,
        password: password,
        displayName: 'Temporary transport QA',
      );
      try {
        expect((await auth.currentUser()).email, email);
        expect(await auth.restoreSession(), isNotNull);
        expect(await manager.refresh(), isNotNull);
        final result = await ApiPrescriptionTextStructurer(api).structure(
          prescriptionId: 'transient-qa-not-persisted',
          pages: [
            (
              pageNumber: 1,
              text:
                  'Rx\nLipitor 10 mg Tabs\nTake 1 tablet every day\nFollow up in two weeks',
            ),
          ],
        );
        expect(result.items, hasLength(1));
        final item = result.items.single;
        expect(
          item.field(PrescriptionFieldType.medicationName).currentValue,
          'Lipitor',
        );
        final overview = await MedicineOverviewLoader(api).load((
          name: 'Lipitor',
          strength: '10 mg',
          form: 'Tabs',
          language: 'en',
        ));
        expect(overview.status, 'available');
        expect(overview.explanation?.answer, isNotEmpty);
        expect(overview.explanation?.sources, isNotEmpty);
        final brand = await MedicineOverviewLoader(api).load((
          name: 'Betaloc',
          strength: '50 mg',
          form: 'Tablet',
          language: 'en',
        ));
        expect(brand.status, 'available');
        expect(brand.referenceName?.toLowerCase(), 'metoprolol');
        expect(brand.referenceNote, contains('not confirmed'));
        expect(brand.identitySources, isNotEmpty);
        expect(brand.explanation?.answer, isNotEmpty);
        // General explanations must not require strength/form/product selection.
        for (final entry in {
          'Metformin': 'metformin',
          'Augmentin': 'amoxicillin / clavulanate',
          'Paracetamol': 'acetaminophen',
          'Concor': 'bisoprolol',
        }.entries) {
          final general = await MedicineOverviewLoader(
            api,
          ).load((name: entry.key, strength: null, form: null, language: 'en'));
          expect(general.status, 'available', reason: entry.key);
          expect(general.referenceName?.toLowerCase(), entry.value);
          expect(general.referenceScope, 'ingredient');
          expect(general.explanation?.answer, isNotEmpty);
          expect(general.explanation?.sources, isNotEmpty);
        }
        final fixture = img.Image(width: 1000, height: 300);
        img.fill(fixture, color: img.ColorRgb8(255, 255, 255));
        img.drawString(
          fixture,
          'Betaloc 50 mg Tabs',
          font: img.arial48,
          x: 25,
          y: 25,
          color: img.ColorRgb8(0, 0, 0),
        );
        img.drawString(
          fixture,
          'Take 1 tablet BD',
          font: img.arial48,
          x: 25,
          y: 120,
          color: img.ColorRgb8(0, 0, 0),
        );
        final vision = await api.recognizeHandwriting(
          img.encodeJpg(fixture),
          useGemini: true,
        );
        expect(vision['provider'], 'gemini');
        expect(vision['requires_review'], isTrue);
        final imageMedicines = await ApiPrescriptionTextStructurer(api)
            .structure(
              prescriptionId: 'transient-image-fixture',
              pages: [(pageNumber: 1, text: vision['text']! as String)],
            );
        expect(
          imageMedicines.items.single
              .field(PrescriptionFieldType.medicationName)
              .currentValue,
          'Betaloc',
        );
        // Synthetic fixture only: persist, explicitly review, save every medicine,
        // sync, delete the source scan, and verify the saved medicine still works.
        final database = db.AppDatabase.forTesting(NativeDatabase.memory());
        try {
          final sync = SyncCoordinator(
            database: database,
            transport: ApiSyncTransport(api),
          );
          final prescriptions = LocalPrescriptionRepository(
            database: database,
            imageStore: _NoImages(),
            sync: sync,
          );
          final meds = LocalMedicationRepository(database: database);
          final draft = await prescriptions.createManualDraft(
            userId: api.currentUserId,
          );
          for (final parsed in imageMedicines.items) {
            final item = PrescriptionItem(
              id: parsed.id,
              prescriptionId: draft.prescription.id,
              rawMedicationText: parsed.rawMedicationText,
              sourceText: parsed.sourceText,
              fields: parsed.fields,
              pageNumber: 0,
              lineNumber: 0,
              state: PrescriptionItemState.needsReview,
              createdAt: parsed.createdAt,
              updatedAt: parsed.updatedAt,
            );
            await prescriptions.addManualItem(draft.prescription.id, item);
            for (final field in item.fields.values) {
              // Explicit fixture review, including the literal BD abbreviation.
              await prescriptions.editField(
                draft.prescription.id,
                item.id,
                field.edit(field.currentValue!, DateTime.now()),
              );
              await prescriptions.confirmField(
                draft.prescription.id,
                item.id,
                field.type,
              );
            }
            await prescriptions.setItemState(
              draft.prescription.id,
              item.id,
              PrescriptionItemState.confirmedByUser,
            );
            await prescriptions.setItemState(
              draft.prescription.id,
              item.id,
              PrescriptionItemState.readyForLookup,
            );
          }
          await prescriptions.confirmPrescription(draft.prescription.id);
          final saved = await meds.saveConfirmedPrescription(
            draft.prescription.id,
          );
          expect(saved, hasLength(imageMedicines.items.length));
          expect(saved.every((m) => !m.plan.active), isTrue);
          await meds.saveConfirmedPrescription(draft.prescription.id);
          expect(
            await database.select(database.userMedications).get(),
            hasLength(saved.length),
          );
          // Delete before the first network sync: the reviewed saved-medicine
          // snapshot must be backed up before the source is removed remotely.
          await prescriptions.deletePrescription(draft.prescription.id);
          await sync.synchronize();
          expect(
            (await database.select(database.syncOperations).get())
                .where((op) => op.syncState != 'synced')
                .map((op) => '${op.syncState}: ${op.lastError}'),
            isEmpty,
          );
          expect(await prescriptions.latestDraft(), isNull);
          expect(await meds.getPlan(saved.first.plan.id), isNotNull);
          await meds.setMedicationStatus(
            saved.first.medication.id,
            MedicationStatus.pausedByUser,
          );
          await sync.synchronize();
          expect(
            (await database.select(database.syncOperations).get())
                .where((op) => op.syncState != 'synced')
                .map((op) => '${op.syncState}: ${op.lastError}'),
            isEmpty,
          );
          final remote = (await api.getJsonList(
            'medications/plans',
          )).singleWhere((plan) => plan['id'] == saved.first.plan.id);
          expect(remote['display_name'], 'Betaloc');
          expect(remote['active'], isFalse);
        } finally {
          await database.close();
        }
        await auth.signOut();
        expect(manager.current, isNull);
        await auth.signIn(email: email, password: password);
        expect((await auth.currentUser()).email, email);
      } finally {
        await auth.signOut();
        api.dio.close(force: true);
      }
    },
    skip: base.isEmpty || email.isEmpty,
    timeout: const Timeout(Duration(minutes: 4)),
  );
}

class _Vault implements SessionVault {
  Session? stored;
  @override
  Future<Session?> read() async => stored;
  @override
  Future<void> write(Session session) async {
    stored = session;
  }

  @override
  Future<void> clear() async {
    stored = null;
  }
}

class _NoImages implements PrescriptionImageStore {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
