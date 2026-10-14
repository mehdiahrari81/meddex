import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/services.dart';

import '../../../core/database/app_database.dart';

class TerminologyImportReport {
  const TerminologyImportReport({
    required this.datasetVersion,
    required this.termCount,
    required this.morphologyCount,
    required this.lessonCount,
    required this.flashcardCount,
    required this.quizQuestionCount,
    required this.changed,
    required this.productionApproved,
  });
  final String datasetVersion;
  final int termCount;
  final int morphologyCount;
  final int lessonCount;
  final int flashcardCount;
  final int quizQuestionCount;
  final bool changed;
  final bool productionApproved;
}

class TerminologySeedImporter {
  TerminologySeedImporter(this._database, {AssetBundle? assets})
    : _assets = assets ?? rootBundle;

  final AppDatabase _database;
  final AssetBundle _assets;

  Future<TerminologyImportReport> importBundled({bool dryRun = false}) async {
    final raw = await _assets.loadString(
      'assets/terminology/starter_dataset_v1.json',
    );
    return importJson(raw, dryRun: dryRun, onlyIfEmpty: true);
  }

  Future<TerminologyImportReport> importJson(
    String raw, {
    bool dryRun = false,
    bool onlyIfEmpty = false,
  }) async {
    final document = _validate(jsonDecode(raw));
    final datasetVersion = document.string('dataset_version');
    final current =
        await (_database.select(_database.contentVersions)..where(
              (row) => row.datasetName.equals(document.string('dataset_name')),
            ))
            .getSingleOrNull();
    final report = TerminologyImportReport(
      datasetVersion: onlyIfEmpty && current != null
          ? current.datasetVersion
          : datasetVersion,
      termCount: document.list('terms').length,
      morphologyCount: document.list('morphology').length,
      lessonCount: document.list('lessons').length,
      flashcardCount: document.list('flashcards').length,
      quizQuestionCount: document.list('quiz_questions').length,
      changed:
          (!onlyIfEmpty || current == null) &&
          current?.datasetVersion != datasetVersion,
      productionApproved: document.boolean('production_approved'),
    );
    if (dryRun || !report.changed) return report;
    await _database.transaction(() async {
      await _importSources(document.list('sources'));
      await _importCategories(document.list('categories'));
      await _importMorphology(document.list('morphology'));
      await _importTerms(document.list('terms'), document.list('sources'));
      await _importAbbreviations(document.list('abbreviations'));
      await _importLearning(document);
      await _database
          .into(_database.contentVersions)
          .insertOnConflictUpdate(
            ContentVersionsCompanion.insert(
              datasetName: document.string('dataset_name'),
              datasetVersion: datasetVersion,
              installedAt: DateTime.now().toUtc(),
            ),
          );
    });
    return report;
  }

