abstract interface class FhirMedicationAdapter<TDomain> {
  Map<String, Object?> toFhirMedication(TDomain model);
  Map<String, Object?> toFhirMedicationRequest(TDomain model);
}
