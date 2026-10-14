import 'medical_term.dart';

enum ResolutionType {
  exact,
  synonym,
  layEquivalent,
  abbreviation,
  partial,
  fuzzy,
  ambiguous,
  noMatch,
}

enum ResultOrigin { local, cached, remote }

class TermSearchCandidate {
  const TermSearchCandidate({
    required this.term,
    required this.matchType,
    required this.matchedText,
    required this.repositoryScore,
  });
  final MedicalTerm term;
  final ResolutionType matchType;
  final String matchedText;
  final double repositoryScore;
}

class TermSearchResult {
  const TermSearchResult({
    required this.term,
    required this.matchType,
    required this.matchedText,
    required this.relevance,
    required this.origin,
    this.isSuggestion = false,
  });
  final MedicalTerm term;
  final ResolutionType matchType;
  final String matchedText;
  final double relevance;
  final ResultOrigin origin;
  final bool isSuggestion;
}

class TermResolution {
  const TermResolution({
    required this.originalQuery,
    required this.normalizedQuery,
    required this.type,
    required this.results,
    required this.ambiguous,
    this.suggestedQuery,
  });
  final String originalQuery;
  final String normalizedQuery;
  final ResolutionType type;
  final List<TermSearchResult> results;
  final bool ambiguous;
  final String? suggestedQuery;
}

abstract interface class TerminologyRepository {
  Future<List<TermSearchCandidate>> searchCandidates(
    String normalizedQuery, {
    required int limit,
    String? categoryId,
    String language = 'en',
  });
  Future<MedicalTerm?> termById(String id, {String language = 'en'});
  Future<List<MedicalTerm>> termsByIds(
    List<String> ids, {
    String language = 'en',
  });
  Future<List<MedicalCategory>> categories();
  Future<List<MedicalTerm>> browseTerms({
    String? categoryId,
    String language = 'en',
    int offset = 0,
    int limit = 50,
  });
  Future<List<MorphologyElement>> morphology(
    MorphologyType type, {
    String? category,
    String language = 'en',
  });
  Future<List<AbbreviationMeaning>> abbreviations(String normalizedQuery);
  Future<List<AbbreviationMeaning>> browseAbbreviations({
    String query = '',
    int limit = 100,
  });
}
