import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:mediexplain/core/database/app_database.dart';
import 'package:mediexplain/core/network/api_client.dart';
import 'package:mediexplain/core/storage/session_vault.dart';
import 'package:mediexplain/core/sync/sync_coordinator.dart';
import 'package:mediexplain/domain/models/session.dart';
import 'package:mediexplain/features/learning/data/local_learning_repository.dart';
import 'package:mediexplain/features/medications/data/local_medication_repository.dart';
import 'package:mediexplain/features/medications/domain/medication_models.dart';
import 'package:mediexplain/features/prescription/data/local_prescription_repository.dart';
import 'package:mediexplain/features/prescription/data/private_image_store.dart';
import 'package:mediexplain/features/prescription/domain/prescription_models.dart';
import 'package:mediexplain/features/prescription/domain/prescription_providers.dart';
import 'package:mediexplain/features/settings/application/data_management.dart';
import 'package:mediexplain/features/settings/data/settings_repository.dart';
import 'package:mediexplain/features/settings/domain/app_settings.dart';
import 'package:mediexplain/features/terminology/data/terminology_seed_importer.dart';

class MemoryPreferences implements SettingsRepository {
  AppSettings value = const AppSettings.defaults().copyWith(
    onboardingComplete: true,
  );
  int clears = 0;
  @override
  Future<AppSettings> load() async => value;
  @override
  Future<void> save(AppSettings settings) async {
    value = settings;
  }

  @override
  Future<void> resetOnboarding() async {
    value = value.copyWith(onboardingComplete: false);
  }

  @override
  Future<void> clearLocalPreferences() async {
    clears++;
    value = const AppSettings.defaults();
  }
}

class _Images implements PrescriptionImageStore {
  bool fail = true;
  @override
  Future<void> deleteByPrivateId(String id) async {
    if (fail) throw const FileSystemException('Synthetic storage failure');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Vault implements SessionVault {
  Session? session;
  @override
  Future<Session?> read() async => session;
  @override
  Future<void> write(Session value) async {
    session = value;
  }

  @override
  Future<void> clear() async {
    session = null;
  }
}

class _Transport implements SyncTransport {
  final ids = <String>[];
  @override
  Future<SyncReceipt> send(SyncOperation op) async {
    ids.add(op.entityId);
    return const SyncReceipt(serverRevision: 'deleted');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'local erasure survives restart, removes private records/files and retains pending deletions',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'meddex-profile-erasure-',
      );
      var db = AppDatabase.forTesting(
        NativeDatabase(File('${directory.path}/profile.sqlite')),
      );
      final other = AppDatabase.forTesting(NativeDatabase.memory());
      final images = PrivatePrescriptionImageStore(
        supportDirectory: () async => directory,
        temporaryDirectory: () async => directory,
      );
      final prefs = MemoryPreferences();
      final sync = SyncCoordinator(
        database: db,
        transport: const DisabledSyncTransport(),
      );
      try {
        for (final file in [
          'starter_dataset_v1.json',
          'learning_expansion_v1.json',
        ]) {
          await TerminologySeedImporter(db).importJson(
            File('assets/terminology/$file').readAsStringSync(),
            additive: file.startsWith('learning'),
          );
        }
        await db.setMetadata('private-marker', 'erase');
        await other.setMetadata('private-marker', 'preserve other profile');
        final image = await images.persistBytes(
          [1, 2, 3],
          pageNumber: 1,
          suffix: 'jpg',
        );
        final otherImage = await images.persistBytes(
          [4, 5],
          pageNumber: 1,
          suffix: 'jpg',
        );
        final work = await images.createTemporaryFile('jpg');
        await work.writeAsBytes([6, 7]);
        await LocalPrescriptionRepository(
          database: db,
          imageStore: images,
          sync: sync,
        ).createDraft(
          sourceType: PrescriptionSourceType.camera,
          pages: [image],
        );
        final now = DateTime.now().toUtc();
        final meds = LocalMedicationRepository(database: db);
        final plan = await meds.createPlan(
          CreateMedicationPlanRequest(
            sourceType: MedicationSourceType.manualEntry,
            displayName: 'Engineering fixture',
            confirmedDoseText: 'Reviewed fixture',
            confirmedFrequency: 'daily',
            confirmedInstruction: 'Engineering fixture only',
            startDate: now,
            timezone: 'UTC',
            scheduleType: MedicationScheduleType.onceDaily,
            reminderTimes: [480],
          ),
        );
        await meds.recordDose(
          planId: plan.plan.id,
          logicalDoseId: 'qa-dose',
          scheduledAt: now,
          action: DoseAction.taken,
          source: DoseEventSource.app,
        );
        await meds.addNote(plan.medication.id, 'Private fixture note');
        await LocalLearningRepository(db, sync).recordMeaningfulActivity(now);
        await db
            .into(db.savedContentItems)
            .insert(
              SavedContentItemsCompanion.insert(
                id: 'bookmark',
                contentId: 'term-hypertension',
                contentType: 'term',
                savedAt: now,
              ),
            );
        await sync.enqueue(
          entityType: 'prescription',
          entityId: 'already-removed',
          operationType: 'delete',
          payload: jsonEncode({
            'id': 'already-removed',
            syncDependenciesKey: ['discarded-upload'],
          }),
          tombstone: true,
        );
        var cancelled = 0;
        final eraser = LocalUserDataEraser(
          database: db,
          images: images,
          cancelNotifications: () async {
            cancelled++;
          },
          clearTemporaryFiles: images.clearTemporaryFiles,
          preferences: prefs,
        );
        await eraser.erase();
        expect(cancelled, 1);
        expect(prefs.clears, 1);
        expect(await File(image.localPath).exists(), isFalse);
        expect(await File(otherImage.localPath).exists(), isTrue);
        expect(await work.exists(), isFalse);
        expect(
          await other.getMetadata('private-marker'),
          'preserve other profile',
        );
        expect(await db.select(db.userMedications).get(), isEmpty);
        expect(await db.select(db.medicationPlans).get(), isEmpty);
        expect(await db.select(db.doseEvents).get(), isEmpty);
        expect(await db.select(db.medicationNotes).get(), isEmpty);
        expect(await db.select(db.prescriptions).get(), isEmpty);
        expect(await db.select(db.prescriptionPages).get(), isEmpty);
        expect(await db.select(db.savedContentItems).get(), isEmpty);
        expect(await db.select(db.learningStreaks).get(), isEmpty);
        expect(await db.getMetadata('private-marker'), isNull);
        expect(await db.select(db.learningLessons).get(), hasLength(30));
        expect(await db.select(db.flashcards).get(), hasLength(60));
        expect(await db.select(db.quizQuestions).get(), hasLength(4));
        expect(
          await db.customSelect('PRAGMA foreign_key_check').get(),
          isEmpty,
        );
        final retained = await db.select(db.syncOperations).getSingle();
        expect(retained.operationType, 'delete');
        expect(jsonDecode(retained.payload), {'id': 'already-removed'});
        await db.close();
        db = AppDatabase.forTesting(
          NativeDatabase(File('${directory.path}/profile.sqlite')),
        );
        expect(await db.select(db.prescriptions).get(), isEmpty);
        final transport = _Transport();
        await SyncCoordinator(database: db, transport: transport).synchronize();
        expect(transport.ids, ['already-removed']);
        expect(
          (await db.select(db.syncOperations).getSingle()).syncState,
          'synced',
        );
      } finally {
        sync.dispose();
        await db.close();
        await other.close();
        await directory.delete(recursive: true);
      }
    },
  );

