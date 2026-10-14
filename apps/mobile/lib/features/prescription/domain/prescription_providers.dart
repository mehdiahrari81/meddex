import 'prescription_models.dart';

class ImageReference {
  const ImageReference({
    required this.privateId,
    required this.localPath,
    required this.pageNumber,
  });

  final String privateId;
  final String localPath;
  final int pageNumber;
}

class CapturedPrescriptionPage {
  const CapturedPrescriptionPage({
    required this.image,
    required this.sourceType,
  });

  final ImageReference image;
  final PrescriptionSourceType sourceType;
}

class PreprocessingMetadata {
  const PreprocessingMetadata({
    required this.operations,
    required this.originalWidth,
    required this.originalHeight,
    required this.outputWidth,
    required this.outputHeight,
    required this.createdAt,
  });

  final List<String> operations;
  final int originalWidth;
  final int originalHeight;
  final int outputWidth;
  final int outputHeight;
  final DateTime createdAt;
}

class PreprocessedImage {
  const PreprocessedImage({
    required this.original,
    required this.processed,
    required this.metadata,
  });

  final ImageReference original;
  final ImageReference processed;
  final PreprocessingMetadata metadata;
}

enum CaptureIssue { blur, dark, bright, lowResolution, cropped, perspective }

class CaptureQualityResult {
  const CaptureQualityResult({
    required this.issues,
    required this.confidenceByIssue,
  });

  final Set<CaptureIssue> issues;
  final Map<CaptureIssue, double> confidenceByIssue;
  bool get acceptable => issues.isEmpty;
}

enum PermissionKind { camera, photos }

enum AppPermissionStatus {
  notRequested,
  granted,
  denied,
  permanentlyDenied,
  restricted,
}

abstract interface class PrescriptionCaptureProvider {
  Future<List<CapturedPrescriptionPage>> scanDocument();
  Future<CapturedPrescriptionPage> persistCameraCapture(String sourcePath);
  Future<CapturedPrescriptionPage?> importFromGallery();
  Future<List<CapturedPrescriptionPage>> importFromFiles();
}

abstract interface class ImagePreprocessor {
  Future<PreprocessedImage> process(ImageReference original);
  Future<ImageReference> rotate(ImageReference original, int degrees);
}

abstract interface class CaptureQualityAnalyzer {
  Future<CaptureQualityResult> analyze(ImageReference image);
}

abstract interface class ImageAdjustmentProvider {
  Future<ImageReference?> crop(ImageReference original);
}

abstract interface class PrescriptionImageStore {
  Future<ImageReference> persistImported(
    String sourcePath, {
    required int pageNumber,
  });
  Future<ImageReference> persistBytes(
    List<int> bytes, {
    required int pageNumber,
    required String suffix,
  });
  Future<void> delete(ImageReference image);
  Future<void> deleteByPrivateId(String privateId);
  Future<ImageReference?> resolve(String privateId, {required int pageNumber});
  Future<void> cleanupTemporaryFiles();
}

abstract interface class PermissionService {
  Future<AppPermissionStatus> check(PermissionKind kind);
  Future<AppPermissionStatus> request(PermissionKind kind);
  Future<bool> openSettings();
}
