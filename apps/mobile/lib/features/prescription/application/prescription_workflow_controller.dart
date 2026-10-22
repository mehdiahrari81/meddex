import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../domain/models/confidence_result.dart';
import '../../../domain/providers/medical_providers.dart';
import '../../auth/application/auth_controller.dart';
import '../../settings/application/settings_controller.dart';
import '../domain/prescription_models.dart';
import '../domain/prescription_providers.dart';
import '../domain/prescription_repository.dart';
import 'prescription_providers.dart';
import 'prescription_error_message.dart';

enum PrescriptionProcessingStage {
  idle,
  importing,
  checkingQuality,
  preprocessing,
  readingPrescription,
  organizingInformation,
  reviewRequired,
  failed,
}

class PrescriptionWorkflowState {
  const PrescriptionWorkflowState({
    this.stage = PrescriptionProcessingStage.idle,
    this.prescription,
    this.pages = const [],
    this.quality = const [],
    this.ocrResults = const [],
    this.unclassifiedLines = const [],
    this.errorCode,
    this.errorMessage,
  });

  final PrescriptionProcessingStage stage;
  final Prescription? prescription;
  final List<ImageReference> pages;
  final List<CaptureQualityResult> quality;
  final List<PrescriptionOcrResult> ocrResults;
  final List<String> unclassifiedLines;
  final String? errorCode;
  final String? errorMessage;

  PrescriptionWorkflowState copyWith({
    PrescriptionProcessingStage? stage,
    Prescription? prescription,
    List<ImageReference>? pages,
    List<CaptureQualityResult>? quality,
    List<PrescriptionOcrResult>? ocrResults,
    List<String>? unclassifiedLines,
    String? errorCode,
    String? errorMessage,
    bool clearError = false,
  }) => PrescriptionWorkflowState(
    stage: stage ?? this.stage,
    prescription: prescription ?? this.prescription,
    pages: pages ?? this.pages,
    quality: quality ?? this.quality,
    ocrResults: ocrResults ?? this.ocrResults,
    unclassifiedLines: unclassifiedLines ?? this.unclassifiedLines,
    errorCode: clearError ? null : errorCode ?? this.errorCode,
    errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
  );
}

final prescriptionWorkflowControllerProvider =
    NotifierProvider<PrescriptionWorkflowController, PrescriptionWorkflowState>(
      PrescriptionWorkflowController.new,
    );