  Map<String, Object?> _validate(Object? raw) {
    if (raw is! Map<String, Object?>) {
      throw const FormatException('Terminology dataset must be a JSON object.');
    }
    if (raw['schema_version'] != 1) {
      throw const FormatException('Unsupported terminology schema version.');
    }
    for (final key in [
      'dataset_name',
      'dataset_version',
      'production_approved',
      'generated_at',
      'sources',
      'categories',
      'morphology',
      'terms',
      'abbreviations',
      'lessons',
      'flashcards',
      'quiz_questions',
    ]) {
      if (!raw.containsKey(key)) {
        throw FormatException('Missing dataset field: $key');
      }
    }
    raw.string('dataset_name');
    raw.string('dataset_version');
    raw.boolean('production_approved');
    DateTime.parse(raw.string('generated_at'));

    Set<String> uniqueIds(String collection) {
      final ids = <String>{};
      for (final value in raw.list(collection)) {
        final id = value.object().string('id');
        if (!ids.add(id)) {
          throw FormatException('Duplicate $collection ID: $id');
        }
      }
      return ids;
    }

    final sourceIds = uniqueIds('sources');
    final categoryIds = uniqueIds('categories');
    final morphologyIds = uniqueIds('morphology');
    final termIds = uniqueIds('terms');
    uniqueIds('abbreviations');
    final lessonIds = uniqueIds('lessons');
    uniqueIds('flashcards');
    final questionIds = uniqueIds('quiz_questions');
    const reviewStatuses = {'draft', 'reviewed', 'approved', 'deprecated'};
    const difficulties = {'beginner', 'intermediate', 'advanced'};
    void validateReviewStatus(Map<String, Object?> item) {
      if (!reviewStatuses.contains(item.string('review_status'))) {
        throw FormatException(
          'Invalid review status: ${item.string('review_status')}',
        );
      }
    }

    for (final value in raw.list('sources')) {
      final item = value.object();
      item.string('provider');
      item.string('source_title');
      item.string('source_identifier');
      item.optionalString('canonical_reference');
      DateTime.parse(item.string('retrieved_at'));
      item.optionalDate('source_updated_at');
      item.string('locale');
      item.string('version');
      item.string('content_type');
      item.optionalString('external_identifier');
      item.optionalString('licensing_attribution');
      validateReviewStatus(item);
    }
    for (final value in raw.list('categories')) {
      final item = value.object();
      item.string('name');
      item.string('description');
      item.integer('position');
      final parentId = item.optionalString('parent_id');
      if (parentId != null && !categoryIds.contains(parentId)) {
        throw FormatException('Unknown parent category: $parentId');
      }
    }
    for (final value in raw.list('morphology')) {
      final item = value.object();
      if (!{'prefix', 'root', 'suffix'}.contains(item.string('type'))) {
        throw FormatException(
          'Invalid morphology type: ${item.string('type')}',
        );
      }
      item.string('value');
      item.string('meaning');
      item.string('explanation');
      item.stringList('examples');
      item.optionalString('origin');
      item.string('category');
      item.string('language');
      item.optionalString('pronunciation');
      item.stringList('related_element_ids', optional: true);
      validateReviewStatus(item);
    }
    final normalizedTerms = <String>{};
    for (final rawTerm in raw.list('terms')) {
      final term = rawTerm.object();
      final id = term.string('id');
      if (term.string('term').trim().isEmpty ||
          term.string('normalized').trim().isEmpty) {
        throw FormatException('Malformed medical term: $id');
      }
      final normalizedKey =
          '${_normalize(term.string('normalized'))}:'
          '${term.string('language')}';
      if (!normalizedTerms.add(normalizedKey)) {
        throw FormatException('Duplicate normalized term: $normalizedKey');
      }
      if (!categoryIds.contains(term.string('category_id'))) {
        throw FormatException('Unknown category for term: $id');
      }
      if (!sourceIds.contains(term.string('source_id'))) {
        throw FormatException('Unknown source for term: $id');
      }
      final definitions = term.nestedMap('definitions');
      definitions.string('simple');
      definitions.string('standard');
      definitions.string('technical');
      definitions.optionalString('source_language');
      definitions.optionalString('translation_method');
      definitions.optionalString('reviewed_by');
      definitions.optionalDate('reviewed_at');
      term.optionalString('pronunciation');
      term.optionalString('phonetic');
      term.optionalString('subcategory');
      term.integer('version');
      term.optionalBoolean('deprecated');
      term.optionalString('replacement_term_id');
      term.stringList('synonyms');
      term.stringList('alternative_spellings');
      term.stringList('lay_terms');
      term.stringList('abbreviations');
      term.stringList('examples');
      validateReviewStatus(term);
      for (final relatedId in term.stringList('related_term_ids')) {
        if (!termIds.contains(relatedId)) {
          throw FormatException('Unknown related term: $relatedId');
        }
      }
      for (final value in term.list('morphology')) {
        final elementId = value.object().string('element_id');
        if (!morphologyIds.contains(elementId)) {
          throw FormatException('Unknown morphology element: $elementId');
        }
      }
    }
    for (final value in raw.list('abbreviations')) {
      final item = value.object();
      item.string('abbreviation');
      item.string('expansion');
      item.string('context');
      item.string('category');
      item.boolean('ambiguous');
      item.stringList('alternative_meanings');
      item.optionalString('safety_warning');
      if (!termIds.contains(item.string('term_id'))) {
        throw FormatException(
          'Unknown abbreviation term: ${item.string('term_id')}',
        );
      }
    }
    for (final value in raw.list('lessons')) {
      final item = value.object();
      item.string('title');
      item.string('description');
      if (!categoryIds.contains(item.string('category_id'))) {
        throw FormatException(
          'Unknown lesson category: ${item.string('category_id')}',
        );
      }
      if (!difficulties.contains(item.string('difficulty'))) {
        throw FormatException(
          'Invalid lesson difficulty: ${item.string('difficulty')}',
        );
      }
      item.integer('estimated_minutes');
      item.stringList('objectives');
      item.integer('version');
      validateReviewStatus(item);
      if (!sourceIds.contains(item.string('source_id'))) {
        throw FormatException(
          'Unknown lesson source: ${item.string('source_id')}',
        );
      }
      for (final questionId
          in item.list('review_question_ids').cast<String>()) {
        if (!questionIds.contains(questionId)) {
          throw FormatException('Unknown review question: $questionId');
        }
      }
      for (final value in item.list('sections')) {
        final section = value.object();
        section.string('id');
        section.string('title');
        section.string('content');
        section.string('type');
        section.integer('position');
        for (final termId in section.stringList('linked_term_ids')) {
          if (!termIds.contains(termId)) {
            throw FormatException('Unknown lesson term: $termId');
          }
        }
      }
    }
    for (final value in raw.list('flashcards')) {
      final item = value.object();
      item.string('type');
      item.string('front');
      item.string('back');
      item.string('category_id');
      if (!difficulties.contains(item.string('difficulty'))) {
        throw FormatException(
          'Invalid flashcard difficulty: ${item.string('difficulty')}',
        );
      }
      if (!sourceIds.contains(item.string('source_id'))) {
        throw FormatException(
          'Unknown flashcard source: ${item.string('source_id')}',
        );
      }
      final linkedId = item.optionalString('linked_content_id');
      if (linkedId != null &&
          !termIds.contains(linkedId) &&
          !morphologyIds.contains(linkedId)) {
        throw FormatException('Unknown flashcard content: $linkedId');
      }
    }
    for (final value in raw.list('quiz_questions')) {
      final item = value.object();
      item.string('type');
      item.string('prompt');
      item.string('explanation');
      item.string('category_id');
      if (!difficulties.contains(item.string('difficulty'))) {
        throw FormatException(
          'Invalid quiz difficulty: ${item.string('difficulty')}',
        );
      }
      if (!sourceIds.contains(item.string('source_id'))) {
        throw FormatException(
          'Unknown quiz source: ${item.string('source_id')}',
        );
      }
      final linkedId = item.optionalString('linked_term_id');
      if (linkedId != null && !termIds.contains(linkedId)) {
        throw FormatException('Unknown quiz term: $linkedId');
      }
      final options = item.list('options');
      final optionIds = <String>{};
      for (final option in options) {
        final optionItem = option.object();
        if (!optionIds.add(optionItem.string('id'))) {
          throw FormatException(
            'Duplicate quiz option ID: ${optionItem.string('id')}',
          );
        }
        optionItem.string('text');
        optionItem.boolean('correct');
      }
      if (options.length < 2 ||
          options
                  .where((option) => option.object().boolean('correct'))
                  .length !=
              1) {
        throw FormatException(
          'Quiz ${item.string('id')} must have at least two options and one correct answer.',
        );
      }
    }
    if (lessonIds.isEmpty) {
      throw const FormatException('At least one learning lesson is required.');
    }
    return raw;
  }

