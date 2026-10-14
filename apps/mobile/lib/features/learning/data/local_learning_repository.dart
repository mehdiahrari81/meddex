import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart' as db;
import '../../../core/sync/sync_coordinator.dart';
import '../../../domain/models/source_provenance.dart';
import '../../terminology/domain/medical_term.dart';
import '../application/streak_calculator.dart';
import '../domain/learning_models.dart';

class LocalLearningRepository implements LearningRepository {
  const LocalLearningRepository(
    this._database,
    this._sync, {
    this.includeReviewedContent = true,
  });
  final db.AppDatabase _database;
  final SyncCoordinator _sync;
  final bool includeReviewedContent;

  List<String> get _publishedStatuses => includeReviewedContent
      ? const ['reviewed', 'approved']
      : const ['approved'];

  @override
  Future<List<LearningLesson>> lessons({
    LearningDifficulty? difficulty,
    String? categoryId,
  }) async {
    final query = _database.select(_database.learningLessons)
      ..where((row) => row.reviewStatus.isIn(_publishedStatuses));
    if (difficulty != null) {
      query.where((row) => row.difficulty.equals(difficulty.name));
    }
    if (categoryId != null) {
      query.where((row) => row.categoryId.equals(categoryId));
    }
    final rows = await query.get();
    final result = <LearningLesson>[];
    for (final row in rows) {
      final lesson = await lessonById(row.id);
      if (lesson != null) result.add(lesson);
    }
    return result;
  }

  @override
  Future<LearningLesson?> lessonById(String id) async {
    final lesson =
        await (_database.select(_database.learningLessons)..where(
              (row) =>
                  row.id.equals(id) & row.reviewStatus.isIn(_publishedStatuses),
            ))
            .getSingleOrNull();
    if (lesson == null) return null;
    final sections =
        await (_database.select(_database.lessonSections)
              ..where((row) => row.lessonId.equals(id))
              ..orderBy([(row) => OrderingTerm.asc(row.position)]))
            .get();
    final source = await _sourceById(lesson.sourceId);
    return LearningLesson(
      id: lesson.id,
      title: lesson.title,
      description: lesson.description,
      categoryId: lesson.categoryId,
      difficulty: LearningDifficulty.values.byName(lesson.difficulty),
      estimatedMinutes: lesson.estimatedMinutes,
      objectives: (jsonDecode(lesson.objectivesJson) as List).cast<String>(),
      sections: sections
          .map(
            (section) => LessonSection(
              id: section.id,
              title: section.title,
              content: section.content,
              type: LessonSectionType.values.byName(section.sectionType),
              position: section.position,
              linkedTermIds: (jsonDecode(section.linkedTermIdsJson) as List)
                  .cast<String>(),
            ),
          )
          .toList(growable: false),
      reviewQuestionIds: (jsonDecode(lesson.reviewQuestionIdsJson) as List)
          .cast<String>(),
      sources: [source],
      reviewStatus: ContentReviewStatus.values.byName(lesson.reviewStatus),
      version: lesson.recordVersion,
    );
  }

  @override
  Future<LessonProgress?> lessonProgress(String lessonId) async {
    final row = await (_database.select(
      _database.lessonProgressEntries,
    )..where((entry) => entry.lessonId.equals(lessonId))).getSingleOrNull();
    return row == null
        ? null
        : LessonProgress(
            lessonId: row.lessonId,
            lastSectionIndex: row.lastSectionIndex,
            completionPercentage: row.completionPercentage,
            startedAt: row.startedAt,
            updatedAt: row.updatedAt,
            completedAt: row.completedAt,
            reviewRequired: row.reviewRequired,
          );
  }

  @override
  Future<void> saveLessonProgress(LessonProgress progress) async {
    await _database
        .into(_database.lessonProgressEntries)
        .insertOnConflictUpdate(
          db.LessonProgressEntriesCompanion.insert(
            lessonId: progress.lessonId,
            lastSectionIndex: progress.lastSectionIndex,
            completionPercentage: progress.completionPercentage,
            startedAt: progress.startedAt,
            updatedAt: progress.updatedAt,
            completedAt: Value(progress.completedAt),
            reviewRequired: Value(progress.reviewRequired),
          ),
        );
    await _sync.enqueue(
      entityType: 'lesson_progress',
      entityId: progress.lessonId,
      operationType: 'update',
      payload: jsonEncode({
        'lesson_id': progress.lessonId,
        'last_section_index': progress.lastSectionIndex,
        'completion_percentage': progress.completionPercentage,
        'started_at': progress.startedAt.toIso8601String(),
        'updated_at': progress.updatedAt.toIso8601String(),
        'completed_at': progress.completedAt?.toIso8601String(),
        'review_required': progress.reviewRequired,
      }),
    );
    if (progress.lastSectionIndex >= 0) {
      await recordMeaningfulActivity(progress.updatedAt);
    }
  }

