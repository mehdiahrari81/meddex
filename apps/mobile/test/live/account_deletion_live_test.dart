// Opt-in local API check. Uses a disposable QA account and isolated local files;
// it never deletes an existing user's account or invokes cloud AI.
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediexplain/core/auth/auth_repository.dart';
import 'package:mediexplain/core/database/app_database.dart';
import 'package:mediexplain/core/network/api_client.dart';
import 'package:mediexplain/core/storage/session_vault.dart';
import 'package:mediexplain/core/sync/sync_coordinator.dart';
import 'package:mediexplain/domain/models/session.dart';
import 'package:mediexplain/features/learning/data/local_learning_repository.dart';
import 'package:mediexplain/features/prescription/data/local_prescription_repository.dart';
import 'package:mediexplain/features/prescription/data/private_image_store.dart';
import 'package:mediexplain/features/prescription/domain/prescription_models.dart';
import 'package:mediexplain/features/settings/application/data_management.dart';
import 'package:mediexplain/features/settings/data/settings_repository.dart';

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

class _Preferences implements SettingsRepository {
  bool cleared = false;
  @override
  Future<void> clearLocalPreferences() async {
    cleared = true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  const base = String.fromEnvironment('LIVE_API_BASE_URL');
  test(
    'account deletion revokes real server access, erases local data and clears credentials',
    () async {
      HttpOverrides.global = null;
      final manager = SessionManager(
        refreshClient: Dio(),
        vault: _Vault(),
        baseUrl: Uri.parse(base),
      );
      final api = ApiClient(baseUrl: Uri.parse(base), sessionManager: manager);
      final auth = ApiAuthRepository(api, manager);
      final directory = await Directory.systemTemp.createTemp(
        'meddex-account-delete-',
      );
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      final sync = SyncCoordinator(
        database: database,
        transport: const DisabledSyncTransport(),
      );
      final images = PrivatePrescriptionImageStore(
        supportDirectory: () async => directory,
        temporaryDirectory: () async => directory,
      );
      final preferences = _Preferences();
      final email =
          'account-delete-qa-${DateTime.now().microsecondsSinceEpoch}@example.com';
      final password =
          'TemporaryEngineering!${DateTime.now().microsecondsSinceEpoch}';
      try {
        await auth.register(
          email: email,
          password: password,
          displayName: 'Temporary account-deletion QA',
        );
        final image = await images.persistBytes(
          [1, 2, 3],
          pageNumber: 1,
          suffix: 'jpg',
        );
        await LocalPrescriptionRepository(
          database: database,
          imageStore: images,
          sync: sync,
        ).createDraft(
          sourceType: PrescriptionSourceType.camera,
          pages: [image],
        );
        await LocalLearningRepository(
          database,
          sync,
        ).recordMeaningfulActivity(DateTime.now());
        var notificationsCancelled = false;
        final eraser = LocalUserDataEraser(
          database: database,
          images: images,
          preferences: preferences,
          clearTemporaryFiles: images.clearTemporaryFiles,
          cancelNotifications: () async {
            notificationsCancelled = true;
          },
        );
        final service = AccountDeletionService(
          api: api,
          eraseLocal: () => eraser.erase(preservePendingDeletions: false),
          signOut: auth.signOut,
        );
        await service.delete();
        expect(manager.current, isNull);
        expect(preferences.cleared, isTrue);
        expect(notificationsCancelled, isTrue);
        expect(await File(image.localPath).exists(), isFalse);
        expect(await database.select(database.prescriptions).get(), isEmpty);
        expect(await database.select(database.learningStreaks).get(), isEmpty);
        expect(await database.select(database.syncOperations).get(), isEmpty);
        await expectLater(
          auth.signIn(email: email, password: password),
          throwsA(isA<Object>()),
        );
        expect(manager.current, isNull);
      } finally {
        if (manager.current != null) {
          try {
            await api.delete('users/me');
          } on Object {
            /* Only this test's account. */
          }
        }
        await auth.signOut();
        api.dio.close(force: true);
        sync.dispose();
        await database.close();
        await directory.delete(recursive: true);
      }
    },
    skip: base.isEmpty,
    timeout: const Timeout(Duration(minutes: 1)),
  );
}
