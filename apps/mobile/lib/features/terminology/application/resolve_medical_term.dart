import '../domain/search.dart';
import 'edit_distance.dart';
import 'normalizer.dart';

class ResolveMedicalTerm {
  const ResolveMedicalTerm(this._repository);
  final TerminologyRepository _repository;

  Future<TermResolution> call(
    String input, {
    int limit = 20,
    String? categoryId,
    String language = 'en',
  }) async {
    final normalized = MedicalTermNormalizer.normalize(input);
    if (normalized.isEmpty) {
      return TermResolution(
        originalQuery: input,
        normalizedQuery: normalized,
        type: ResolutionType.noMatch,
        results: const [],
        ambiguous: false,
      );
    }
    final abbreviations = await _repository.abbreviations(normalized);
    final candidates = await _repository.searchCandidates(
      normalized,
      limit: limit * 10,
      categoryId: categoryId,
      language: language,
    );
    final ranked =
        candidates
            .map((candidate) => _rank(candidate, normalized))
            .where(
              (result) => result.relevance >= _minimumScore(result.matchType),
            )
            .toList()
          ..sort((left, right) {
            final scoreOrder = right.relevance.compareTo(left.relevance);
            if (scoreOrder != 0) return scoreOrder;
            return left.term.canonicalTerm.compareTo(right.term.canonicalTerm);
          });
    final unique = <String, TermSearchResult>{};
    for (final result in ranked) {
      unique.putIfAbsent(result.term.id, () => result);
    }
    final results = unique.values.take(limit).toList(growable: false);
    final abbreviationAmbiguous =
        abbreviations.length > 1 ||
        abbreviations.any((meaning) => meaning.ambiguous);
    if (abbreviationAmbiguous && results.isNotEmpty) {
      return TermResolution(
        originalQuery: input,
        normalizedQuery: normalized,
        type: ResolutionType.ambiguous,
        results: results
            .where((result) => result.matchType == ResolutionType.abbreviation)
            .toList(growable: false),
        ambiguous: true,
      );
    }
    if (results.isEmpty) {
      return TermResolution(
        originalQuery: input,
        normalizedQuery: normalized,
        type: ResolutionType.noMatch,
        results: const [],
        ambiguous: false,
      );
    }
    final first = results.first;
    return TermResolution(
      originalQuery: input,
      normalizedQuery: normalized,
      type: first.matchType,
      results: results,
      ambiguous: false,
      suggestedQuery: first.isSuggestion ? first.term.canonicalTerm : null,
    );
  }

  TermSearchResult _rank(TermSearchCandidate candidate, String query) {
    final canonical = MedicalTermNormalizer.normalize(
      candidate.term.canonicalTerm,
    );
    final matched = MedicalTermNormalizer.normalize(candidate.matchedText);
    final base = switch (candidate.matchType) {
      ResolutionType.exact => 1000,
      ResolutionType.synonym => 900,
      ResolutionType.layEquivalent => 850,
      ResolutionType.abbreviation => 800,
      ResolutionType.partial => canonical.startsWith(query) ? 700 : 620,
      ResolutionType.fuzzy => 500,
      ResolutionType.ambiguous => 800,
      ResolutionType.noMatch => 0,
    };
    final exactBonus = matched == query ? 40 : 0;
    final prefixBonus = matched.startsWith(query) ? 20 : 0;
    final similarity = EditDistance.similarity(query, matched);
    final fuzzyAdjustment = candidate.matchType == ResolutionType.fuzzy
        ? similarity * 100
        : 0;
    return TermSearchResult(
      term: candidate.term,
      matchType: candidate.matchType,
      matchedText: candidate.matchedText,
      relevance:
          base +
          exactBonus +
          prefixBonus +
          fuzzyAdjustment +
          candidate.repositoryScore,
      origin: ResultOrigin.local,
      isSuggestion: candidate.matchType == ResolutionType.fuzzy,
    );
  }

  double _minimumScore(ResolutionType type) => switch (type) {
    ResolutionType.fuzzy => 555,
    ResolutionType.noMatch => double.infinity,
    _ => 1,
  };
}

typedef MedicalTermResolver = ResolveMedicalTerm;
