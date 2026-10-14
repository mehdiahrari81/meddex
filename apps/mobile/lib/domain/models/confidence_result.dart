enum ConfidenceBand { unknown, low, medium, high }

enum VerificationState {
  unresolved,
  verificationRequired,
  userConfirmed,
  sourceVerified,
  conflicting,
}

class ConfidenceResult {
  const ConfidenceResult({
    required this.band,
    required this.verificationState,
    this.score,
  });

  final double? score;
  final ConfidenceBand band;
  final VerificationState verificationState;

  bool get requiresUserAction =>
      verificationState == VerificationState.verificationRequired ||
      verificationState == VerificationState.unresolved ||
      verificationState == VerificationState.conflicting;
}
