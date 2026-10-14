import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediexplain/core/database/app_database.dart'
    hide PrescriptionItem, PrescriptionOcrResult;
import 'package:mediexplain/core/sync/sync_coordinator.dart';
import 'package:mediexplain/domain/providers/medical_providers.dart';
import 'package:mediexplain/features/prescription/application/prescription_parsers.dart';
import 'package:mediexplain/features/prescription/data/local_prescription_repository.dart';
import 'package:mediexplain/features/prescription/domain/prescription_models.dart';
import 'package:mediexplain/features/prescription/domain/prescription_providers.dart';

void main() {
  test(
    'offline capture through restart, confirmation and reconnect sync',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'mediexplain-pipeline-integration-',
      );
      addTearDown(() => root.delete(recursive: true));
      final databaseFile = File('${root.path}/offline.sqlite');
      final source = File('${root.path}/synthetic-prescription.jpg');
      await source.writeAsBytes([1, 2, 3, 4]);
      final images = _IntegrationImageStore();
      final captured = await images.persistImported(source.path, pageNumber: 1);
      final offlineTransport = _OfflineTransport();
      var database = AppDatabase.forTesting(NativeDatabase(databaseFile));
      var repository = LocalPrescriptionRepository(
        database: database,
        imageStore: images,
        sync: SyncCoordinator(database: database, transport: offlineTransport),
      );

      final draft = await repository.createDraft(
        sourceType: PrescriptionSourceType.fileImport,
        pages: [captured],
      );
      await repository.storePreprocessed(
        draft.prescription.id,
        [
          PreprocessedImage(
            original: captured,
            processed: captured,
            metadata: PreprocessingMetadata(
              operations: const ['orientation'],
              originalWidth: 1200,
              originalHeight: 1600,
              outputWidth: 1200,
              outputHeight: 1600,
              createdAt: DateTime.utc(2026, 8, 13),
            ),
          ),
        ],
        [const CaptureQualityResult(issues: {}, confidenceByIssue: {})],
      );
      final ocr = await const _SyntheticOcrProvider().recognize(captured);
      await repository.storeOcr(draft.prescription.id, [ocr]);
      final parsed = await _parser.parse(
        prescriptionId: draft.prescription.id,
        rawText: ocr.fullText,
        pageNumber: 1,
      );
      await repository.storeParsedItems(draft.prescription.id, parsed.items);

      final beforeRestart = await repository.get(draft.prescription.id);
      expect(
        beforeRestart!.pipelineState,
        PrescriptionPipelineState.userReviewRequired,
      );
      expect(beforeRestart.rawOcrText, contains('Amoxici1lin'));
      expect(beforeRestart.items.single.frequency!.timesPerDay, 3);
      await database.close();

      database = AppDatabase.forTesting(NativeDatabase(databaseFile));
      final onlineTransport = _RecordingTransport();
      repository = LocalPrescriptionRepository(
        database: database,
        imageStore: images,
        sync: SyncCoordinator(database: database, transport: onlineTransport),
      );
      addTearDown(database.close);
      final restored = await repository.latestDraft();
      expect(restored!.id, draft.prescription.id);
      final item = restored.items.single;
      final correctedName = item
          .field(PrescriptionFieldType.medicationName)
          .edit('Amoxicillin', DateTime.utc(2026, 8, 13, 1));
      await repository.editField(restored.id, item.id, correctedName);
      await repository.confirmField(
        restored.id,
        item.id,
        PrescriptionFieldType.medicationName,
      );
      await repository.setItemState(
        restored.id,
        item.id,
        PrescriptionItemState.confirmedByUser,
      );
      await repository.setItemState(
        restored.id,
        item.id,
        PrescriptionItemState.readyForLookup,
      );
      await repository.confirmPrescription(restored.id);

      final confirmed = await repository.get(restored.id);
      expect(
        confirmed!.pipelineState,
        PrescriptionPipelineState.readyForMedicationLookup,
      );
      expect(
        confirmed.items.single
            .field(PrescriptionFieldType.medicationName)
            .currentValue,
        'Amoxicillin',
      );
      expect(confirmed.rawOcrText, contains('Amoxici1lin'));
      expect(
        () => repository.replaceParsedItemsFromCorrectedText(
          restored.id,
          'A new machine guess',
          const [],
        ),
        throwsStateError,
      );

      final coordinator = SyncCoordinator(
        database: database,
        transport: onlineTransport,
      );
      await coordinator.synchronize();
      expect(onlineTransport.sent, hasLength(1));
      expect(onlineTransport.sent.single.entityType, 'prescription');
      expect(
        onlineTransport.sent.single.payload,
        isNot(contains('raw_ocr_text')),
      );
      expect(
        onlineTransport.sent.single.payload,
        isNot(contains('source_text')),
      );
      expect(onlineTransport.sent.single.payload, isNot(contains(source.path)));
    },
  );
}

