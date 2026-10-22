import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediexplain/core/database/app_database.dart'
    hide PrescriptionItem;
import 'package:mediexplain/core/sync/sync_coordinator.dart';
import 'package:mediexplain/domain/models/confidence_result.dart';
import 'package:mediexplain/features/prescription/data/local_prescription_repository.dart';
import 'package:mediexplain/features/prescription/domain/prescription_models.dart';
import 'package:mediexplain/features/prescription/domain/prescription_providers.dart';

void main() {
  late AppDatabase database;
  late _MemoryImageStore images;
  late LocalPrescriptionRepository repository;
  final now = DateTime.utc(2026, 8, 13, 2);

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    images = _MemoryImageStore();
    repository = LocalPrescriptionRepository(
      database: database,
      imageStore: images,
      sync: SyncCoordinator(
        database: database,
        transport: const DisabledSyncTransport(),
        clock: () => now,
      ),
      clock: () => now,
    );
  });

  tearDown(() => database.close());

  test(
    'manual draft, item edits, unresolved save and restart recovery',
    () async {
      final draft = await repository.createManualDraft();
      final item = _manualItem(draft.prescription.id, now);
      await repository.addManualItem(draft.prescription.id, item);
      await repository.editField(
        draft.prescription.id,
        item.id,
        item
            .field(PrescriptionFieldType.strength)
            .edit('500 mg', now.add(const Duration(minutes: 1))),
      );
      await repository.saveUnresolved(draft.prescription.id);

      final restored = await repository.latestDraft();
      expect(restored, isNotNull);
      expect(restored!.id, draft.prescription.id);
      expect(restored.items.single.state, PrescriptionItemState.unresolved);
      expect(
        restored.items.single
            .field(PrescriptionFieldType.strength)
            .currentValue,
        '500 mg',
      );
      expect(
        await database.select(database.prescriptionFieldEdits).get(),
        hasLength(1),
      );
    },
  );

  test('confirmation requires confirmed medicine identity', () async {
    final draft = await repository.createManualDraft();
    final item = _manualItem(draft.prescription.id, now);
    await repository.addManualItem(draft.prescription.id, item);
    expect(
      () => repository.setItemState(
        draft.prescription.id,
        item.id,
        PrescriptionItemState.confirmedByUser,
      ),
      throwsStateError,
    );
    await repository.confirmField(
      draft.prescription.id,
      item.id,
      PrescriptionFieldType.medicationName,
    );
    await repository.setItemState(
      draft.prescription.id,
      item.id,
      PrescriptionItemState.confirmedByUser,
    );
    await repository.setItemState(
      draft.prescription.id,
      item.id,
      PrescriptionItemState.readyForLookup,
    );
    await repository.confirmPrescription(draft.prescription.id);

    final confirmed = await repository.get(draft.prescription.id);
    expect(
      confirmed!.pipelineState,
      PrescriptionPipelineState.readyForMedicationLookup,
    );
    final operations = await database.select(database.syncOperations).get();
    expect(operations.single.payload, isNot(contains('raw_ocr_text')));
    expect(operations.single.payload, isNot(contains('image')));
  });

  test(
    'AI retry from stored OCR advances review and protects individually confirmed fields',
    () async {
      final draft = await repository.createManualDraft();
      await database.customStatement(
        'UPDATE prescriptions SET pipeline_state = ? WHERE id = ?',
        [PrescriptionPipelineState.ocrResult.name, draft.prescription.id],
      );
      final item = _manualItem(draft.prescription.id, now);
      await repository.replaceParsedItemsFromCorrectedText(
        draft.prescription.id,
        'Synthetic QA OCR text',
        [item],
        parserVersion: 'gemini-text-v1:qa',
      );
      final restored = await repository.get(draft.prescription.id);
      expect(
        restored!.pipelineState,
        PrescriptionPipelineState.userReviewRequired,
      );
      expect(restored.parserVersion, 'gemini-text-v1:qa');
      await repository.confirmField(
        draft.prescription.id,
        item.id,
        PrescriptionFieldType.medicationName,
      );
      await expectLater(
        repository.replaceParsedItemsFromCorrectedText(
          draft.prescription.id,
          'replacement',
          [],
        ),
        throwsStateError,
      );
      await repository.setItemState(
        draft.prescription.id,
        item.id,
        PrescriptionItemState.confirmedByUser,
      );
      await repository.setItemState(
        draft.prescription.id,
        item.id,
        PrescriptionItemState.readyForLookup,
      );
      await repository.confirmPrescription(draft.prescription.id);
      expect(
        (await repository.get(draft.prescription.id))!.pipelineState,
        PrescriptionPipelineState.readyForMedicationLookup,
      );
    },
  );

  test('image-only deletion clears private files but retains fields', () async {
    final tempDirectory = await Directory.systemTemp.createTemp(
      'mediexplain-prescription-test-',
    );
    addTearDown(() => tempDirectory.delete(recursive: true));
    final sourceFile = File('${tempDirectory.path}/source.jpg');
    await sourceFile.writeAsBytes([1, 2, 3, 4]);
    final original = ImageReference(
      privateId: '11111111-1111-1111-1111-111111111111',
      localPath: sourceFile.path,
      pageNumber: 1,
    );
    images.values[original.privateId] = original;
    final draft = await repository.createDraft(
      sourceType: PrescriptionSourceType.camera,
      pages: [original],
    );

    await repository.deleteImages(draft.prescription.id);

    expect(images.deleted, contains(original.privateId));
    expect(await repository.get(draft.prescription.id), isNotNull);
    final page = await database.select(database.prescriptionPages).getSingle();
    expect(page.originalImageId, isNull);
  });

  test('entire deletion queues tombstone and removes history item', () async {
    final draft = await repository.createManualDraft();
    await repository.deletePrescription(draft.prescription.id);
    expect(await repository.get(draft.prescription.id), isNull);
    final operation = await database
        .select(database.syncOperations)
        .getSingle();
    expect(operation.tombstone, isTrue);
    expect(operation.entityType, 'prescription');
  });

  test(
    'confirmed barcode is stored as an unresolved identifier and queued',
    () async {
      final barcode = BarcodeCapture(
        id: '22222222-2222-4222-8222-222222222222',
        format: 'ean13',
        rawValue: '1234567890128',
        scannedAt: now,
        source: 'device_camera',
        userConfirmed: true,
      );

      await repository.saveBarcode(barcode);

      final saved = await repository.recentBarcodes();
      expect(saved.single.id, barcode.id);
      expect(saved.single.rawValue, barcode.rawValue);
      expect(saved.single.userConfirmed, isTrue);
      final operation = await database
          .select(database.syncOperations)
          .getSingle();
      expect(operation.entityType, 'barcode_scan');
      expect(operation.payload, contains('1234567890128'));
      expect(operation.payload, isNot(contains('medicine_name')));
    },
  );
}

