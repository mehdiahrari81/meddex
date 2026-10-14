import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../domain/models/confidence_result.dart';
import '../../auth/application/auth_controller.dart';
import '../../settings/application/settings_controller.dart';
import '../domain/prescription_models.dart';
import '../domain/prescription_providers.dart';
import '../domain/prescription_repository.dart';
import 'prescription_providers.dart';

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
  });

  final PrescriptionProcessingStage stage;
  final Prescription? prescription;
  final List<ImageReference> pages;
  final List<CaptureQualityResult> quality;
  final List<PrescriptionOcrResult> ocrResults;
  final List<String> unclassifiedLines;
  final String? errorCode;

  PrescriptionWorkflowState copyWith({
    PrescriptionProcessingStage? stage,
    Prescription? prescription,
    List<ImageReference>? pages,
    List<CaptureQualityResult>? quality,
    List<PrescriptionOcrResult>? ocrResults,
    List<String>? unclassifiedLines,
    String? errorCode,
    bool clearError = false,
  }) => PrescriptionWorkflowState(
    stage: stage ?? this.stage,
    prescription: prescription ?? this.prescription,
    pages: pages ?? this.pages,
    quality: quality ?? this.quality,
    ocrResults: ocrResults ?? this.ocrResults,
    unclassifiedLines: unclassifiedLines ?? this.unclassifiedLines,
    errorCode: clearError ? null : errorCode ?? this.errorCode,
  );
}

final prescriptionWorkflowControllerProvider =
    NotifierProvider<PrescriptionWorkflowController, PrescriptionWorkflowState>(
      PrescriptionWorkflowController.new,
    );

class PrescriptionWorkflowController
    extends Notifier<PrescriptionWorkflowState> {
  var _generation = 0;

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
      return _createDraft(captured);
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
      return _createDraft([captured]);
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
      return _createDraft([captured]);
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
      return _createDraft(captured);
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
    final prescription = await _repository.get(prescriptionId);
    if (prescription == null) {
      state = state.copyWith(
        stage: PrescriptionProcessingStage.failed,
        errorCode: 'draft_not_found',
      );
      return;
    }
    state = PrescriptionWorkflowState(
      stage:
          prescription.pipelineState ==
              PrescriptionPipelineState.userReviewRequired
          ? PrescriptionProcessingStage.reviewRequired
          : PrescriptionProcessingStage.idle,
      prescription: prescription,
      pages: await _repository.pages(prescriptionId),
    );
  }

  Future<void> process(String prescriptionId) async {
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
        final quality = await Future.wait(
          pages.map((page) => ref.read(qualityAnalyzerProvider).analyze(page)),
        );
        if (generation != _generation) return;
        state = state.copyWith(
          stage: PrescriptionProcessingStage.preprocessing,
          quality: quality,
        );
        final processed = await Future.wait(
          pages.map(
            (page) => ref.read(imagePreprocessorProvider).process(page),
          ),
        );
        if (generation != _generation) return;
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
        final results = await Future.wait(
          pages.map(
            (page) => ref.read(prescriptionOcrProvider).recognize(page),
          ),
        );
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
        if (generation != _generation) return;
        await _repository.storeParsedItems(prescriptionId, items);
        state = state.copyWith(unclassifiedLines: unknown);
      }
      await loadDraft(prescriptionId);
      state = state.copyWith(stage: PrescriptionProcessingStage.reviewRequired);
    } on Object {
      if (generation == _generation) {
        state = state.copyWith(
          stage: PrescriptionProcessingStage.failed,
          errorCode: 'processing_failed',
        );
      }
    }
  }

  Future<void> storeAdjustedPage(ImageReference image) async {
    final id = state.prescription!.id;
    await _repository.storeAdjustedPage(id, image);
    await loadDraft(id);
  }

  Future<void> reparseCorrectedText(String correctedText) async {
    final prescription = state.prescription!;
    final parsed = await ref
        .read(prescriptionParserProvider)
        .parse(
          prescriptionId: prescription.id,
          rawText: correctedText,
          pageNumber: 1,
        );
    await _repository.replaceParsedItemsFromCorrectedText(
      prescription.id,
      correctedText,
      parsed.items,
    );
    await loadDraft(prescription.id);
  }

  Future<List<PrescriptionOcrResult>> _loadOcrFromPrescription(
    Prescription prescription,
  ) async {
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
    final id = state.prescription!.id;
    await _repository.deleteItem(id, itemId);
    await loadDraft(id);
  }

  Future<void> saveUnresolved() async {
    final id = state.prescription!.id;
    await _repository.saveUnresolved(id);
    await loadDraft(id);
  }

  Future<void> confirmPrescription() async {
    final id = state.prescription!.id;
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
