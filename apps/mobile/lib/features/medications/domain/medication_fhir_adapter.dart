import '../../../domain/providers/fhir_adapter.dart';
import 'medication_models.dart';

class MedicationPlanFhirAdapter
    implements FhirMedicationAdapter<MedicationPlanDetails> {
  const MedicationPlanFhirAdapter();

  @override
  Map<String, Object?> toFhirMedication(MedicationPlanDetails model) => {
    'resourceType': 'Medication',
    'id': model.medication.id,
    'code': {'text': model.medication.displayName},
    if (model.medication.dosageForm != null)
      'form': {'text': model.medication.dosageForm},
  };

  @override
  Map<String, Object?> toFhirMedicationRequest(MedicationPlanDetails model) {
    if (model.source.sourceType != MedicationSourceType.confirmedPrescription) {
      throw UnsupportedError(
        'A user-created reminder is not a clinician-issued MedicationRequest.',
      );
    }
    // This is explicitly a draft mapping. It lacks clinician identity and must
    // never be presented as an official order.
    return {
      'resourceType': 'MedicationStatement',
      'status': model.plan.active ? 'recorded' : 'not-taken',
      'medication': {'reference': 'Medication/${model.medication.id}'},
      'note': [
        {'text': 'User-confirmed prescription-derived information.'},
      ],
      'dosage': [
        {
          'text': model.source.confirmedInstruction,
          'patientInstruction': model.plan.instructions,
        },
      ],
    };
  }
}
