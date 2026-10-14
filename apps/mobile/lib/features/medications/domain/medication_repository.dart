import 'medication_models.dart';

abstract interface class MedicationRepository {
  Stream<List<MedicationPlanDetails>> watchPlans({MedicationStatus? status});
  Future<MedicationPlanDetails?> getPlan(String planId);
  Future<MedicationPlanDetails> createPlan(CreateMedicationPlanRequest request);
  Future<void> replaceSchedule(
    String planId, {
    required MedicationScheduleType type,
    required List<int> reminderTimes,
    required Set<int> weekdays,
    int? intervalHours,
    DateTime? intervalAnchor,
    bool asNeeded,
  });
  Future<void> setPlanActive(String planId, bool active);
  Future<void> setMedicationStatus(
    String medicationId,
    MedicationStatus status,
  );
  Future<void> deletePlan(String planId, {required bool deleteLogs});
  Future<DoseEvent> recordDose({
    required String planId,
    required String logicalDoseId,
    required DateTime? scheduledAt,
    required DoseAction action,
    required DoseEventSource source,
    String? note,
  });
  Future<DoseEvent> correctDose({
    required String eventId,
    required DoseAction action,
    String? note,
  });
  Future<List<DoseEvent>> doseHistory({
    String? planId,
    DateTime? from,
    DateTime? to,
  });
  Future<void> addNote(String medicationId, String note);
  Future<void> saveRefill({
    required String planId,
    DateTime? reminderDate,
    double? startingQuantity,
    double? quantityPerTakenDose,
    double? alertAtRemaining,
  });
  Future<double?> estimatedRemaining(String planId);
  Future<List<MedicationActivity>> activityHistory({String? planId});
  Future<MedicationPrivacyPreferences> loadPrivacy();
  Future<void> savePrivacy(MedicationPrivacyPreferences preferences);
  Future<void> clearMedicationLogs();
  Future<void> recordExport({
    required String format,
    required List<String> includedFields,
    required bool shared,
  });
}