  @override
  Future<List<Flashcard>> dueFlashcards({int limit = 20}) async {
    final now = DateTime.now().toUtc();
    final rows = await _database
        .customSelect(
          '''
      SELECT f.* FROM flashcards f
      LEFT JOIN flashcard_schedules s ON s.flashcard_id = f.id
      WHERE s.flashcard_id IS NULL OR s.next_review_at <= ?
      ORDER BY COALESCE(s.next_review_at, '1970-01-01') ASC, f.id ASC
      LIMIT ?
      ''',
          variables: [Variable(now), Variable(limit.clamp(1, 100))],
          readsFrom: {_database.flashcards, _database.flashcardSchedules},
        )
        .get();
    final result = <Flashcard>[];
    for (final row in rows) {
      final sourceId = row.read<String>('source_id');
      if (!await _sourceIsPublished(sourceId)) continue;
      result.add(
        Flashcard(
          id: row.read<String>('id'),
          type: FlashcardType.values.byName(row.read<String>('flashcard_type')),
          front: row.read<String>('front'),
          back: row.read<String>('back'),
          categoryId: row.read<String>('category_id'),
          difficulty: LearningDifficulty.values.byName(
            row.read<String>('difficulty'),
          ),
          source: await _sourceById(sourceId),
          linkedContentId: row.readNullable<String>('linked_content_id'),
        ),
      );
    }
    return result;
  }

  @override
  Future<FlashcardSchedule?> flashcardSchedule(String flashcardId) async {
    final row =
        await (_database.select(_database.flashcardSchedules)
              ..where((entry) => entry.flashcardId.equals(flashcardId)))
            .getSingleOrNull();
    return row == null
        ? null
        : FlashcardSchedule(
            flashcardId: row.flashcardId,
            repetitions: row.repetitions,
            easeFactor: row.easeFactor,
            intervalDays: row.intervalDays,
            lastReviewedAt: row.lastReviewedAt,
            nextReviewAt: row.nextReviewAt,
            lastPerformance: row.lastPerformance == null
                ? null
                : ReviewPerformance.values.byName(row.lastPerformance!),
          );
  }

  @override
  Future<void> saveFlashcardReview(FlashcardSchedule schedule) async {
    await _database
        .into(_database.flashcardSchedules)
        .insertOnConflictUpdate(
          db.FlashcardSchedulesCompanion.insert(
            flashcardId: schedule.flashcardId,
            repetitions: schedule.repetitions,
            easeFactor: schedule.easeFactor,
            intervalDays: schedule.intervalDays,
            lastReviewedAt: Value(schedule.lastReviewedAt),
            nextReviewAt: schedule.nextReviewAt,
            lastPerformance: Value(schedule.lastPerformance?.name),
          ),
        );
    await _sync.enqueue(
      entityType: 'flashcard_review',
      entityId: schedule.flashcardId,
      operationType: 'update',
      payload: jsonEncode({
        'flashcard_id': schedule.flashcardId,
        'repetitions': schedule.repetitions,
        'ease_factor': schedule.easeFactor,
        'interval_days': schedule.intervalDays,
        'performance': schedule.lastPerformance?.name ?? 'again',
        'reviewed_at': (schedule.lastReviewedAt ?? DateTime.now().toUtc())
            .toIso8601String(),
        'next_review_at': schedule.nextReviewAt.toIso8601String(),
      }),
    );
    await recordMeaningfulActivity(schedule.lastReviewedAt ?? DateTime.now());
  }

  @override
  Future<List<QuizQuestion>> quizQuestions({
    required int count,
    LearningDifficulty? difficulty,
    String? categoryId,
  }) async {
    final query = _database.select(_database.quizQuestions);
    if (difficulty != null) {
      query.where((row) => row.difficulty.equals(difficulty.name));
    }
    if (categoryId != null) {
      query.where((row) => row.categoryId.equals(categoryId));
    }
    query.limit(count.clamp(1, 50));
    final rows = await query.get();
    final result = <QuizQuestion>[];
    for (final row in rows) {
      if (!await _sourceIsPublished(row.sourceId)) continue;
      final options =
          await (_database.select(_database.quizOptions)
                ..where((option) => option.questionId.equals(row.id))
                ..orderBy([(option) => OrderingTerm.asc(option.position)]))
              .get();
      result.add(
        QuizQuestion(
          id: row.id,
          type: QuizQuestionType.values.byName(row.questionType),
          prompt: row.prompt,
          options: options
              .map(
                (option) => QuizOption(id: option.id, text: option.optionText),
              )
              .toList(growable: false),
          correctOptionIds: options
              .where((option) => option.isCorrect)
              .map((option) => option.id)
              .toSet(),
          explanation: row.explanation,
          categoryId: row.categoryId,
          difficulty: LearningDifficulty.values.byName(row.difficulty),
          source: await _sourceById(row.sourceId),
          linkedTermId: row.linkedTermId,
        ),
      );
    }
    return result;
  }

