import '../domain/decoder.dart';
import '../domain/medical_term.dart';
import '../domain/search.dart';
import 'normalizer.dart';

class MedicalWordDecoder {
  const MedicalWordDecoder(this._repository);
  final TerminologyRepository _repository;

  Future<WordDecodeResult> decode(
    String input, {
    String language = 'en',
  }) async {
    final normalized = MedicalTermNormalizer.compact(input);
    if (normalized.isEmpty) {
      return WordDecodeResult(
        input: input,
        normalizedInput: normalized,
        components: const [],
        unknownFragments: const [],
        confidence: DecodeConfidence.none,
        exactTerm: null,
      );
    }
    final candidates = await _repository.searchCandidates(
      MedicalTermNormalizer.normalize(input),
      limit: 10,
      language: language,
    );
    MedicalTerm? exact;
    for (final candidate in candidates) {
      if (candidate.matchType == ResolutionType.exact &&
          MedicalTermNormalizer.compact(candidate.term.normalizedTerm) ==
              normalized) {
        exact = candidate.term;
        break;
      }
    }
    if (exact != null && exact.morphology.isNotEmpty) {
      final covered = List<bool>.filled(normalized.length, false);
      for (final component in exact.morphology) {
        for (
          var index = component.start.clamp(0, normalized.length);
          index < component.end.clamp(0, normalized.length);
          index++
        ) {
          covered[index] = true;
        }
      }
      final onlyConnectingVowelsUncovered = [
        for (var index = 0; index < covered.length; index++)
          if (!covered[index]) normalized[index],
      ].every((character) => character == 'o');
      return WordDecodeResult(
        input: input,
        normalizedInput: normalized,
        components: exact.morphology,
        unknownFragments: const [],
        confidence: onlyConnectingVowelsUncovered
            ? DecodeConfidence.complete
            : DecodeConfidence.partial,
        exactTerm: exact,
      );
    }

    final prefixes = await _repository.morphology(MorphologyType.prefix);
    final roots = await _repository.morphology(MorphologyType.root);
    final suffixes = await _repository.morphology(MorphologyType.suffix);
    final components = <TermMorphologyComponent>[];
    var cursor = 0;
    final prefix = _longestAt(prefixes, normalized, cursor);
    if (prefix != null) {
      final length = MedicalTermNormalizer.compact(prefix.value).length;
      components.add(_component(prefix, cursor, cursor + length));
      cursor += length;
    }
    final suffix = _longestSuffix(suffixes, normalized, cursor);
    final suffixStart = suffix == null
        ? normalized.length
        : normalized.length -
              MedicalTermNormalizer.compact(suffix.value).length;
    while (cursor < suffixStart) {
      final root = _longestAt(
        roots,
        normalized.substring(0, suffixStart),
        cursor,
      );
      if (root == null) break;
      final length = MedicalTermNormalizer.compact(root.value).length;
      components.add(_component(root, cursor, cursor + length));
      cursor += length;
      if (cursor < suffixStart && normalized[cursor] == 'o') {
        cursor += 1;
      }
    }
    if (suffix != null && cursor == suffixStart) {
      components.add(_component(suffix, suffixStart, normalized.length));
      cursor = normalized.length;
    }
    final unknown = cursor < normalized.length
        ? [
            UnknownFragment(
              normalized.substring(cursor),
              cursor,
              normalized.length,
            ),
          ]
        : <UnknownFragment>[];
    final confidence = components.isEmpty
        ? DecodeConfidence.none
        : unknown.isEmpty
        ? DecodeConfidence.complete
        : DecodeConfidence.partial;
    return WordDecodeResult(
      input: input,
      normalizedInput: normalized,
      components: components,
      unknownFragments: unknown,
      confidence: confidence,
      exactTerm: exact,
    );
  }

  MorphologyElement? _longestAt(
    List<MorphologyElement> elements,
    String input,
    int start,
  ) {
    MorphologyElement? best;
    for (final element in elements) {
      final value = MedicalTermNormalizer.compact(element.value);
      if (input.startsWith(value, start) &&
          (best == null ||
              value.length >
                  MedicalTermNormalizer.compact(best.value).length)) {
        best = element;
      }
    }
    return best;
  }

  MorphologyElement? _longestSuffix(
    List<MorphologyElement> elements,
    String input,
    int after,
  ) {
    MorphologyElement? best;
    for (final element in elements) {
      final value = MedicalTermNormalizer.compact(element.value);
      final start = input.length - value.length;
      if (start >= after &&
          input.endsWith(value) &&
          (best == null ||
              value.length >
                  MedicalTermNormalizer.compact(best.value).length)) {
        best = element;
      }
    }
    return best;
  }

  TermMorphologyComponent _component(
    MorphologyElement element,
    int start,
    int end,
  ) => TermMorphologyComponent(
    elementId: element.id,
    type: element.type,
    surfaceText: element.value,
    meaning: element.meaning,
    start: start,
    end: end,
  );
}