  Future<void> _importSources(List<Object?> values) async {
    for (final value in values) {
      final item = value.object();
      await _database
          .into(_database.contentSources)
          .insertOnConflictUpdate(
            ContentSourcesCompanion.insert(
              id: item.string('id'),
              contentId: item.string('id'),
              contentType: item.string('content_type'),
              provider: item.string('provider'),
              sourceTitle: item.string('source_title'),
              sourceIdentifier: item.string('source_identifier'),
              canonicalReference: Value(
                item.optionalString('canonical_reference'),
              ),
              retrievedAt: DateTime.parse(item.string('retrieved_at')).toUtc(),
              sourceUpdatedAt: Value(item.optionalDate('source_updated_at')),
              locale: item.string('locale'),
              sourceVersion: item.string('version'),
              reviewStatus: item.string('review_status'),
              sourceContentType: item.string('content_type'),
              externalIdentifier: Value(
                item.optionalString('external_identifier'),
              ),
              licensingAttribution: Value(
                item.optionalString('licensing_attribution'),
              ),
            ),
          );
    }
  }

  Future<void> _importCategories(List<Object?> values) async {
    for (final value in values) {
      final item = value.object();
      await _database
          .into(_database.medicalCategories)
          .insertOnConflictUpdate(
            MedicalCategoriesCompanion.insert(
              id: item.string('id'),
              name: item.string('name'),
              description: item.string('description'),
              parentId: Value(item.optionalString('parent_id')),
              position: Value(item.integer('position')),
            ),
          );
    }
  }

