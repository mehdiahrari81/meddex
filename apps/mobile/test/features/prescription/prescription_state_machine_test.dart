import 'package:flutter_test/flutter_test.dart';
import 'package:mediexplain/domain/models/confidence_result.dart';
import 'package:mediexplain/features/prescription/domain/prescription_models.dart';
import 'package:mediexplain/features/prescription/domain/prescription_state_machine.dart';

void main() {
  const machine = PrescriptionVerificationStateMachine();
  final now = DateTime.utc(2026, 8, 13);

  test('allowed transition map is centralized and exhaustive', () {
    final allowed = <(PrescriptionItemState, PrescriptionItemState)>[
      (PrescriptionItemState.detected, PrescriptionItemState.needsReview),
      (PrescriptionItemState.detected, PrescriptionItemState.rejected),
      (PrescriptionItemState.needsReview, PrescriptionItemState.edited),
      (PrescriptionItemState.needsReview, PrescriptionItemState.unresolved),
      (PrescriptionItemState.edited, PrescriptionItemState.confirmedByUser),
      (
        PrescriptionItemState.confirmedByUser,
        PrescriptionItemState.readyForLookup,
      ),
      (PrescriptionItemState.readyForLookup, PrescriptionItemState.edited),
      (PrescriptionItemState.unresolved, PrescriptionItemState.edited),
    ];
    for (final transition in allowed) {
      expect(
        machine.canTransition(transition.$1, transition.$2),
        isTrue,
        reason: '${transition.$1.name} -> ${transition.$2.name}',
      );
    }
    expect(
      machine.canTransition(
        PrescriptionItemState.detected,
        PrescriptionItemState.readyForLookup,
      ),
      isFalse,
    );
    expect(
      machine.canTransition(
        PrescriptionItemState.rejected,
        PrescriptionItemState.edited,
      ),
      isFalse,
    );
  });

  test('OCR item can never jump to confirmed or lookup', () {
    final item = _item(PrescriptionItemState.detected, confirmedName: false);
    expect(
      () => machine.transition(
        item,
        PrescriptionItemState.confirmedByUser,
        now: now,
      ),
      throwsA(isA<InvalidPrescriptionTransition>()),
    );
    expect(
      () => machine.transition(
        item,
        PrescriptionItemState.readyForLookup,
        now: now,
      ),
      throwsA(isA<InvalidPrescriptionTransition>()),
    );
  });

  test('explicit unambiguous user-confirmed identity is mandatory', () {
    final unconfirmed = _item(
      PrescriptionItemState.edited,
      confirmedName: false,
    );
    expect(
      () => machine.transition(
        unconfirmed,
        PrescriptionItemState.confirmedByUser,
        now: now,
      ),
      throwsStateError,
    );
    final confirmed = _item(PrescriptionItemState.edited, confirmedName: true);
    final userConfirmed = machine.transition(
      confirmed,
      PrescriptionItemState.confirmedByUser,
      now: now,
    );
    expect(userConfirmed.state, PrescriptionItemState.confirmedByUser);
    final ready = machine.transition(
      userConfirmed,
      PrescriptionItemState.readyForLookup,
      now: now,
    );
    expect(ready.state, PrescriptionItemState.readyForLookup);
  });

  test('pipeline sequence forbids skipped stages', () {
    const pipeline = PrescriptionPipelineStateMachine();
    expect(
      pipeline.canTransition(
        PrescriptionPipelineState.rawCapture,
        PrescriptionPipelineState.preprocessedImage,
      ),
      isTrue,
    );
    expect(
      () => pipeline.requireTransition(
        PrescriptionPipelineState.rawCapture,
        PrescriptionPipelineState.userConfirmed,
      ),
      throwsStateError,
    );
  });
}

PrescriptionItem _item(
  PrescriptionItemState state, {
  required bool confirmedName,
}) {
  final now = DateTime.utc(2026, 8, 13);
  return PrescriptionItem(
    id: 'item',
    prescriptionId: 'prescription',
    rawMedicationText: 'Amoxicillin',
    sourceText: 'Amoxicillin 500 mg',
    pageNumber: 1,
    lineNumber: 0,
    fields: {
      PrescriptionFieldType.medicationName: ParsedField(
        type: PrescriptionFieldType.medicationName,
        originalValue: 'Amoxicillin',
        currentValue: 'Amoxicillin',
        source: FieldValueSource.user,
        confidence: ConfidenceBand.unknown,
        ambiguous: false,
        userConfirmed: confirmedName,
      ),
    },
    state: state,
    createdAt: now,
    updatedAt: now,
  );
}
