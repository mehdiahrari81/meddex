import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart' as db;
import '../../../domain/models/source_provenance.dart';
import '../application/edit_distance.dart';
import '../application/normalizer.dart';
import '../domain/medical_term.dart' as domain;
import '../domain/search.dart';

class LocalTerminologyRepository implements TerminologyRepository {
  const LocalTerminologyRepository(
    this._database, {
    this.includeReviewedContent = true,
  });
  final db.AppDatabase _database;
  final bool includeReviewedContent;

  List<String> get _publishedStatuses => includeReviewedContent
      ? const ['reviewed', 'approved']
      : const ['approved'];

  String get _publishedStatusesSql =>
      includeReviewedContent ? "('reviewed', 'approved')" : "('approved')";

  @override
  Future<List<TermSearchCandidate>> searchCandidates(
    String normalizedQuery, {
    required int limit,
    String? categoryId,
    String language = 'en',
  }) async {
    final query = MedicalTermNormalizer.normalize(normalizedQuery);
    if (query.isEmpty) return const [];
    final variables = <Variable<Object>>[
      Variable(query),
      Variable(query),
      Variable('$query%'),
      Variable('$query%'),
      Variable(query.length),
      Variable(query),
      Variable('$query%'),
      Variable('%$query%'),
      Variable(query),
      Variable('$query%'),
      Variable('%$query%'),
      Variable(query.substring(0, 1)),
      Variable(language),
    ];
    final categoryFilter = categoryId == null ? '' : 'AND t.category_id = ?';
    if (categoryId != null) variables.add(Variable(categoryId));
    variables.add(Variable(limit.clamp(1, 200)));
    final rows = await _database
        .customSelect(
          '''
      SELECT t.id,
        MIN(CASE
          WHEN t.normalized_term = ? THEN 0
          WHEN a.normalized_alias = ? THEN 1
          WHEN t.normalized_term LIKE ? THEN 2
          WHEN a.normalized_alias LIKE ? THEN 3
          ELSE 4
        END) AS match_priority
        , ABS(length(t.normalized_term) - ?) AS length_distance
      FROM medical_terms t
      LEFT JOIN term_aliases a ON a.term_id = t.id
      WHERE t.deprecated = 0
        AND t.review_status IN $_publishedStatusesSql
        AND (
          t.normalized_term = ? OR t.normalized_term LIKE ? OR t.normalized_term LIKE ?
          OR a.normalized_alias = ? OR a.normalized_alias LIKE ? OR a.normalized_alias LIKE ?
          OR substr(t.normalized_term, 1, 1) = ?
        )
        AND t.language = ?
        $categoryFilter
      GROUP BY t.id
      ORDER BY match_priority, length_distance, t.normalized_term
      LIMIT ?
      ''',
          variables: variables,
          readsFrom: {_database.medicalTerms, _database.termAliases},
        )
        .get();
    final results = <TermSearchCandidate>[];
    for (final row in rows) {
      final id = row.read<String>('id');
      final term = await termById(id, language: language);
      if (term == null) continue;
      final match = _bestMatch(term, query);
      if (match != null) results.add(match);
    }
    return results;
  }

  TermSearchCandidate? _bestMatch(domain.MedicalTerm term, String query) {
    final values = <(String, ResolutionType)>[
      (term.normalizedTerm, ResolutionType.exact),
      ...term.synonyms.map((value) => (value, ResolutionType.synonym)),
      ...term.layTerms.map((value) => (value, ResolutionType.layEquivalent)),
      ...term.abbreviations.map(
        (value) => (value, ResolutionType.abbreviation),
      ),
      ...term.alternativeSpellings.map(
        (value) => (value, ResolutionType.partial),
      ),
    ];
    TermSearchCandidate? best;
    var bestPriority = -1;
    for (final value in values) {
      final normalized = MedicalTermNormalizer.normalize(value.$1);
      ResolutionType? matchType;
      var score = 0.0;
      if (normalized == query) {
        matchType = value.$2;
        score = 10;
      } else if (normalized.startsWith(query) ||
          normalized.contains(' $query')) {
        matchType = ResolutionType.partial;
        score = 5;
      } else {
        final similarity = EditDistance.similarity(query, normalized);
        final maximumDistance = query.length <= 5 ? 1 : 2;
        if (EditDistance.levenshtein(query, normalized) <= maximumDistance &&
            similarity >= 0.72) {
          matchType = ResolutionType.fuzzy;
          score = similarity * 10;
        }
      }
      if (matchType == null) continue;
      final priority = _priority(matchType);
      if (priority > bestPriority ||
          (priority == bestPriority && score > (best?.repositoryScore ?? -1))) {
        bestPriority = priority;
        best = TermSearchCandidate(
          term: term,
          matchType: matchType,
          matchedText: value.$1,
          repositoryScore: score,
        );
      }
    }
    return best;
  }

