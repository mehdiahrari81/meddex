import 'medical_term.dart';

enum DecodeConfidence { none, partial, complete }

class UnknownFragment {
  const UnknownFragment(this.text, this.start, this.end);
  final String text;
  final int start;
  final int end;
}

class WordDecodeResult {
  const WordDecodeResult({
    required this.input,
    required this.normalizedInput,
    required this.components,
    required this.unknownFragments,
    required this.confidence,
    required this.exactTerm,
  });
  final String input;
  final String normalizedInput;
  final List<TermMorphologyComponent> components;
  final List<UnknownFragment> unknownFragments;
  final DecodeConfidence confidence;
  final MedicalTerm? exactTerm;

  bool get hasDefensibleBreakdown => components.isNotEmpty;
}
