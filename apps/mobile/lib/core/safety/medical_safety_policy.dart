enum MedicalAction {
  explainTerminology,
  simplifySourcedInformation,
  explainConfirmedPrescriptionText,
  presentEducationalMaterial,
  organizeUserConfirmedInstructions,
  diagnose,
  recommendDiagnosis,
  prescribe,
  changeDosage,
  adviseStoppingMedication,
  inferUnreadableText,
  generateInteractionClaim,
  inferPrescriberIntent,
}

class SafetyDecision {
  const SafetyDecision.allowed() : allowed = true, reasonCode = null;
  const SafetyDecision.denied(this.reasonCode) : allowed = false;

  final bool allowed;
  final String? reasonCode;
}

abstract interface class MedicalSafetyPolicy {
  SafetyDecision evaluate(MedicalAction action);
  int get currentConsentVersion;
}

class DefaultMedicalSafetyPolicy implements MedicalSafetyPolicy {
  const DefaultMedicalSafetyPolicy();

  @override
  int get currentConsentVersion => 1;

  @override
  SafetyDecision evaluate(MedicalAction action) => switch (action) {
    MedicalAction.explainTerminology ||
    MedicalAction.simplifySourcedInformation ||
    MedicalAction.explainConfirmedPrescriptionText ||
    MedicalAction.presentEducationalMaterial ||
    MedicalAction.organizeUserConfirmedInstructions =>
      const SafetyDecision.allowed(),
    _ => SafetyDecision.denied('medical_action_not_permitted'),
  };
}
