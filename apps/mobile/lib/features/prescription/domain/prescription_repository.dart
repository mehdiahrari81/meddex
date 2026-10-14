import 'prescription_models.dart';
import 'prescription_providers.dart';

class PrescriptionHistoryEntry {
  const PrescriptionHistoryEntry({
    required this.id,
    required this.captureDate,
    required this.itemCount,
    required this.pipelineState,
    required this.unresolvedCount,
    required this.medicationNames,
    required this.imageAvailable,
    required this.updatedAt,
  });

  final String id;
  final DateTime captureDate;
  final int itemCount;
  final PrescriptionPipelineState pipelineState;
  final int unresolvedCount;
  final List<String> medicationNames;
  final bool imageAvailable;
  final DateTime updatedAt;
}

class PrescriptionDraft {
  const PrescriptionDraft({required this.prescription, required this.pages});
  final Prescription prescription;
  final List<ImageReference> pages;
}

abstract interface class PrescriptionRepository {
  Future<PrescriptionDraft> createDraft({
    required PrescriptionSourceType sourceType,
    required List<ImageReference> pages,
    String? userId,
  });
  Future<PrescriptionDraft> createManualDraft({String? userId});
  Future<Prescription?> get(String id);
  Future<List<ImageReference>> pages(String prescriptionId);
  Stream<List<PrescriptionHistoryEntry>> watchHistory();
  Future<Prescription?> latestDraft();
  Future<void> storePreprocessed(
    String prescriptionId,
    List<PreprocessedImage> pages,
    List<CaptureQualityResult> quality,
  );
  Future<void> storeAdjustedPage(String prescriptionId, ImageReference image);
  Future<void> storeOcr(
    String prescriptionId,
    List<PrescriptionOcrResult> results,
  );
  Future<void> storeParsedItems(
    String prescriptionId,
    List<PrescriptionItem> items,
  );
  Future<void> replaceParsedItemsFromCorrectedText(
    String prescriptionId,
    String correctedText,
    List<PrescriptionItem> items,
  );
  Future<void> addManualItem(String prescriptionId, PrescriptionItem item);
  Future<void> editField(
    String prescriptionId,
    String itemId,
    ParsedField field,
  );
  Future<void> confirmField(
    String prescriptionId,
    String itemId,
    PrescriptionFieldType type,
  );
  Future<void> setItemState(
    String prescriptionId,
    String itemId,
    PrescriptionItemState state,
  );
  Future<void> deleteItem(String prescriptionId, String itemId);
  Future<void> saveUnresolved(String prescriptionId);
  Future<void> confirmPrescription(String prescriptionId);
  Future<void> deleteImages(String prescriptionId);
  Future<void> deletePrescription(String prescriptionId);
  Future<void> saveBarcode(BarcodeCapture capture);
  Future<List<BarcodeCapture>> recentBarcodes();
}
