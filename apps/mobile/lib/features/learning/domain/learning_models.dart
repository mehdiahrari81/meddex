import '../../../domain/models/source_provenance.dart';
import '../../terminology/domain/medical_term.dart';

enum LearningDifficulty { beginner, intermediate, advanced }

enum LessonSectionType { text, example, morphology, review }

class LessonSection {
  const LessonSection({
    required this.id,
    required this.title,
    required this.content,
    required this.type,
    required this.position,
    this.linkedTermIds = const [],
  });
  final String id;
  final String title;
  final String content;
  final LessonSectionType type;
  final int position;
  final List<String> linkedTermIds;
}

class LearningLesson {
  const LearningLesson({
    required this.id,
    required this.title,
    required this.description,
    required this.categoryId,
    required this.difficulty,
    required this.estimatedMinutes,
    required this.objectives,
    required this.sections,
    required this.reviewQuestionIds,
    required this.sources,
    required this.reviewStatus,
    required this.version,
  });
  final String id;
  final String title;
  final String description;
  final String categoryId;
  final LearningDifficulty difficulty;
  final int estimatedMinutes;
  final List<String> objectives;
  final List<LessonSection> sections;
  final List<String> reviewQuestionIds;
  final List<SourceProvenance> sources;
  final ContentReviewStatus reviewStatus;
  final int version;
}

enum FlashcardType {
  termToMeaning,
  meaningToTerm,
  elementToMeaning,
  abbreviationToExpansion,
}

class Flashcard {
  const Flashcard({
    required this.id,
    required this.type,
    required this.front,
    required this.back,
    required this.categoryId,
    required this.difficulty,
    required this.source,
    this.linkedContentId,
  });
  final String id;
  final FlashcardType type;
  final String front;
  final String back;
  final String categoryId;
  final LearningDifficulty difficulty;
  final SourceProvenance source;
  final String? linkedContentId;
}

enum ReviewPerformance { again, hard, good, easy }

class FlashcardSchedule {
  const FlashcardSchedule({
    required this.flashcardId,
    required this.repetitions,
    required this.easeFactor,
    required this.intervalDays,
    required this.nextReviewAt,
    this.lastReviewedAt,
    this.lastPerformance,
  });
  final String flashcardId;
  final int repetitions;
  final double easeFactor;
  final int intervalDays;
  final DateTime? lastReviewedAt;
  final DateTime nextReviewAt;
  final ReviewPerformance? lastPerformance;
}

enum QuizQuestionType {
  multipleChoice,
  trueFalse,
  matching,
  identifyMorphology,
  chooseMeaning,
  selectTerm,
  abbreviationMeaning,
}

class QuizOption {
  const QuizOption({required this.id, required this.text});
  final String id;
  final String text;
}

class QuizQuestion {
  const QuizQuestion({
    required this.id,
    required this.type,
    required this.prompt,
    required this.options,
    required this.correctOptionIds,
    required this.explanation,
    required this.categoryId,
    required this.difficulty,
    required this.source,
    this.linkedTermId,
  });
  final String id;
  final QuizQuestionType type;
  final String prompt;
  final List<QuizOption> options;
  final Set<String> correctOptionIds;
  final String explanation;
  final String categoryId;
  final LearningDifficulty difficulty;
  final SourceProvenance source;
  final String? linkedTermId;
}

class QuizAnswer {
  const QuizAnswer({required this.questionId, required this.selectedOptionIds});
  final String questionId;
  final Set<String> selectedOptionIds;
}

class QuizQuestionResult {
  const QuizQuestionResult({
    required this.question,
    required this.answer,
    required this.correct,
  });
  final QuizQuestion question;
  final QuizAnswer answer;
  final bool correct;
}

class QuizResult {
  const QuizResult({required this.questions, required this.correctAnswers});
  final List<QuizQuestionResult> questions;
  final int correctAnswers;
  int get totalQuestions => questions.length;
  double get accuracy =>
      totalQuestions == 0 ? 0 : correctAnswers / totalQuestions;
  List<QuizQuestionResult> get mistakes =>
      questions.where((result) => !result.correct).toList(growable: false);
}

class LessonProgress {
  const LessonProgress({
    required this.lessonId,
    required this.lastSectionIndex,
    required this.completionPercentage,
    required this.startedAt,
    required this.updatedAt,
    required this.reviewRequired,
    this.completedAt,
  });
  final String lessonId;
  final int lastSectionIndex;
  final double completionPercentage;
  final DateTime startedAt;
  final DateTime updatedAt;
  final DateTime? completedAt;
  final bool reviewRequired;
}

class LearningStreak {
  const LearningStreak({
    required this.current,
    required this.longest,
    this.lastLearningDate,
  });
  final int current;
  final int longest;
  final DateTime? lastLearningDate;
}

class LearningDashboard {
  const LearningDashboard({
    required this.termsLearned,
    required this.lessonsCompleted,
    required this.flashcardsReviewed,
    required this.quizAccuracy,
    required this.dueReviews,
    required this.streak,
    this.strongestCategory,
    this.categoryNeedingReview,
  });
  final int termsLearned;
  final int lessonsCompleted;
  final int flashcardsReviewed;
  final double quizAccuracy;
  final int dueReviews;
  final LearningStreak streak;
  final String? strongestCategory;
  final String? categoryNeedingReview;
}

abstract interface class LearningRepository {
  Future<List<LearningLesson>> lessons({
    LearningDifficulty? difficulty,
    String? categoryId,
  });
  Future<LearningLesson?> lessonById(String id);
  Future<LessonProgress?> lessonProgress(String lessonId);
  Future<void> saveLessonProgress(LessonProgress progress);
  Future<List<Flashcard>> dueFlashcards({int limit = 20});
  Future<FlashcardSchedule?> flashcardSchedule(String flashcardId);
  Future<void> saveFlashcardReview(FlashcardSchedule schedule);
  Future<List<QuizQuestion>> quizQuestions({
    required int count,
    LearningDifficulty? difficulty,
    String? categoryId,
  });
  Future<void> saveQuizResult(
    QuizResult result, {
    required DateTime completedAt,
  });
  Future<LearningDashboard> dashboard();
  Future<LearningStreak> streak();
  Future<void> recordMeaningfulActivity(DateTime occurredAt);
}