  Future<void> _importMorphology(List<Object?> values) async {
    for (final value in values) {
      final item = value.object();
      await _database
          .into(_database.morphologyElements)
          .insertOnConflictUpdate(
            MorphologyElementsCompanion.insert(
              id: item.string('id'),
              elementType: item.string('type'),
              value: item.string('value'),
              normalizedValue: _compact(item.string('value')),
              meaning: item.string('meaning'),
              explanation: item.string('explanation'),
              examplesJson: jsonEncode(item.list('examples')),
              origin: Value(item.optionalString('origin')),
              category: item.string('category'),
              language: item.string('language'),
              pronunciation: Value(item.optionalString('pronunciation')),
              relatedElementIdsJson: Value(
                jsonEncode(item.optionalList('related_element_ids')),
              ),
              reviewStatus: item.string('review_status'),
              sourceId: item.string('source_id'),
            ),
          );
    }
  }

  Future<void> _importTerms(
    List<Object?> values,
    List<Object?> sourceValues,
  ) async {
    final timestamp = DateTime.now().toUtc();
    final sources = {
      for (final value in sourceValues)
        value.object().string('id'): value.object(),
    };
    for (final value in values) {
      final item = value.object();
      await _database
          .into(_database.medicalTerms)
          .insertOnConflictUpdate(
            MedicalTermsCompanion.insert(
              id: item.string('id'),
              canonicalTerm: item.string('term'),
              normalizedTerm: item.string('normalized'),
              pronunciationText: Value(item.optionalString('pronunciation')),
              phoneticRepresentation: Value(item.optionalString('phonetic')),
              categoryId: item.string('category_id'),
              subcategory: Value(item.optionalString('subcategory')),
              language: Value(item.optionalString('language') ?? 'en'),
              reviewStatus: item.string('review_status'),
              recordVersion: item.integer('version'),
              deprecated: Value(item.optionalBoolean('deprecated') ?? false),
              replacementTermId: Value(
                item.optionalString('replacement_term_id'),
              ),
              createdAt: timestamp,
              updatedAt: timestamp,
            ),
          );
    }
    for (final value in values) {
      final item = value.object();
      final termId = item.string('id');
      await (_database.delete(
        _database.termDefinitions,
      )..where((row) => row.termId.equals(termId))).go();
      await (_database.delete(
        _database.termAliases,
      )..where((row) => row.termId.equals(termId))).go();
      await (_database.delete(
        _database.termExamples,
      )..where((row) => row.termId.equals(termId))).go();
      await (_database.delete(
        _database.termMorphologies,
      )..where((row) => row.termId.equals(termId))).go();
      await (_database.delete(
        _database.termRelations,
      )..where((row) => row.sourceTermId.equals(termId))).go();
      final definitions = item.nestedMap('definitions');
      final definitionLanguage = item.optionalString('language') ?? 'en';
      await _database
          .into(_database.termDefinitions)
          .insertOnConflictUpdate(
            TermDefinitionsCompanion.insert(
              id: '$termId:$definitionLanguage',
              termId: termId,
              language: definitionLanguage,
              simpleDefinition: definitions.string('simple'),
              standardDefinition: definitions.string('standard'),
              technicalDefinition: definitions.string('technical'),
              sourceLanguage: Value(
                definitions.optionalString('source_language') ??
                    item.optionalString('language') ??
                    'en',
              ),
              translationMethod: Value(
                definitions.optionalString('translation_method') ??
                    (item.optionalString('language') == null ||
                            item.optionalString('language') == 'en'
                        ? 'original'
                        : null),
              ),
              reviewedBy: Value(definitions.optionalString('reviewed_by')),
              reviewedAt: Value(definitions.optionalDate('reviewed_at')),
              reviewStatus: item.string('review_status'),
              recordVersion: item.integer('version'),
            ),
          );
      var position = 0;
      for (final entry in <(String, String, List<Object?>)>[
        ('synonym', 'synonyms', item.list('synonyms')),
        (
          'alternative',
          'alternative_spellings',
          item.list('alternative_spellings'),
        ),
        ('lay', 'lay_terms', item.list('lay_terms')),
        ('abbreviation', 'abbreviations', item.list('abbreviations')),
      ]) {
        for (final alias in entry.$3.cast<String>()) {
          await _database
              .into(_database.termAliases)
              .insertOnConflictUpdate(
                TermAliasesCompanion.insert(
                  id: '$termId:${entry.$1}:${position++}',
                  termId: termId,
                  alias: alias,
                  normalizedAlias: _normalize(alias),
                  aliasType: entry.$1,
                ),
              );
        }
      }
      position = 0;
      for (final example in item.list('examples').cast<String>()) {
        await _database
            .into(_database.termExamples)
            .insertOnConflictUpdate(
              TermExamplesCompanion.insert(
                id: '$termId:example:${position++}',
                termId: termId,
                example: example,
                position: position,
              ),
            );
      }
      position = 0;
      for (final rawComponent in item.list('morphology')) {
        final component = rawComponent.object();
        await _database
            .into(_database.termMorphologies)
            .insertOnConflictUpdate(
              TermMorphologiesCompanion.insert(
                id: '$termId:morphology:${position++}',
                termId: termId,
                elementId: component.string('element_id'),
                elementType: component.string('type'),
                surfaceText: component.string('surface'),
                meaning: component.string('meaning'),
                startOffset: component.integer('start'),
                endOffset: component.integer('end'),
                position: position,
              ),
            );
      }
      for (final relatedId in item.list('related_term_ids').cast<String>()) {
        await _database
            .into(_database.termRelations)
            .insertOnConflictUpdate(
              TermRelationsCompanion.insert(
                sourceTermId: termId,
                targetTermId: relatedId,
              ),
            );
      }
      final source = sources[item.string('source_id')]!;
      await _database
          .into(_database.contentSources)
          .insertOnConflictUpdate(
            ContentSourcesCompanion.insert(
              id: '$termId:source',
              contentId: termId,
              contentType: 'medical_term',
              provider: source.string('provider'),
              sourceTitle: source.string('source_title'),
              sourceIdentifier: source.string('source_identifier'),
              canonicalReference: Value(
                source.optionalString('canonical_reference'),
              ),
              retrievedAt: DateTime.parse(
                source.string('retrieved_at'),
              ).toUtc(),
              sourceUpdatedAt: Value(source.optionalDate('source_updated_at')),
              locale: source.string('locale'),
              sourceVersion: source.string('version'),
              reviewStatus: source.string('review_status'),
              sourceContentType: source.string('content_type'),
              externalIdentifier: Value(
                source.optionalString('external_identifier'),
              ),
              licensingAttribution: Value(
                source.optionalString('licensing_attribution'),
              ),
            ),
          );
    }
  }