const _parser = PrescriptionParser(
  normalizer: ConservativeOcrNormalizer(),
  segmenter: PrescriptionLineSegmenter(
    MedicationCandidateParser(NoMedicationCandidateSuggestionService()),
    StrengthParser(),
  ),
  medicationParser: MedicationCandidateParser(
    NoMedicationCandidateSuggestionService(),
  ),
  strengthParser: StrengthParser(),
  formParser: DosageFormParser(),
  doseParser: DoseParser(),
  routeParser: RouteParser(_IntegrationAbbreviationResolver()),
  frequencyParser: FrequencyParser(_IntegrationAbbreviationResolver()),
  durationParser: DurationParser(),
  instructionParser: InstructionParser(),
  dateParser: DateParser(),
);

class _SyntheticOcrProvider implements OcrProvider {
  const _SyntheticOcrProvider();

  @override
  Future<PrescriptionOcrResult> recognize(
    ImageReference imageReference,
  ) async => PrescriptionOcrResult(
    id: '33333333-3333-4333-8333-333333333333',
    pageNumber: imageReference.pageNumber,
    fullText: 'Amoxici1lin 500 mg\n1 capsule PO TID x 7 days with food',
    blocks: const [],
    provider: 'synthetic_on_device_test',
    providerVersion: '1.0.0',
    processedAt: DateTime.utc(2026, 8, 13),
    script: OcrScript.latin,
  );
}

class _IntegrationAbbreviationResolver
    implements PrescriptionAbbreviationResolver {
  const _IntegrationAbbreviationResolver();

  @override
  Future<AbbreviationResolution> resolve(String abbreviation) async {
    final meanings = switch (abbreviation.toUpperCase()) {
      'PO' => const ['by mouth'],
      'TID' => const ['three times daily'],
      _ => const <String>[],
    };
    return AbbreviationResolution(
      detected: abbreviation,
      possibleMeanings: meanings,
      ambiguous: meanings.length != 1,
    );
  }
}

class _IntegrationImageStore implements PrescriptionImageStore {
  final _values = <String, ImageReference>{};

  @override
  Future<ImageReference> persistImported(
    String sourcePath, {
    required int pageNumber,
  }) async {
    final image = ImageReference(
      privateId: '11111111-1111-4111-8111-111111111111',
      localPath: sourcePath,
      pageNumber: pageNumber,
    );
    _values[image.privateId] = image;
    return image;
  }

  @override
  Future<ImageReference> persistBytes(
    List<int> bytes, {
    required int pageNumber,
    required String suffix,
  }) => throw UnimplementedError();

  @override
  Future<ImageReference?> resolve(
    String privateId, {
    required int pageNumber,
  }) async => _values[privateId];

  @override
  Future<void> delete(ImageReference image) =>
      deleteByPrivateId(image.privateId);

  @override
  Future<void> deleteByPrivateId(String privateId) async {
    _values.remove(privateId);
  }

  @override
  Future<void> cleanupTemporaryFiles() async {}
}

class _OfflineTransport implements SyncTransport {
  @override
  Future<SyncReceipt> send(SyncOperation operation) =>
      throw const SocketException('offline');
}

class _RecordingTransport implements SyncTransport {
  final sent = <SyncOperation>[];

  @override
  Future<SyncReceipt> send(SyncOperation operation) async {
    sent.add(operation);
    return const SyncReceipt(serverRevision: 'server-revision-1');
  }
}