PrescriptionItem _manualItem(String prescriptionId, DateTime now) =>
    PrescriptionItem(
      id: 'item-1',
      prescriptionId: prescriptionId,
      rawMedicationText: 'Amoxicillin',
      sourceText: 'Amoxicillin',
      pageNumber: 0,
      lineNumber: 0,
      fields: {
        PrescriptionFieldType.medicationName: const ParsedField(
          type: PrescriptionFieldType.medicationName,
          originalValue: null,
          currentValue: 'Amoxicillin',
          source: FieldValueSource.user,
          confidence: ConfidenceBand.unknown,
          ambiguous: false,
          userConfirmed: false,
        ),
        PrescriptionFieldType.strength: const ParsedField(
          type: PrescriptionFieldType.strength,
          originalValue: null,
          currentValue: '5O mg',
          source: FieldValueSource.user,
          confidence: ConfidenceBand.unknown,
          ambiguous: false,
          userConfirmed: false,
        ),
      },
      state: PrescriptionItemState.edited,
      createdAt: now,
      updatedAt: now,
    );

class _MemoryImageStore implements PrescriptionImageStore {
  final values = <String, ImageReference>{};
  final deleted = <String>[];

  @override
  Future<void> cleanupTemporaryFiles() async {}

  @override
  Future<void> delete(ImageReference image) =>
      deleteByPrivateId(image.privateId);

  @override
  Future<void> deleteByPrivateId(String privateId) async {
    deleted.add(privateId);
    values.remove(privateId);
  }

  @override
  Future<ImageReference> persistBytes(
    List<int> bytes, {
    required int pageNumber,
    required String suffix,
  }) => throw UnimplementedError();

  @override
  Future<ImageReference> persistImported(
    String sourcePath, {
    required int pageNumber,
  }) => throw UnimplementedError();

  @override
  Future<ImageReference?> resolve(
    String privateId, {
    required int pageNumber,
  }) async => values[privateId];
}