  Future<void> _importAbbreviations(List<Object?> values) async {
    for (final value in values) {
      final item = value.object();
      await _database
          .into(_database.medicalAbbreviations)
          .insertOnConflictUpdate(
            MedicalAbbreviationsCompanion.insert(
              id: item.string('id'),
              termId: item.string('term_id'),
              abbreviation: item.string('abbreviation'),
              normalizedAbbreviation: _normalize(item.string('abbreviation')),
              expansion: item.string('expansion'),
              context: item.string('context'),
              category: item.string('category'),
              ambiguous: item.boolean('ambiguous'),
              alternativeMeaningsJson: Value(
                jsonEncode(item.list('alternative_meanings')),
              ),
              safetyWarning: Value(item.optionalString('safety_warning')),
            ),
          );
    }
  }

  Future<void> _importLearning(Map<String, Object?> document) async {
    for (final value in document.list('lessons')) {
      final item = value.object();
      await _database
          .into(_database.learningLessons)
          .insertOnConflictUpdate(
            LearningLessonsCompanion.insert(
              id: item.string('id'),
              title: item.string('title'),
              description: item.string('description'),
              categoryId: item.string('category_id'),
              difficulty: item.string('difficulty'),
              estimatedMinutes: item.integer('estimated_minutes'),
              objectivesJson: jsonEncode(item.list('objectives')),
              reviewQuestionIdsJson: jsonEncode(
                item.list('review_question_ids'),
              ),
              reviewStatus: item.string('review_status'),
              recordVersion: item.integer('version'),
              sourceId: item.string('source_id'),
            ),
          );
      for (final rawSection in item.list('sections')) {
        final section = rawSection.object();
        await _database
            .into(_database.lessonSections)
            .insertOnConflictUpdate(
              LessonSectionsCompanion.insert(
                id: section.string('id'),
                lessonId: item.string('id'),
                title: section.string('title'),
                content: section.string('content'),
                sectionType: section.string('type'),
                position: section.integer('position'),
                linkedTermIdsJson: Value(
                  jsonEncode(section.list('linked_term_ids')),
                ),
              ),
            );
      }
    }
    for (final value in document.list('flashcards')) {
      final item = value.object();
      await _database
          .into(_database.flashcards)
          .insertOnConflictUpdate(
            FlashcardsCompanion.insert(
              id: item.string('id'),
              flashcardType: item.string('type'),
              front: item.string('front'),
              back: item.string('back'),
              categoryId: item.string('category_id'),
              difficulty: item.string('difficulty'),
              linkedContentId: Value(item.optionalString('linked_content_id')),
              sourceId: item.string('source_id'),
            ),
          );
    }
    for (final value in document.list('quiz_questions')) {
      final item = value.object();
      await _database
          .into(_database.quizQuestions)
          .insertOnConflictUpdate(
            QuizQuestionsCompanion.insert(
              id: item.string('id'),
              questionType: item.string('type'),
              prompt: item.string('prompt'),
              explanation: item.string('explanation'),
              categoryId: item.string('category_id'),
              difficulty: item.string('difficulty'),
              linkedTermId: Value(item.optionalString('linked_term_id')),
              sourceId: item.string('source_id'),
            ),
          );
      var position = 0;
      for (final rawOption in item.list('options')) {
        final option = rawOption.object();
        await _database
            .into(_database.quizOptions)
            .insertOnConflictUpdate(
              QuizOptionsCompanion.insert(
                id: option.string('id'),
                questionId: item.string('id'),
                optionText: option.string('text'),
                isCorrect: option.boolean('correct'),
                position: position++,
              ),
            );
      }
    }
  }

