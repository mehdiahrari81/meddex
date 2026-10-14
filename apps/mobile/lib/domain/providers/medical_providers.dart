import '../models/source_provenance.dart';
import '../../features/prescription/domain/prescription_models.dart';
import '../../features/prescription/domain/prescription_providers.dart';

abstract interface class TerminologyProvider {
  Future<SourcedResult<Object>> lookup(String query, {required String locale});
}

abstract interface class DrugNormalizationProvider {
  Future<SourcedResult<Object>> normalize(String medicationText);
}

abstract interface class DrugInformationProvider {
  Future<SourcedResult<Object>> information(String normalizedDrugId);
}

abstract interface class CountryDrugRegistryProvider {
  Future<SourcedResult<Object>> lookup(
    String identifier, {
    required String country,
  });
}

abstract interface class OcrProvider {
  Future<PrescriptionOcrResult> recognize(ImageReference imageReference);
}

abstract interface class BarcodeProvider {
  BarcodeCapture fromUnverifiedDetection({
    required String format,
    required String rawValue,
    required DateTime scannedAt,
  });
}

abstract interface class AiExplanationProvider {
  Future<SourcedResult<String>> simplify(SourcedResult<String> groundedContent);
}

abstract interface class InteractionProvider {
  Future<SourcedResult<Object>> check(List<String> normalizedDrugIds);
}

abstract interface class TranslationProvider {
  Future<SourcedResult<String>> translate(
    SourcedResult<String> source, {
    required String targetLocale,
  });
}

class SourcedResult<T> {
  const SourcedResult({required this.value, required this.sources});
  final T value;
  final List<SourceProvenance> sources;
}

class UnverifiedProviderResult<T> {
  const UnverifiedProviderResult({required this.value, this.confidence});
  final T value;
  final double? confidence;
}
