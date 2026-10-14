import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediexplain/core/database/app_database.dart';
import 'package:mediexplain/core/sync/sync_coordinator.dart';
import 'package:mediexplain/features/learning/application/quiz_engine.dart';
import 'package:mediexplain/features/learning/application/spaced_repetition.dart';
import 'package:mediexplain/features/learning/data/local_learning_repository.dart';
import 'package:mediexplain/features/learning/domain/learning_models.dart';
import 'package:mediexplain/features/saved/data/local_saved_content_repository.dart';
import 'package:mediexplain/features/terminology/data/content_update_service.dart';
import 'package:mediexplain/features/terminology/data/local_terminology_repository.dart';
import 'package:mediexplain/features/terminology/data/terminology_seed_importer.dart';
import 'package:mediexplain/features/terminology/domain/medical_term.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase database;
  late SyncCoordinator sync;
  late LocalLearningRepository learning;
  late String rawDataset;

  setUp(() async {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    rawDataset = File(
      'assets/terminology/starter_dataset_v1.json',
    ).readAsStringSync();
    await TerminologySeedImporter(database).importJson(rawDataset);
    sync = SyncCoordinator(
      database: database,
      transport: const DisabledSyncTransport(),
    );
    learning = LocalLearningRepository(database, sync);
  });

  tearDown(() => database.close());

  test(
    'terms, lessons, flashcards, and quizzes are available offline',
    () async {
      final term = await LocalTerminologyRepository(
        database,
      ).termById('term-hypertension');
      expect(term, isNotNull);
      expect(term!.definitions.single.sourceLanguage, 'en');
      expect(term.definitions.single.translationMethod, 'original');
      expect(
        term.sources.single.provider,
        'MediExplain Editorial Development Dataset',
      );
      expect(
        term.sources.single.sourceIdentifier,
        'mediexplain-dev-seed-2026.08.2',
      );
      expect(await learning.lessons(), isNotEmpty);
      expect(await learning.dueFlashcards(), isNotEmpty);
      expect(await learning.quizQuestions(count: 4), hasLength(4));
    },
  );

  test(
    'development seed is excluded by production publication policy',
    () async {
      expect(
        await LocalTerminologyRepository(
          database,
          includeReviewedContent: false,
        ).termById('term-hypertension'),
        isNull,
      );
      final productionLearning = LocalLearningRepository(
        database,
        sync,
        includeReviewedContent: false,
      );
      expect(await productionLearning.lessons(), isEmpty);
      expect(await productionLearning.dueFlashcards(), isEmpty);
      expect(await productionLearning.quizQuestions(count: 4), isEmpty);
    },
  );

  test('save is persistent, idempotent, removable, and sync-ready', () async {
    final saved = LocalSavedContentRepository(database, sync);
    await saved.save('term-hypertension', MedicalContentType.term);
    await saved.save('term-hypertension', MedicalContentType.term);
    expect(await saved.watch().first, hasLength(1));
    expect(await database.pendingOperations(), hasLength(1));
    await saved.unsave('term-hypertension', MedicalContentType.term);
    expect(await saved.watch().first, isEmpty);
    expect(await database.pendingOperations(), hasLength(2));
  });

  test(
    'lesson progress resumes offline and opening alone does not affect streak',
    () async {
      final before = await learning.streak();
      expect(before.current, 0);
      await learning.lessonById('lesson-intro-morphology');
      expect((await learning.streak()).current, 0);
      final now = DateTime.utc(2026, 8, 12, 10);
      await learning.saveLessonProgress(
        LessonProgress(
          lessonId: 'lesson-intro-morphology',
          lastSectionIndex: 1,
          completionPercentage: 2 / 3,
          startedAt: now.subtract(const Duration(minutes: 3)),
          updatedAt: now,
          reviewRequired: false,
        ),
      );
      final resumed = await learning.lessonProgress('lesson-intro-morphology');
      expect(resumed?.lastSectionIndex, 1);
      expect(resumed?.completionPercentage, closeTo(2 / 3, 0.001));
      expect((await learning.streak()).current, 1);
    },
  );

  test('spaced repetition review is deterministic and persisted', () async {
    final now = DateTime.utc(2026, 8, 12, 12);
    final initial = const SpacedRepetitionScheduler().initial('card-itis', now);
    final reviewed = const SpacedRepetitionScheduler().review(
      current: initial,
      performance: ReviewPerformance.good,
      reviewedAt: now,
    );
    expect(reviewed.intervalDays, 1);
    expect(reviewed.nextReviewAt, DateTime.utc(2026, 8, 13, 12));
    await learning.saveFlashcardReview(reviewed);
    expect((await learning.flashcardSchedule('card-itis'))?.repetitions, 1);
  });

  test(
    'repeated learning activity keeps one streak and advances across days',
    () async {
      final first = DateTime(2026, 8, 12, 12);
      await learning.recordMeaningfulActivity(first);
      await learning.recordMeaningfulActivity(
        first.add(const Duration(hours: 1)),
      );
      expect((await learning.streak()).current, 1);
      await learning.recordMeaningfulActivity(
        first.add(const Duration(days: 1)),
      );
      expect((await learning.streak()).current, 2);
      expect((await learning.streak()).longest, 2);
      final rows = await database.select(database.learningStreaks).get();
      expect(rows, hasLength(1));
      expect(rows.single.singletonId, 1);
    },
  );

  test(
    'legacy duplicate streaks recover latest activity and longest streak',
    () async {
      await database
          .into(database.learningStreaks)
          .insert(
            LearningStreaksCompanion.insert(
              singletonId: const Value(1),
              currentStreak: const Value(2),
              longestStreak: const Value(5),
              lastLearningDate: Value(DateTime(2026, 8, 10)),
            ),
          );
      await database
          .into(database.learningStreaks)
          .insert(
            LearningStreaksCompanion.insert(
              singletonId: const Value(2),
              currentStreak: const Value(1),
              longestStreak: const Value(3),
              lastLearningDate: Value(DateTime(2026, 8, 12)),
            ),
          );
      expect((await learning.streak()).current, 1);
      expect((await learning.streak()).longest, 5);
      await learning.recordMeaningfulActivity(DateTime(2026, 8, 13, 12));
      expect((await learning.streak()).current, 2);
      expect((await learning.streak()).longest, 5);
      expect(
        await database.select(database.learningStreaks).get(),
        hasLength(1),
      );
    },
  );

  test('quiz scoring exposes mistakes and aggregates real progress', () async {
    final questions = await learning.quizQuestions(count: 2);
    final result = const QuizEngine().score(
      questions: questions,
      answers: [
        QuizAnswer(
          questionId: questions.first.id,
          selectedOptionIds: questions.first.correctOptionIds,
        ),
      ],
    );
    expect(result.correctAnswers, 1);
    expect(result.mistakes, hasLength(1));
    await learning.saveQuizResult(
      result,
      completedAt: DateTime.utc(2026, 8, 12),
    );
    final dashboard = await learning.dashboard();
    expect(dashboard.quizAccuracy, 0.5);
    expect(dashboard.streak.current, 1);
  });

  test(
    'failed content refresh preserves local reference and user data',
    () async {
      final saved = LocalSavedContentRepository(database, sync);
      await saved.save('term-hypertension', MedicalContentType.term);
      final service = TerminologyContentUpdateService(
        _FailingContentProvider(),
        TerminologySeedImporter(database),
      );
      final result = await service.refresh(installedVersion: '2026.08.2');
      expect(result.updated, isFalse);
      expect(result.preservedLocalContent, isTrue);
      expect(
        await LocalTerminologyRepository(
          database,
        ).termById('term-hypertension'),
        isNotNull,
      );
      expect(
        await saved.isSaved('term-hypertension', MedicalContentType.term),
        isTrue,
      );
    },
  );

  test(
    'import is idempotent and dry run does not mutate installed version',
    () async {
      final importer = TerminologySeedImporter(database);
      final unchanged = await importer.importJson(rawDataset);
      expect(unchanged.changed, isFalse);
      final dryRun = await importer.importJson(
        rawDataset.replaceFirst('2026.08.3', '2026.09.0'),
        dryRun: true,
      );
      expect(dryRun.changed, isTrue);
      final installed = await database
          .select(database.contentVersions)
          .getSingle();
      expect(installed.datasetVersion, '2026.08.3');
    },
  );

  test(
    'a published reference refresh preserves bookmarks and learning progress',
    () async {
      final saved = LocalSavedContentRepository(database, sync);
      await saved.save('term-hypertension', MedicalContentType.term);
      final now = DateTime.utc(2026, 10, 12);
      await learning.saveLessonProgress(
        LessonProgress(
          lessonId: 'lesson-intro-morphology',
          lastSectionIndex: 2,
          completionPercentage: 1,
          startedAt: now,
          updatedAt: now,
          completedAt: now,
          reviewRequired: false,
        ),
      );
      final document = jsonDecode(rawDataset) as Map<String, dynamic>;
      document['dataset_version'] = 'release-refresh-v2';
      final result = await TerminologyContentUpdateService(
        _FixtureContentProvider(jsonEncode(document)),
        TerminologySeedImporter(database),
      ).refresh();
      expect(result.updated, isTrue);
      final bootstrap = await TerminologySeedImporter(database).importBundled();
      expect(bootstrap.changed, isFalse);
      expect(
        (await database.select(database.contentVersions).getSingle())
            .datasetVersion,
        'release-refresh-v2',
      );
      expect(
        await saved.isSaved('term-hypertension', MedicalContentType.term),
        isTrue,
      );
      expect((await learning.dashboard()).lessonsCompleted, 1);
      expect(
        await LocalTerminologyRepository(
          database,
        ).termById('term-hypertension'),
        isNotNull,
      );
    },
  );

  test(
    'production refuses an unapproved reference download without changing local data',
    () async {
      final document = jsonDecode(rawDataset) as Map<String, dynamic>;
      document['dataset_version'] = 'unapproved-v2';
      document['production_approved'] = false;
      final result = await TerminologyContentUpdateService(
        _FixtureContentProvider(jsonEncode(document)),
        TerminologySeedImporter(database),
        requireProductionApproval: true,
      ).refresh();
      expect(result.safeErrorCode, 'reference_release_not_approved');
      expect(result.updated, isFalse);
      expect(
        (await database.select(database.contentVersions).getSingle())
            .datasetVersion,
        '2026.08.3',
      );
    },
  );
}

class _FixtureContentProvider implements TerminologyContentProvider {
  const _FixtureContentProvider(this.dataset);
  final String dataset;

  @override
  Future<String> downloadDataset({required String? installedVersion}) async =>
      dataset;
}

class _FailingContentProvider implements TerminologyContentProvider {
  @override
  Future<String> downloadDataset({required String? installedVersion}) =>
      throw const SocketException('offline');
}