  int _priority(ResolutionType type) => switch (type) {
    ResolutionType.exact => 8,
    ResolutionType.synonym => 7,
    ResolutionType.layEquivalent => 6,
    ResolutionType.abbreviation => 5,
    ResolutionType.partial => 4,
    ResolutionType.fuzzy => 3,
    ResolutionType.ambiguous => 2,
    ResolutionType.noMatch => 0,
  };

  @override
  Future<domain.MedicalTerm?> termById(
    String id, {
    String language = 'en',
  }) async {
    final term =
        await (_database.select(_database.medicalTerms)..where(
              (row) =>
                  row.id.equals(id) &
                  row.deprecated.equals(false) &
                  row.reviewStatus.isIn(_publishedStatuses),
            ))
            .getSingleOrNull();
    if (term == null) return null;
    final definitions =
        await (_database.select(_database.termDefinitions)..where(
              (row) =>
                  row.termId.equals(id) &
                  row.reviewStatus.isIn(_publishedStatuses),
            ))
            .get();
    final aliases = await (_database.select(
      _database.termAliases,
    )..where((row) => row.termId.equals(id))).get();
    final examples =
        await (_database.select(_database.termExamples)
              ..where((row) => row.termId.equals(id))
              ..orderBy([(row) => OrderingTerm.asc(row.position)]))
            .get();
    final morphology =
        await (_database.select(_database.termMorphologies)
              ..where((row) => row.termId.equals(id))
              ..orderBy([(row) => OrderingTerm.asc(row.position)]))
            .get();
    final relations = await (_database.select(
      _database.termRelations,
    )..where((row) => row.sourceTermId.equals(id))).get();
    final sources = await (_database.select(
      _database.contentSources,
    )..where((row) => row.contentId.equals(id))).get();
    List<String> aliasesOf(String type) => aliases
        .where((alias) => alias.aliasType == type)
        .map((alias) => alias.alias)
        .toList(growable: false);
    return domain.MedicalTerm(
      id: term.id,
      canonicalTerm: term.canonicalTerm,
      normalizedTerm: term.normalizedTerm,
      definitions: definitions
          .map(
            (definition) => domain.TermDefinition(
              language: definition.language,
              simple: definition.simpleDefinition,
              standard: definition.standardDefinition,
              technical: definition.technicalDefinition,
              sourceLanguage: definition.sourceLanguage,
              translationMethod: definition.translationMethod,
              reviewedBy: definition.reviewedBy,
              reviewedAt: definition.reviewedAt,
              reviewStatus: _reviewStatus(definition.reviewStatus),
              version: definition.recordVersion,
            ),
          )
          .toList(growable: false),
      pronunciationText: term.pronunciationText,
      phoneticRepresentation: term.phoneticRepresentation,
      categoryId: term.categoryId,
      subcategory: term.subcategory,
      synonyms: aliasesOf('synonym'),
      alternativeSpellings: aliasesOf('alternative'),
      layTerms: aliasesOf('lay'),
      abbreviations: aliasesOf('abbreviation'),
      relatedTermIds: relations
          .map((relation) => relation.targetTermId)
          .toList(),
      morphology: morphology
          .map(
            (component) => domain.TermMorphologyComponent(
              elementId: component.elementId,
              type: _morphologyType(component.elementType),
              surfaceText: component.surfaceText,
              meaning: component.meaning,
              start: component.startOffset,
              end: component.endOffset,
            ),
          )
          .toList(growable: false),
      examples: examples
          .map((example) => example.example)
          .toList(growable: false),
      sources: sources.map(_source).toList(growable: false),
      language: term.language,
      reviewStatus: _reviewStatus(term.reviewStatus),
      version: term.recordVersion,
      createdAt: term.createdAt,
      updatedAt: term.updatedAt,
      deprecated: term.deprecated,
      replacementTermId: term.replacementTermId,
    );
  }

  @override
  Future<List<domain.MedicalTerm>> termsByIds(
    List<String> ids, {
    String language = 'en',
  }) async {
    final result = <domain.MedicalTerm>[];
    for (final id in ids) {
      final term = await termById(id, language: language);
      if (term != null) result.add(term);
    }
    return result;
  }

