import 'prescription_models.dart';

class InvalidPrescriptionTransition implements Exception {
  const InvalidPrescriptionTransition(this.from, this.to);

  final PrescriptionItemState from;
  final PrescriptionItemState to;

  @override
  String toString() =>
      'Transition from ${from.name} to ${to.name} is not allowed.';
}

class PrescriptionVerificationStateMachine {
  const PrescriptionVerificationStateMachine();

  static const _allowed = <PrescriptionItemState, Set<PrescriptionItemState>>{
    PrescriptionItemState.detected: {
      PrescriptionItemState.needsReview,
      PrescriptionItemState.rejected,
      PrescriptionItemState.unresolved,
    },
    PrescriptionItemState.needsReview: {
      PrescriptionItemState.edited,
      PrescriptionItemState.confirmedByUser,
      PrescriptionItemState.unresolved,
      PrescriptionItemState.rejected,
    },
    PrescriptionItemState.edited: {
      PrescriptionItemState.edited,
      PrescriptionItemState.confirmedByUser,
      PrescriptionItemState.unresolved,
      PrescriptionItemState.rejected,
    },
    PrescriptionItemState.confirmedByUser: {
      PrescriptionItemState.edited,
      PrescriptionItemState.readyForLookup,
      PrescriptionItemState.unresolved,
    },
    PrescriptionItemState.unresolved: {
      PrescriptionItemState.edited,
      PrescriptionItemState.confirmedByUser,
      PrescriptionItemState.rejected,
    },
    PrescriptionItemState.rejected: {},
    PrescriptionItemState.readyForLookup: {
      PrescriptionItemState.edited,
      PrescriptionItemState.unresolved,
    },
  };

  bool canTransition(PrescriptionItemState from, PrescriptionItemState to) =>
      _allowed[from]!.contains(to);

  PrescriptionItem transition(
    PrescriptionItem item,
    PrescriptionItemState to, {
    required DateTime now,
  }) {
    if (!canTransition(item.state, to)) {
      throw InvalidPrescriptionTransition(item.state, to);
    }
    if ((to == PrescriptionItemState.confirmedByUser ||
            to == PrescriptionItemState.readyForLookup) &&
        !_identityConfirmed(item)) {
      throw StateError('Medication identity must be entered and confirmed.');
    }
    if (to == PrescriptionItemState.readyForLookup &&
        item.state != PrescriptionItemState.confirmedByUser) {
      throw InvalidPrescriptionTransition(item.state, to);
    }
    return item.copyWith(state: to, updatedAt: now.toUtc());
  }

  bool _identityConfirmed(PrescriptionItem item) {
    final name = item.field(PrescriptionFieldType.medicationName);
    return name.hasValue && name.userConfirmed && !name.ambiguous;
  }
}

class PrescriptionPipelineStateMachine {
  const PrescriptionPipelineStateMachine();

  static const _next = <PrescriptionPipelineState, PrescriptionPipelineState>{
    PrescriptionPipelineState.rawCapture:
        PrescriptionPipelineState.preprocessedImage,
    PrescriptionPipelineState.preprocessedImage:
        PrescriptionPipelineState.ocrResult,
    PrescriptionPipelineState.ocrResult:
        PrescriptionPipelineState.parsedCandidates,
    PrescriptionPipelineState.parsedCandidates:
        PrescriptionPipelineState.userReviewRequired,
    PrescriptionPipelineState.userReviewRequired:
        PrescriptionPipelineState.userConfirmed,
    PrescriptionPipelineState.userConfirmed:
        PrescriptionPipelineState.readyForMedicationLookup,
  };

  bool canTransition(
    PrescriptionPipelineState from,
    PrescriptionPipelineState to,
  ) => _next[from] == to;

  void requireTransition(
    PrescriptionPipelineState from,
    PrescriptionPipelineState to,
  ) {
    if (!canTransition(from, to)) {
      throw StateError(
        'Prescription pipeline cannot move from ${from.name} to ${to.name}.',
      );
    }
  }
}
