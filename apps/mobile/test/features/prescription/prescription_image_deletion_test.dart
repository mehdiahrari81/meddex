import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediexplain/core/database/app_database.dart';
import 'package:mediexplain/core/sync/sync_coordinator.dart';
import 'package:mediexplain/features/prescription/data/local_prescription_repository.dart';
import 'package:mediexplain/features/prescription/data/private_image_store.dart';
import 'package:mediexplain/features/prescription/domain/prescription_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'deleting a scanned multipage draft removes private files and stays deleted after restart',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'mediexplain-image-deletion-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final databaseFile = File('${directory.path}/prescriptions.sqlite');
      var database = AppDatabase.forTesting(NativeDatabase(databaseFile));
      addTearDown(() => database.close());
      final images = PrivatePrescriptionImageStore(
        supportDirectory: () async => directory,
      );
      LocalPrescriptionRepository repository() => LocalPrescriptionRepository(
        database: database,
        imageStore: images,
        sync: SyncCoordinator(
          database: database,
          transport: const DisabledSyncTransport(),
        ),
      );
      final first = await images.persistBytes(
        [1, 2, 3],
        pageNumber: 1,
        suffix: 'jpg',
      );
      final second = await images.persistBytes(
        [4, 5, 6],
        pageNumber: 2,
        suffix: 'png',
      );
      final preserved = await images.persistBytes(
        [7, 8, 9],
        pageNumber: 1,
        suffix: 'jpg',
      );
      final scanned = await repository().createDraft(
        sourceType: PrescriptionSourceType.camera,
        pages: [first, second],
      );
      final otherScan = await repository().createDraft(
        sourceType: PrescriptionSourceType.gallery,
        pages: [preserved],
      );

      await repository().deletePrescription(scanned.prescription.id);
      expect(await File(first.localPath).exists(), isFalse);
      expect(await File(second.localPath).exists(), isFalse);
      expect(await File(preserved.localPath).exists(), isTrue);
      expect(await repository().get(scanned.prescription.id), isNull);
      expect(await repository().pages(scanned.prescription.id), isEmpty);
      expect(await repository().get(otherScan.prescription.id), isNotNull);

      await database.close();
      database = AppDatabase.forTesting(NativeDatabase(databaseFile));
      expect(await repository().get(scanned.prescription.id), isNull);
      expect(
        (await repository().watchHistory().first).map((entry) => entry.id),
        [otherScan.prescription.id],
      );
      final deletion = await database
          .select(database.syncOperations)
          .getSingle();
      expect(deletion.entityId, scanned.prescription.id);
      expect(deletion.operationType, 'delete');
      expect(deletion.tombstone, isTrue);

      // A retry after app restart is safe even though the files are gone.
      await repository().deletePrescription(scanned.prescription.id);
      expect(await File(preserved.localPath).exists(), isTrue);
      expect(
        await database.customSelect('PRAGMA foreign_key_check').get(),
        isEmpty,
      );
    },
  );

  test(
    'deleting latest scanned draft reveals the older draft and does not restore the deleted one',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'mediexplain-multiple-drafts-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      final images = PrivatePrescriptionImageStore(
        supportDirectory: () async => directory,
      );
      var now = DateTime.utc(2026, 10, 18, 10);
      final repository = LocalPrescriptionRepository(
        database: database,
        imageStore: images,
        sync: SyncCoordinator(
          database: database,
          transport: const DisabledSyncTransport(),
        ),
        clock: () => now,
      );
      final olderImage = await images.persistBytes(
        [1, 2, 3],
        pageNumber: 1,
        suffix: 'jpg',
      );
      final older = await repository.createDraft(
        sourceType: PrescriptionSourceType.camera,
        pages: [olderImage],
      );
      now = now.add(const Duration(minutes: 1));
      final newerImage = await images.persistBytes(
        [4, 5, 6],
        pageNumber: 1,
        suffix: 'jpg',
      );
      final newer = await repository.createDraft(
        sourceType: PrescriptionSourceType.camera,
        pages: [newerImage],
      );
      expect((await repository.latestDraft())!.id, newer.prescription.id);

      await repository.deletePrescription(newer.prescription.id);
      expect(await repository.get(newer.prescription.id), isNull);
      expect((await repository.latestDraft())!.id, older.prescription.id);
      expect(await File(newerImage.localPath).exists(), isFalse);
      expect(await File(olderImage.localPath).exists(), isTrue);

      // Deleted or OS-cleaned image files must not prevent deleting the draft.
      await File(olderImage.localPath).delete();
      await repository.deletePrescription(older.prescription.id);
      expect(await repository.latestDraft(), isNull);
      expect(await repository.watchHistory().first, isEmpty);
    },
  );
}