class PrescriptionWorkflowController
    extends Notifier<PrescriptionWorkflowState> {
  var _generation = 0;
  var _loadVersion = 0;

  @override
  PrescriptionWorkflowState build() => const PrescriptionWorkflowState();

  PrescriptionRepository get _repository =>
      ref.read(prescriptionRepositoryProvider);

  Future<String?> scanDocument() async {
    state = state.copyWith(
      stage: PrescriptionProcessingStage.importing,
      clearError: true,
    );
    try {
      final captured = await ref
          .read(prescriptionCaptureProvider)
          .scanDocument();
      if (captured.isEmpty) {
        state = state.copyWith(stage: PrescriptionProcessingStage.idle);
        return null;
      }
      return await _createDraft(captured);
    } on Object {
      state = state.copyWith(
        stage: PrescriptionProcessingStage.failed,
        errorCode: 'document_scan_failed',
      );
      return null;
    }
  }

  Future<String?> importGallery() async {
    state = state.copyWith(
      stage: PrescriptionProcessingStage.importing,
      clearError: true,
    );
    try {
      final captured = await ref
          .read(prescriptionCaptureProvider)
          .importFromGallery();
      if (captured == null) {
        state = state.copyWith(stage: PrescriptionProcessingStage.idle);
        return null;
      }
      return await _createDraft([captured]);
    } on Object {
      state = state.copyWith(
        stage: PrescriptionProcessingStage.failed,
        errorCode: 'gallery_import_failed',
      );
      return null;
    }
  }

  Future<String?> acceptCameraCapture(String sourcePath) async {
    state = state.copyWith(
      stage: PrescriptionProcessingStage.importing,
      clearError: true,
    );
    try {
      final captured = await ref
          .read(prescriptionCaptureProvider)
          .persistCameraCapture(sourcePath);
      return await _createDraft([captured]);
    } on Object {
      state = state.copyWith(
        stage: PrescriptionProcessingStage.failed,
        errorCode: 'camera_capture_failed',
      );
      return null;
    }
  }

  Future<String?> importFiles() async {
    state = state.copyWith(
      stage: PrescriptionProcessingStage.importing,
      clearError: true,
    );
    try {
      final captured = await ref
          .read(prescriptionCaptureProvider)
          .importFromFiles();
      if (captured.isEmpty) {
        state = state.copyWith(stage: PrescriptionProcessingStage.idle);
        return null;
      }
      return await _createDraft(captured);
    } on Object {
      state = state.copyWith(
        stage: PrescriptionProcessingStage.failed,
        errorCode: 'file_import_failed',
      );
      return null;
    }
  }

  Future<String?> _createDraft(List<CapturedPrescriptionPage> captured) async {
    final userId = ref
        .read(authControllerProvider)
        .valueOrNull
        ?.session
        ?.userId;
    final draft = await _repository.createDraft(
      sourceType: captured.first.sourceType,
      pages: captured.map((page) => page.image).toList(growable: false),
      userId: userId,
    );
    state = PrescriptionWorkflowState(
      stage: PrescriptionProcessingStage.idle,
      prescription: draft.prescription,
      pages: draft.pages,
    );
    return draft.prescription.id;
  }

  Future<String> createManual() async {
    final userId = ref
        .read(authControllerProvider)
        .valueOrNull
        ?.session
        ?.userId;
    final draft = await _repository.createManualDraft(userId: userId);
    state = PrescriptionWorkflowState(
      stage: PrescriptionProcessingStage.reviewRequired,
      prescription: draft.prescription,
    );
    return draft.prescription.id;
  }

  Future<void> loadDraft(String prescriptionId) async {
    final loadVersion = ++_loadVersion;
    final prescription = await _repository.get(prescriptionId);
    if (loadVersion != _loadVersion) return;
    if (prescription == null) {
      state = const PrescriptionWorkflowState(
        stage: PrescriptionProcessingStage.failed,
        errorCode: 'draft_not_found',
      );
      return;
    }
    final pages = await _repository.pages(prescriptionId);
    if (loadVersion != _loadVersion) return;
    state = PrescriptionWorkflowState(
      stage:
          prescription.pipelineState ==
              PrescriptionPipelineState.userReviewRequired
          ? PrescriptionProcessingStage.reviewRequired
          : PrescriptionProcessingStage.idle,
      prescription: prescription,
      pages: pages,
    );
  }

  Future<void> process(
    String prescriptionId, {
    OcrProvider? ocrOverride,
    bool useGemini = false,
  }) async {
    final generation = ++_generation;
    try {
      await loadDraft(prescriptionId);
      if (generation != _generation) return;
      final current = state.prescription;
      if (current == null) return;
      if (current.pipelineState ==
          PrescriptionPipelineState.userReviewRequired) {
        state = state.copyWith(
          stage: PrescriptionProcessingStage.reviewRequired,
        );
        return;
      }
      var pages = state.pages;
      if (current.pipelineState == PrescriptionPipelineState.rawCapture) {
        state = state.copyWith(
          stage: PrescriptionProcessingStage.checkingQuality,
        );
        final quality = <CaptureQualityResult>[];
        for (final page in pages) {
          quality.add(await ref.read(qualityAnalyzerProvider).analyze(page));
          if (generation != _generation) return;
        }
        if (generation != _generation) return;
        state = state.copyWith(
          stage: PrescriptionProcessingStage.preprocessing,
          quality: quality,
        );
        final processed = <PreprocessedImage>[];
        for (final page in pages) {
          processed.add(
            await ref.read(imagePreprocessorProvider).process(page),
          );
          if (generation != _generation) {
            final store = ref.read(prescriptionImageStoreProvider);
            for (final image in processed) {
              await store.delete(image.processed);
            }
            return;
          }
        }
        await _repository.storePreprocessed(prescriptionId, processed, quality);
        pages = processed.map((page) => page.processed).toList(growable: false);
        state = state.copyWith(pages: pages);
      }
      var refreshed = await _repository.get(prescriptionId);
      if (refreshed?.pipelineState ==
          PrescriptionPipelineState.preprocessedImage) {
        state = state.copyWith(
          stage: PrescriptionProcessingStage.readingPrescription,
        );
        final OcrProvider ocr =
            ocrOverride ?? ref.read<OcrProvider>(prescriptionOcrProvider);
        final results = <PrescriptionOcrResult>[];
        for (final page in pages) {
          results.add(await ocr.recognize(page));
          if (generation != _generation) return;
        }
        if (generation != _generation) return;
        if (results.every((result) => result.fullText.trim().isEmpty)) {
          state = state.copyWith(
            stage: PrescriptionProcessingStage.failed,
            errorCode: 'no_text_detected',
            ocrResults: results,
          );
          return;
        }
        await _repository.storeOcr(prescriptionId, results);
        state = state.copyWith(ocrResults: results);
      }
      refreshed = await _repository.get(prescriptionId);
      if (refreshed?.pipelineState == PrescriptionPipelineState.ocrResult) {
        state = state.copyWith(
          stage: PrescriptionProcessingStage.organizingInformation,
        );
        final items = <PrescriptionItem>[];
        final unknown = <String>[];
        final ocrResults = state.ocrResults.isNotEmpty
            ? state.ocrResults
            : await _loadOcrFromPrescription(refreshed!);
        String? parserVersion;
        if (useGemini) {
          final parsed = await ref
              .read(prescriptionTextStructurerProvider)
              .structure(
                prescriptionId: prescriptionId,
                pages: [
                  for (final result in ocrResults)
                    if (result.fullText.trim().isNotEmpty)
                      (pageNumber: result.pageNumber, text: result.fullText),
                ],
              );
          items.addAll(parsed.items);
          parserVersion = parsed.parserVersion;
        } else {
          for (final result in ocrResults) {
            final parsed = await ref
                .read(prescriptionParserProvider)
                .parse(
                  prescriptionId: prescriptionId,
                  rawText: result.fullText,
                  pageNumber: result.pageNumber,
                );
            items.addAll(parsed.items);
            unknown.addAll(parsed.unclassifiedLines);
          }
        }
        if (generation != _generation) return;
        await _repository.storeParsedItems(
          prescriptionId,
          items,
          parserVersion: parserVersion,
        );
        state = state.copyWith(unclassifiedLines: unknown);
      }
      await loadDraft(prescriptionId);
      state = state.copyWith(stage: PrescriptionProcessingStage.reviewRequired);
    } on Object catch (error) {
      if (generation == _generation) {
        state = state.copyWith(
          stage: PrescriptionProcessingStage.failed,
          errorCode:
              state.stage == PrescriptionProcessingStage.organizingInformation
              ? 'medicine_structuring_failed'
              : 'processing_failed',
          errorMessage: prescriptionErrorMessage(error),
        );
      }
    }
  }

  Future<void> storeAdjustedPage(ImageReference image) async {
    final id = state.prescription!.id;
    await _repository.storeAdjustedPage(id, image);
    await loadDraft(id);
  }

  Future<void> reparseCorrectedText(
    String correctedText, {
    String? ocrProvider,
    String? ocrProviderVersion,
    bool useGemini = false,
  }) async {
    final prescription = state.prescription!;
    final generation = ++_generation;
    final parsed = useGemini
        ? await ref
              .read(prescriptionTextStructurerProvider)
              .structure(
                prescriptionId: prescription.id,
                pages: [(pageNumber: 1, text: correctedText)],
              )
        : await ref
              .read(prescriptionParserProvider)
              .parse(
                prescriptionId: prescription.id,
                rawText: correctedText,
                pageNumber: 1,
              );
    if (generation != _generation) return;
    await _repository.replaceParsedItemsFromCorrectedText(
      prescription.id,
      correctedText,
      parsed.items,
      ocrProvider: ocrProvider,
      ocrProviderVersion: ocrProviderVersion,
      parserVersion: parsed.parserVersion,
    );
    await loadDraft(prescription.id);
  }

  Future<List<PrescriptionOcrResult>> _loadOcrFromPrescription(
    Prescription prescription,
  ) async {
    final stored = await _repository.ocrResults(prescription.id);
    if (stored.isNotEmpty) return stored;
    final raw = prescription.rawOcrText;
    if (raw == null) return const [];
    return [
      PrescriptionOcrResult(
        id: const Uuid().v4(),
        pageNumber: 1,
        fullText: raw,
        blocks: const [],
        provider: prescription.ocrProvider ?? 'stored',
        providerVersion: prescription.ocrProviderVersion ?? 'unknown',
        processedAt: prescription.updatedAt,
        script: OcrScript.unknown,
      ),
    ];
  }

  void cancelProcessing() {
    _generation++;
    state = state.copyWith(stage: PrescriptionProcessingStage.idle);
  }

  Future<void> editField(
    String itemId,
    PrescriptionFieldType type,
    String value,
  ) async {
    final prescription = state.prescription!;
    final item = prescription.items.firstWhere(
      (candidate) => candidate.id == itemId,
    );
    await _repository.editField(
      prescription.id,
      itemId,
      item.field(type).edit(value, DateTime.now()),
    );
    await loadDraft(prescription.id);
  }

  Future<void> confirmField(String itemId, PrescriptionFieldType type) async {
    final id = state.prescription!.id;
    await _repository.confirmField(id, itemId, type);
    await loadDraft(id);
  }

  Future<void> confirmItem(String itemId) async {
    final id = state.prescription!.id;
    var item = state.prescription!.items.firstWhere(
      (value) => value.id == itemId,
    );
    if (item.state == PrescriptionItemState.needsReview ||
        item.state == PrescriptionItemState.edited ||
        item.state == PrescriptionItemState.unresolved) {
      await _repository.setItemState(
        id,
        itemId,
        PrescriptionItemState.confirmedByUser,
      );
    }
    await loadDraft(id);
    item = state.prescription!.items.firstWhere((value) => value.id == itemId);
    if (item.state == PrescriptionItemState.confirmedByUser) {
      await _repository.setItemState(
        id,
        itemId,
        PrescriptionItemState.readyForLookup,
      );
    }
    await loadDraft(id);
  }

  Future<void> confirmReviewedItem(String itemId) async {
    final id = state.prescription!.id;
    await _repository.confirmReviewedItem(id, itemId);
    await loadDraft(id);
  }

  Future<void> addManualItem(Map<PrescriptionFieldType, String> values) async {
    final prescription = state.prescription!;
    final now = DateTime.now().toUtc();
    final fields = <PrescriptionFieldType, ParsedField>{
      for (final entry in values.entries)
        if (entry.value.trim().isNotEmpty)
          entry.key: ParsedField(
            type: entry.key,
            originalValue: null,
            currentValue: entry.value.trim(),
            source: FieldValueSource.user,
            confidence: ConfidenceBand.unknown,
            ambiguous: false,
            userConfirmed: false,
            changedAt: now,
          ),
    };
    final name = fields[PrescriptionFieldType.medicationName];
    if (name == null) throw StateError('Medicine name is required.');
    final item = PrescriptionItem(
      id: const Uuid().v4(),
      prescriptionId: prescription.id,
      rawMedicationText: name.currentValue!,
      sourceText: values.values.where((value) => value.isNotEmpty).join(' '),
      pageNumber: 0,
      lineNumber: 0,
      fields: fields,
      state: PrescriptionItemState.edited,
      createdAt: now,
      updatedAt: now,
    );
    await _repository.addManualItem(prescription.id, item);
    await loadDraft(prescription.id);
  }

  Future<void> deleteItem(String itemId) async {
    _generation++;
    _loadVersion++;
    final id = state.prescription!.id;
    await _repository.deleteItem(id, itemId);
    await loadDraft(id);
  }

  Future<void> deletePrescription(String prescriptionId) async {
    if (state.prescription?.id == prescriptionId) {
      _generation++;
      _loadVersion++;
    }
    await _repository.deletePrescription(prescriptionId);
    if (state.prescription?.id == prescriptionId) {
      state = const PrescriptionWorkflowState();
    }
    ref.invalidate(latestPrescriptionDraftProvider);
    ref.invalidate(prescriptionDetailProvider(prescriptionId));
    ref.invalidate(prescriptionPagesProvider(prescriptionId));
  }

  Future<void> saveUnresolved() async {
    final id = state.prescription!.id;
    await _repository.saveUnresolved(id);
    await loadDraft(id);
  }

  Future<void> confirmPrescription() async {
    final prescription = state.prescription!;
    final id = prescription.id;
    final retained = prescription.items
        .where((item) => item.state != PrescriptionItemState.rejected)
        .toList();
    if (retained.isEmpty ||
        retained.any(
          (item) =>
              !item.field(PrescriptionFieldType.medicationName).hasValue ||
              item.state == PrescriptionItemState.detected ||
              item.fields.values.any((field) => field.needsClarification),
        )) {
      throw StateError('Check unclear fields before confirming.');
    }
    for (final item in retained) {
      for (final field in item.fields.values) {
        if (field.hasValue && !field.userConfirmed) {
          await _repository.confirmField(id, item.id, field.type);
        }
      }
      // The final Add action explicitly confirms the entire reviewed list.
      // An explanation alone never enters this confirmation path.
      if (item.state != PrescriptionItemState.readyForLookup) {
        if (item.state != PrescriptionItemState.confirmedByUser) {
          await _repository.setItemState(
            id,
            item.id,
            PrescriptionItemState.confirmedByUser,
          );
        }
        await _repository.setItemState(
          id,
          item.id,
          PrescriptionItemState.readyForLookup,
        );
      }
    }
    await _repository.confirmPrescription(id);
    final deleteImages =
        ref
            .read(settingsControllerProvider)
            .valueOrNull
            ?.deletePrescriptionImagesAfterConfirmation ??
        true;
    if (deleteImages) await _repository.deleteImages(id);
    await loadDraft(id);
  }
}