  String _normalize(String value) => value
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9\s-]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  String _compact(String value) =>
      _normalize(value).replaceAll(RegExp(r'[\s-]'), '');
}

extension _JsonObject on Map<String, Object?> {
  String string(String key) {
    final value = this[key];
    if (value is! String) throw FormatException('$key must be a string.');
    return value;
  }

  String? optionalString(String key) => this[key] as String?;
  int integer(String key) => this[key] as int;
  bool boolean(String key) => this[key] as bool;
  bool? optionalBoolean(String key) => this[key] as bool?;
  List<Object?> list(String key) => this[key] as List<Object?>;
  List<Object?> optionalList(String key) => this[key] as List<Object?>? ?? [];
  List<String> stringList(String key, {bool optional = false}) {
    final value = optional ? optionalList(key) : list(key);
    if (value.any((item) => item is! String)) {
      throw FormatException('$key must contain only strings.');
    }
    return value.cast<String>();
  }

  Map<String, Object?> nestedMap(String key) =>
      (this[key] as Map).cast<String, Object?>();
  DateTime? optionalDate(String key) {
    final value = optionalString(key);
    return value == null ? null : DateTime.parse(value).toUtc();
  }
}

extension _JsonValue on Object? {
  Map<String, Object?> object() => (this as Map).cast<String, Object?>();
}