  @override
  Future<void> saveQuizResult(
    QuizResult result, {
    required DateTime completedAt,
  }) async {
    final id = const Uuid().v4();
    await _database
        .into(_database.quizAttempts)
        .insert(
          db.QuizAttemptsCompanion.insert(
            id: id,
            correctAnswers: result.correctAnswers,
            totalQuestions: result.totalQuestions,
            answersJson: jsonEncode([
              for (final answer in result.questions)
                {
                  'question_id': answer.question.id,
                  'selected_option_ids': answer.answer.selectedOptionIds
                      .toList(),
                  'correct': answer.correct,
                },
            ]),
            completedAt: completedAt.toUtc(),
          ),
        );
    await _sync.enqueue(
      entityType: 'quiz_attempt',
      entityId: id,
      operationType: 'create',
      payload: jsonEncode({
        'id': id,
        'correct_answers': result.correctAnswers,
        'total_questions': result.totalQuestions,
        'answers': [
          for (final answer in result.questions)
            {
              'question_id': answer.question.id,
              'selected_option_ids': answer.answer.selectedOptionIds.toList(),
              'correct': answer.correct,
            },
        ],
        'completed_at': completedAt.toUtc().toIso8601String(),
      }),
    );
    await recordMeaningfulActivity(completedAt);
  }

  @override
  Future<LearningStreak> streak() async {
    final rows =
        await (_database.select(_database.learningStreaks)..orderBy([
              (row) => OrderingTerm.desc(row.lastLearningDate),
              (row) => OrderingTerm.desc(row.singletonId),
            ]))
            .get();
    if (rows.isEmpty) return const LearningStreak(current: 0, longest: 0);
    // Older builds omitted the INTEGER PRIMARY KEY on insert. SQLite assigns
    // a new rowid in that case, even when the column has a default of 1.
    final latest = rows.first;
    return LearningStreak(
      current: latest.currentStreak,
      longest: rows.fold(
        0,
        (best, row) => row.longestStreak > best ? row.longestStreak : best,
      ),
      lastLearningDate: latest.lastLearningDate,
    );
  }

  @override
  Future<void> recordMeaningfulActivity(DateTime occurredAt) async {
    await _database.transaction(() async {
      final updated = const StreakCalculator().record(
        await streak(),
        occurredAt,
      );
      await _database
          .into(_database.learningStreaks)
          .insertOnConflictUpdate(
            db.LearningStreaksCompanion.insert(
              singletonId: const Value(1),
              currentStreak: Value(updated.current),
              longestStreak: Value(updated.longest),
              lastLearningDate: Value(updated.lastLearningDate),
            ),
          );
      await (_database.delete(
        _database.learningStreaks,
      )..where((row) => row.singletonId.equals(1).not())).go();
      await _sync.enqueue(
        entityType: 'learning_progress',
        entityId: 'streak',
        operationType: 'update',
        payload: jsonEncode({
          'current_streak': updated.current,
          'longest_streak': updated.longest,
          'last_learning_date': updated.lastLearningDate?.toIso8601String(),
        }),
      );
    });
  }

  @override
  Future<LearningDashboard> dashboard() async {
    final lessonsCompleted =
        await (_database.selectOnly(_database.lessonProgressEntries)
              ..addColumns([_database.lessonProgressEntries.lessonId.count()])
              ..where(_database.lessonProgressEntries.completedAt.isNotNull()))
            .map(
              (row) =>
                  row.read(_database.lessonProgressEntries.lessonId.count()) ??
                  0,
            )
            .getSingle();
    final reviews = await _database.select(_database.flashcardSchedules).get();
    final attempts = await _database.select(_database.quizAttempts).get();
    final correct = attempts.fold<int>(
      0,
      (total, item) => total + item.correctAnswers,
    );
    final total = attempts.fold<int>(
      0,
      (sum, item) => sum + item.totalQuestions,
    );
    final now = DateTime.now().toUtc();
    return LearningDashboard(
      termsLearned: reviews.where((review) => review.repetitions >= 2).length,
      lessonsCompleted: lessonsCompleted,
      flashcardsReviewed: reviews
          .where((review) => review.lastReviewedAt != null)
          .length,
      quizAccuracy: total == 0 ? 0 : correct / total,
      dueReviews: reviews
          .where((review) => !review.nextReviewAt.isAfter(now))
          .length,
      streak: await streak(),
    );
  }

  Future<bool> _sourceIsPublished(String sourceId) async {
    final source = await (_database.select(
      _database.contentSources,
    )..where((row) => row.id.equals(sourceId))).getSingleOrNull();
    return source != null && _publishedStatuses.contains(source.reviewStatus);
  }

  Future<SourceProvenance> _sourceById(String sourceId) async {
    final source = await (_database.select(
      _database.contentSources,
    )..where((row) => row.id.equals(sourceId))).getSingle();
    return SourceProvenance(
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
      reviewStatus: switch (source.reviewStatus) {
        'approved' => ReviewStatus.verified,
        'reviewed' => ReviewStatus.humanReviewed,
        _ => ReviewStatus.unreviewed,
      },
      contentType: source.sourceContentType,
      externalIdentifier: source.externalIdentifier,
      licensingAttribution: source.licensingAttribution,
    );
  }
}