  @override
  Future<List<domain.MedicalCategory>> categories() async {
    final rows = await (_database.select(
      _database.medicalCategories,
    )..orderBy([(row) => OrderingTerm.asc(row.position)])).get();
    return rows
        .map(
          (row) => domain.MedicalCategory(
            id: row.id,
            name: row.name,
            description: row.description,
            parentId: row.parentId,
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<List<domain.MedicalTerm>> browseTerms({
    String? categoryId,
    String language = 'en',
    int offset = 0,
    int limit = 50,
  }) async {
    final query = _database.select(_database.medicalTerms)
      ..where(
        (row) =>
            row.deprecated.equals(false) &
            row.language.equals(language) &
            row.reviewStatus.isIn(_publishedStatuses),
      )
      ..orderBy([(row) => OrderingTerm.asc(row.canonicalTerm)])
      ..limit(limit.clamp(1, 100), offset: offset < 0 ? 0 : offset);
    if (categoryId != null) {
      query.where((row) => row.categoryId.equals(categoryId));
    }
    final rows = await query.get();
    return termsByIds(rows.map((row) => row.id).toList(), language: language);
  }

  @override
  Future<List<domain.MorphologyElement>> morphology(
    domain.MorphologyType type, {
    String? category,
    String language = 'en',
  }) async {
    final query = _database.select(_database.morphologyElements)
      ..where(
        (row) =>
            row.elementType.equals(type.name) &
            row.language.equals(language) &
            row.reviewStatus.isIn(_publishedStatuses),
      );
    if (category != null) query.where((row) => row.category.equals(category));
    final rows = await query.get();
    final result = <domain.MorphologyElement>[];
    for (final row in rows) {
      final sourceRow = await (_database.select(
        _database.contentSources,
      )..where((source) => source.id.equals(row.sourceId))).getSingle();
      result.add(
        domain.MorphologyElement(
          id: row.id,
          type: _morphologyType(row.elementType),
          value: row.value,
          normalizedValue: row.normalizedValue,
          meaning: row.meaning,
          explanation: row.explanation,
          examples: (jsonDecode(row.examplesJson) as List).cast<String>(),
          origin: row.origin,
          category: row.category,
          source: _source(sourceRow),
          language: row.language,
          pronunciation: row.pronunciation,
          relatedElementIds: (jsonDecode(row.relatedElementIdsJson) as List)
              .cast<String>(),
          reviewStatus: _reviewStatus(row.reviewStatus),
        ),
      );
    }
    result.sort((a, b) => a.value.compareTo(b.value));
    return result;
  }

  @override
  Future<List<domain.AbbreviationMeaning>> abbreviations(
    String normalizedQuery,
  ) async {
    final rows =
        await (_database.select(_database.medicalAbbreviations)..where(
              (row) => row.normalizedAbbreviation.equals(
                MedicalTermNormalizer.normalize(normalizedQuery),
              ),
            ))
            .get();
    final results = <domain.AbbreviationMeaning>[];
    for (final row in rows) {
      if (await termById(row.termId) == null) continue;
      results.add(
        domain.AbbreviationMeaning(
          id: row.id,
          termId: row.termId,
          abbreviation: row.abbreviation,
          expansion: row.expansion,
          context: row.context,
          category: row.category,
          ambiguous: row.ambiguous,
          alternativeMeanings: (jsonDecode(row.alternativeMeaningsJson) as List)
              .cast<String>(),
          safetyWarning: row.safetyWarning,
        ),
      );
    }
    return results;
  }

  @override
  Future<List<domain.AbbreviationMeaning>> browseAbbreviations({
    String query = '',
    int limit = 100,
  }) async {
    final normalized = MedicalTermNormalizer.normalize(query);
    final statement = _database.select(_database.medicalAbbreviations)
      ..orderBy([(row) => OrderingTerm.asc(row.abbreviation)])
      ..limit(limit.clamp(1, 200));
    if (normalized.isNotEmpty) {
      statement.where(
        (row) =>
            row.normalizedAbbreviation.like('%$normalized%') |
            row.expansion.lower().like('%$normalized%'),
      );
    }
    final rows = await statement.get();
    final results = <domain.AbbreviationMeaning>[];
    for (final row in rows) {
      if (await termById(row.termId) == null) continue;
      results.add(
        domain.AbbreviationMeaning(
          id: row.id,
          termId: row.termId,
          abbreviation: row.abbreviation,
          expansion: row.expansion,
          context: row.context,
          category: row.category,
          ambiguous: row.ambiguous,
          alternativeMeanings: (jsonDecode(row.alternativeMeaningsJson) as List)
              .cast<String>(),
          safetyWarning: row.safetyWarning,
        ),
      );
    }
    return results;
  }

  SourceProvenance _source(db.ContentSource source) => SourceProvenance(
    provider: source.provider,
    sourceTitle: source.sourceTitle,
    sourceIdentifier: source.sourceIdentifier,
    canonicalReference: source.canonicalReference == null
        ? null
        : Uri.tryParse(source.canonicalReference!),
    retrievedAt: source.retrievedAt,
    sourceUpdatedAt: source.sourceUpdatedAt,
    locale: source.locale,
    version: source.sourceVersion,
    reviewStatus: _provenanceReviewStatus(source.reviewStatus),
    contentType: source.sourceContentType,
    externalIdentifier: source.externalIdentifier,
    licensingAttribution: source.licensingAttribution,
  );

  domain.ContentReviewStatus _reviewStatus(String value) =>
      domain.ContentReviewStatus.values.byName(value);

  ReviewStatus _provenanceReviewStatus(String value) => switch (value) {
    'approved' => ReviewStatus.verified,
    'reviewed' => ReviewStatus.humanReviewed,
    _ => ReviewStatus.unreviewed,
  };

  domain.MorphologyType _morphologyType(String value) =>
      domain.MorphologyType.values.byName(value);
}