  test(
    'failed image removal keeps records and preferences available for retry',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      final images = _Images();
      final prefs = MemoryPreferences();
      try {
        final now = DateTime.now();
        await db
            .into(db.prescriptions)
            .insert(
              PrescriptionsCompanion.insert(
                id: 'qa-scan',
                sourceType: 'camera',
                parserVersion: 'qa',
                pipelineState: 'rawCapture',
                captureDate: now,
                createdAt: now,
                updatedAt: now,
              ),
            );
        await db
            .into(db.prescriptionPages)
            .insert(
              PrescriptionPagesCompanion.insert(
                id: 'qa-page',
                prescriptionId: 'qa-scan',
                pageNumber: 1,
                originalImageId: const Value('image-id'),
                createdAt: now,
              ),
            );
        final eraser = LocalUserDataEraser(
          database: db,
          images: images,
          cancelNotifications: () async {},
          clearTemporaryFiles: () async {},
          preferences: prefs,
        );
        await expectLater(eraser.erase(), throwsA(isA<FileSystemException>()));
        expect(await db.select(db.prescriptions).get(), hasLength(1));
        expect(prefs.clears, 0);
        images.fail = false;
        await eraser.erase(preservePendingDeletions: false);
        expect(await db.select(db.prescriptions).get(), isEmpty);
        expect(prefs.clears, 1);
      } finally {
        await db.close();
      }
    },
  );

  for (final serverFails in [true, false]) {
    test(
      'account deletion requires remote success and retries local cleanup (serverFails=$serverFails)',
      () async {
        final manager = SessionManager(
          refreshClient: Dio(),
          vault: _Vault(),
          baseUrl: Uri.parse('https://api.example.test/api/v1/'),
        );
        final now = DateTime.now().toUtc();
        await manager.set(
          Session(
            id: 'qa-session',
            userId: 'qa-user',
            accessToken: 'qa-token',
            refreshToken: 'qa-refresh',
            accessTokenExpiresAt: now.add(const Duration(hours: 1)),
            createdAt: now,
          ),
        );
        var requests = 0;
        final dio =
            Dio(BaseOptions(baseUrl: 'https://api.example.test/api/v1/'))
              ..interceptors.add(
                InterceptorsWrapper(
                  onRequest: (request, handler) {
                    requests++;
                    expect(request.method, 'DELETE');
                    expect(request.uri.path, '/api/v1/users/me');
                    if (serverFails) {
                      handler.reject(
                        DioException(
                          requestOptions: request,
                          type: DioExceptionType.badResponse,
                          response: Response(
                            requestOptions: request,
                            statusCode: 503,
                          ),
                        ),
                      );
                    } else {
                      handler.resolve(
                        Response(requestOptions: request, statusCode: 204),
                      );
                    }
                  },
                ),
              );
        final api = ApiClient(
          baseUrl: Uri.parse('https://api.example.test/api/v1/'),
          sessionManager: manager,
          dio: dio,
        );
        var localClears = 0;
        var signOuts = 0;
        final service = AccountDeletionService(
          api: api,
          eraseLocal: () async {
            localClears++;
            if (localClears == 1) throw StateError('Synthetic cleanup failure');
          },
          signOut: () async {
            signOuts++;
            await manager.clear();
          },
        );
        await expectLater(service.delete(), throwsA(isA<Object>()));
        expect(signOuts, 0);
        if (serverFails) {
          expect(localClears, 0);
          expect(manager.current?.userId, 'qa-user');
        } else {
          expect(localClears, 1);
          await service.delete();
          expect(requests, 1);
          expect(localClears, 2);
          expect(signOuts, 1);
          expect(manager.current, isNull);
        }
        dio.close(force: true);
      },
    );
  }
}
