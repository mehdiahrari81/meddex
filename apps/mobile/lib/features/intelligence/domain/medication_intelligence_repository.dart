import 'intelligence_models.dart';

abstract interface class MedicationIntelligenceRepository {
  Future<MedicationResolution> search({
    required String query,
    String? strength,
    String? dosageForm,
    String? country,
    String inputOrigin = 'search',
    String? prescriptionItemId,
  });

  Future<MedicationIdentity> confirm(String resolutionId, String candidateId);
  Future<MedicationIdentity> detail(String medicationId);
  Future<MedicationCandidate?> resolveBarcode(String value);
  Future<List<MedicationIdentity>> saved();
  Future<List<MedicationIdentity>> recent();
  Future<void> setSaved(String medicationId, {required bool saved});
  Future<GroundedAnswer> ask({
    required String question,
    required String medicationId,
    required String mode,
    required String language,
  });
  void cancelActiveAnswer();
  Future<void> report({
    required String type,
    required String targetType,
    required String targetId,
    required String reason,
    String? note,
  });
}
