import 'package:drift/drift.dart';

class MedicalTerms extends Table {
  TextColumn get id => text()();
  TextColumn get canonicalTerm => text()();
  TextColumn get normalizedTerm => text()();
  TextColumn get pronunciationText => text().nullable()();
  TextColumn get phoneticRepresentation => text().nullable()();
  TextColumn get categoryId => text()();
  TextColumn get subcategory => text().nullable()();
  TextColumn get language => text().withDefault(const Constant('en'))();
  TextColumn get reviewStatus => text()();
  IntColumn get recordVersion => integer()();
  BoolColumn get deprecated => boolean().withDefault(const Constant(false))();
  TextColumn get replacementTermId => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class TermDefinitions extends Table {
  TextColumn get id => text()();
  TextColumn get termId =>
      text().references(MedicalTerms, #id, onDelete: KeyAction.cascade)();
  TextColumn get language => text()();
  TextColumn get simpleDefinition => text()();
  TextColumn get standardDefinition => text()();
  TextColumn get technicalDefinition => text()();
  TextColumn get sourceLanguage => text().withDefault(const Constant('en'))();
  TextColumn get translationMethod => text().nullable()();
  TextColumn get reviewedBy => text().nullable()();
  DateTimeColumn get reviewedAt => dateTime().nullable()();
  TextColumn get reviewStatus => text()();
  IntColumn get recordVersion => integer()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {termId, language},
  ];
}

class TermAliases extends Table {
  TextColumn get id => text()();
  TextColumn get termId =>
      text().references(MedicalTerms, #id, onDelete: KeyAction.cascade)();
  TextColumn get alias => text()();
  TextColumn get normalizedAlias => text()();
  TextColumn get aliasType => text()();
  TextColumn get language => text().withDefault(const Constant('en'))();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {termId, normalizedAlias, aliasType, language},
  ];
}

class TermExamples extends Table {
  TextColumn get id => text()();
  TextColumn get termId =>
      text().references(MedicalTerms, #id, onDelete: KeyAction.cascade)();
  TextColumn get example => text()();
  TextColumn get language => text().withDefault(const Constant('en'))();
  IntColumn get position => integer()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class ContentSources extends Table {
  TextColumn get id => text()();
  TextColumn get contentId => text()();
  TextColumn get contentType => text()();
  TextColumn get provider => text()();
  TextColumn get sourceTitle => text()();
  TextColumn get sourceIdentifier => text()();
  TextColumn get canonicalReference => text().nullable()();
  DateTimeColumn get retrievedAt => dateTime()();
  DateTimeColumn get sourceUpdatedAt => dateTime().nullable()();
  TextColumn get locale => text()();
  TextColumn get sourceVersion => text()();
  TextColumn get reviewStatus => text()();
  TextColumn get sourceContentType => text()();
  TextColumn get externalIdentifier => text().nullable()();
  TextColumn get licensingAttribution => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class MedicalCategories extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get description => text()();
  TextColumn get parentId => text().nullable()();
  IntColumn get position => integer().withDefault(const Constant(0))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class MorphologyElements extends Table {
  TextColumn get id => text()();
  TextColumn get elementType => text()();
  TextColumn get value => text()();
  TextColumn get normalizedValue => text()();
  TextColumn get meaning => text()();
  TextColumn get explanation => text()();
  TextColumn get examplesJson => text()();
  TextColumn get origin => text().nullable()();
  TextColumn get category => text()();
  TextColumn get language => text()();
  TextColumn get pronunciation => text().nullable()();
  TextColumn get relatedElementIdsJson =>
      text().withDefault(const Constant('[]'))();
  TextColumn get reviewStatus => text()();
  TextColumn get sourceId => text().references(ContentSources, #id)();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class TermMorphologies extends Table {
  TextColumn get id => text()();
  TextColumn get termId =>
      text().references(MedicalTerms, #id, onDelete: KeyAction.cascade)();
  TextColumn get elementId => text().references(MorphologyElements, #id)();
  TextColumn get elementType => text()();
  TextColumn get surfaceText => text()();
  TextColumn get meaning => text()();
  IntColumn get startOffset => integer()();
  IntColumn get endOffset => integer()();
  IntColumn get position => integer()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class TermRelations extends Table {
  @ReferenceName('outgoingTermRelations')
  TextColumn get sourceTermId =>
      text().references(MedicalTerms, #id, onDelete: KeyAction.cascade)();
  @ReferenceName('incomingTermRelations')
  TextColumn get targetTermId =>
      text().references(MedicalTerms, #id, onDelete: KeyAction.cascade)();
  TextColumn get relationType =>
      text().withDefault(const Constant('related'))();

  @override
  Set<Column<Object>> get primaryKey => {
    sourceTermId,
    targetTermId,
    relationType,
  };
}

class MedicalAbbreviations extends Table {
  TextColumn get id => text()();
  TextColumn get termId =>
      text().references(MedicalTerms, #id, onDelete: KeyAction.cascade)();
  TextColumn get abbreviation => text()();
  TextColumn get normalizedAbbreviation => text()();
  TextColumn get expansion => text()();
  TextColumn get context => text()();
  TextColumn get category => text()();
  BoolColumn get ambiguous => boolean()();
  TextColumn get alternativeMeaningsJson =>
      text().withDefault(const Constant('[]'))();
  TextColumn get safetyWarning => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class SearchHistoryItems extends Table {
  TextColumn get id => text()();
  TextColumn get query => text()();
  TextColumn get selectedTermId => text().nullable()();
  DateTimeColumn get searchedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class SavedContentItems extends Table {
  TextColumn get id => text()();
  TextColumn get contentId => text()();
  TextColumn get contentType => text()();
  DateTimeColumn get savedAt => dateTime()();
  TextColumn get syncState => text().withDefault(const Constant('pending'))();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {contentId, contentType},
  ];
}

class LearningLessons extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get description => text()();
  TextColumn get categoryId => text()();
  TextColumn get difficulty => text()();
  IntColumn get estimatedMinutes => integer()();
  TextColumn get objectivesJson => text()();
  TextColumn get reviewQuestionIdsJson => text()();
  TextColumn get reviewStatus => text()();
  IntColumn get recordVersion => integer()();
  TextColumn get sourceId => text().references(ContentSources, #id)();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class LessonSections extends Table {
  TextColumn get id => text()();
  TextColumn get lessonId =>
      text().references(LearningLessons, #id, onDelete: KeyAction.cascade)();
  TextColumn get title => text()();
  TextColumn get content => text()();
  TextColumn get sectionType => text()();
  IntColumn get position => integer()();
  TextColumn get linkedTermIdsJson =>
      text().withDefault(const Constant('[]'))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class Flashcards extends Table {
  TextColumn get id => text()();
  TextColumn get flashcardType => text()();
  TextColumn get front => text()();
  TextColumn get back => text()();
  TextColumn get categoryId => text()();
  TextColumn get difficulty => text()();
  TextColumn get linkedContentId => text().nullable()();
  TextColumn get sourceId => text().references(ContentSources, #id)();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class QuizQuestions extends Table {
  TextColumn get id => text()();
  TextColumn get questionType => text()();
  TextColumn get prompt => text()();
  TextColumn get explanation => text()();
  TextColumn get categoryId => text()();
  TextColumn get difficulty => text()();
  TextColumn get linkedTermId => text().nullable()();
  TextColumn get sourceId => text().references(ContentSources, #id)();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class QuizOptions extends Table {
  TextColumn get id => text()();
  TextColumn get questionId =>
      text().references(QuizQuestions, #id, onDelete: KeyAction.cascade)();
  TextColumn get optionText => text()();
  BoolColumn get isCorrect => boolean()();
  IntColumn get position => integer()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class LessonProgressEntries extends Table {
  TextColumn get lessonId => text()();
  IntColumn get lastSectionIndex => integer()();
  RealColumn get completionPercentage => real()();
  DateTimeColumn get startedAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get completedAt => dateTime().nullable()();
  BoolColumn get reviewRequired =>
      boolean().withDefault(const Constant(false))();
  TextColumn get syncState => text().withDefault(const Constant('pending'))();

  @override
  Set<Column<Object>> get primaryKey => {lessonId};
}

class FlashcardSchedules extends Table {
  TextColumn get flashcardId => text()();
  IntColumn get repetitions => integer()();
  RealColumn get easeFactor => real()();
  IntColumn get intervalDays => integer()();
  DateTimeColumn get lastReviewedAt => dateTime().nullable()();
  DateTimeColumn get nextReviewAt => dateTime()();
  TextColumn get lastPerformance => text().nullable()();
  TextColumn get syncState => text().withDefault(const Constant('pending'))();

  @override
  Set<Column<Object>> get primaryKey => {flashcardId};
}

class QuizAttempts extends Table {
  TextColumn get id => text()();
  IntColumn get correctAnswers => integer()();
  IntColumn get totalQuestions => integer()();
  TextColumn get categoryId => text().nullable()();
  TextColumn get difficulty => text().nullable()();
  TextColumn get answersJson => text()();
  DateTimeColumn get completedAt => dateTime()();
  TextColumn get syncState => text().withDefault(const Constant('pending'))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class LearningStreaks extends Table {
  IntColumn get singletonId => integer().withDefault(const Constant(1))();
  IntColumn get currentStreak => integer().withDefault(const Constant(0))();
  IntColumn get longestStreak => integer().withDefault(const Constant(0))();
  DateTimeColumn get lastLearningDate => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {singletonId};
}

class ContentReports extends Table {
  TextColumn get id => text()();
  TextColumn get recordId => text()();
  TextColumn get reason => text()();
  TextColumn get note => text().nullable()();
  TextColumn get locale => text()();
  TextColumn get appVersion => text()();
  DateTimeColumn get createdAt => dateTime()();
  TextColumn get syncState => text().withDefault(const Constant('pending'))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class ContentVersions extends Table {
  TextColumn get datasetName => text()();
  TextColumn get datasetVersion => text()();
  DateTimeColumn get installedAt => dateTime()();
  DateTimeColumn get lastCheckedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {datasetName};
}
