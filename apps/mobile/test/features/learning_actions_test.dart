import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediexplain/design_system/widgets/states.dart';
import 'package:mediexplain/domain/models/source_provenance.dart';
import 'package:mediexplain/features/learning/application/learning_providers.dart';
import 'package:mediexplain/features/learning/domain/learning_models.dart';
import 'package:mediexplain/features/learning/presentation/flashcard_session_screen.dart';
import 'package:mediexplain/features/learning/presentation/lesson_screens.dart';
import 'package:mediexplain/features/learning/presentation/quiz_screens.dart';
import 'package:mediexplain/features/terminology/domain/medical_term.dart';
import 'package:mediexplain/l10n/app_localizations.dart';

final _source = SourceProvenance(
  provider: 'Engineering fixture',
  sourceTitle: 'Fixture',
  sourceIdentifier: 'qa',
  retrievedAt: DateTime.utc(2026),
  locale: 'en',
  version: '1',
  reviewStatus: ReviewStatus.unreviewed,
  contentType: 'fixture',
);
final _card = Flashcard(
  id: 'card',
  type: FlashcardType.termToMeaning,
  front: 'Fixture front',
  back: 'Fixture back',
  categoryId: 'general',
  difficulty: LearningDifficulty.beginner,
  source: _source,
);
final _question = QuizQuestion(
  id: 'question',
  type: QuizQuestionType.multipleChoice,
  prompt: 'Fixture question',
  options: const [QuizOption(id: 'a', text: 'Fixture answer')],
  correctOptionIds: const {'a'},
  explanation: 'Fixture explanation',
  categoryId: 'general',
  difficulty: LearningDifficulty.beginner,
  source: _source,
);
LearningLesson _lesson({bool empty = false}) => LearningLesson(
  id: 'lesson',
  title: 'Fixture lesson',
  description: 'Description',
  categoryId: 'general',
  difficulty: LearningDifficulty.beginner,
  estimatedMinutes: 2,
  objectives: const [],
  sections: empty
      ? const []
      : const [
          LessonSection(
            id: '1',
            title: 'First section',
            content: 'First content',
            type: LessonSectionType.text,
            position: 0,
          ),
          LessonSection(
            id: '2',
            title: 'Second section',
            content: 'Second content',
            type: LessonSectionType.text,
            position: 1,
          ),
        ],
  reviewQuestionIds: const [],
  sources: [_source],
  reviewStatus: ContentReviewStatus.reviewed,
  version: 1,
);

class _Learning implements LearningRepository {
  bool failLoad = false;
  bool failSave = false;
  bool empty = false;
  int writes = 0;
  int loads = 0;
  Completer<void>? loadPending;
  Completer<void>? pending;
  LessonProgress? progress;
  QuizResult? quizResult;
  @override
  Future<LearningLesson?> lessonById(String id) async {
    if (failLoad) throw StateError('Synthetic read failure');
    return _lesson(empty: empty);
  }

  @override
  Future<LessonProgress?> lessonProgress(String id) async => progress;
  Future<void> _save() async {
    writes++;
    if (failSave) throw StateError('Synthetic write failure');
    await pending?.future;
  }

  @override
  Future<void> saveLessonProgress(LessonProgress value) async {
    await _save();
    progress = value;
  }

  @override
  Future<List<Flashcard>> dueFlashcards({int limit = 20}) async => [_card];
  @override
  Future<FlashcardSchedule?> flashcardSchedule(String id) async => null;
  @override
  Future<void> saveFlashcardReview(FlashcardSchedule value) => _save();
  @override
  Future<List<QuizQuestion>> quizQuestions({
    int count = 4,
    LearningDifficulty? difficulty,
    String? categoryId,
  }) async {
    loads++;
    await loadPending?.future;
    if (failLoad) throw StateError('Synthetic read failure');
    return [_question];
  }

  @override
  Future<void> saveQuizResult(
    QuizResult value, {
    required DateTime completedAt,
  }) async {
    await _save();
    quizResult = value;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _mount(
  WidgetTester tester,
  _Learning repository,
  Widget screen,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [learningRepositoryProvider.overrideWithValue(repository)],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: screen,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

const _saveFailure = 'Progress could not be saved. Try again.';
void main() {
  testWidgets('rapid quiz start taps open one session', (tester) async {
    final repo = _Learning()..loadPending = Completer<void>();
    await _mount(tester, repo, const QuizSetupScreen());
    await tester.tap(find.text('Start quiz'));
    await tester.tap(find.text('Start quiz'));
    await tester.pump();
    expect(repo.loads, 1);
    repo.loadPending!.complete();
    await tester.pumpAndSettle();
    expect(find.byType(QuizSessionScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('lesson read failure offers a working retry', (tester) async {
    final repo = _Learning()..failLoad = true;
    await _mount(tester, repo, const LessonDetailScreen(lessonId: 'lesson'));
    expect(
      find.text('This lesson could not be loaded. Try again.'),
      findsOneWidget,
    );
    repo.failLoad = false;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text('First section'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'empty lesson with old progress shows empty state instead of spinning',
    (tester) async {
      final repo = _Learning()
        ..empty = true
        ..progress = LessonProgress(
          lessonId: 'lesson',
          lastSectionIndex: 1,
          completionPercentage: 0.5,
          startedAt: DateTime.utc(2026),
          updatedAt: DateTime.utc(2026),
          reviewRequired: false,
        );
      await _mount(tester, repo, const LessonDetailScreen(lessonId: 'lesson'));
      expect(find.byType(AppEmptyState), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'lesson save retries, blocks duplicate taps, and resumes the next section',
    (tester) async {
      final repo = _Learning()..failSave = true;
      await _mount(tester, repo, const LessonDetailScreen(lessonId: 'lesson'));
      await tester.tap(find.text('Next section'));
      await tester.pumpAndSettle();
      expect(find.text(_saveFailure), findsOneWidget);
      expect(find.text('First section'), findsOneWidget);
      repo
        ..failSave = false
        ..pending = Completer<void>();
      await tester.tap(find.text('Next section'));
      await tester.tap(find.text('Next section'));
      await tester.pump();
      expect(repo.writes, 2);
      repo.pending!.complete();
      await tester.pumpAndSettle();
      expect(find.text('Second section'), findsOneWidget);
      expect(repo.progress?.lastSectionIndex, 1);
      await tester.pumpWidget(const SizedBox.shrink());
      await _mount(tester, repo, const LessonDetailScreen(lessonId: 'lesson'));
      expect(find.text('Second section'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('quiz question load failure can be retried', (tester) async {
    final repo = _Learning()..failLoad = true;
    await _mount(tester, repo, const QuizSetupScreen());
    await tester.tap(find.text('Start quiz'));
    await tester.pumpAndSettle();
    expect(
      find.text('This lesson could not be loaded. Try again.'),
      findsOneWidget,
    );
    repo.failLoad = false;
    await tester.tap(find.text('Start quiz'));
    await tester.pumpAndSettle();
    expect(find.text('Fixture question'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('quiz final save retries without duplicates or lost answers', (
    tester,
  ) async {
    final repo = _Learning()..failSave = true;
    await _mount(tester, repo, QuizSessionScreen(questions: [_question]));
    await tester.tap(find.text('Fixture answer'));
    await tester.pumpAndSettle();
    final submit = find.byType(FilledButton);
    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(find.text(_saveFailure), findsOneWidget);
    repo
      ..failSave = false
      ..pending = Completer<void>();
    await tester.tap(submit);
    await tester.tap(submit);
    await tester.pump();
    expect(repo.writes, 2);
    repo.pending!.complete();
    await tester.pumpAndSettle();
    expect(find.byType(QuizResultsScreen), findsOneWidget);
    expect(repo.quizResult?.correctAnswers, 1);
    expect(repo.quizResult?.totalQuestions, 1);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'flashcard save failure preserves card and retry is single-flight',
    (tester) async {
      final repo = _Learning()..failSave = true;
      await _mount(tester, repo, const FlashcardSessionScreen());
      await tester.tap(find.text('Reveal answer'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Easy'));
      await tester.pumpAndSettle();
      expect(find.text(_saveFailure), findsOneWidget);
      expect(find.text('Fixture back'), findsOneWidget);
      repo
        ..failSave = false
        ..pending = Completer<void>();
      await tester.tap(find.text('Easy'));
      await tester.tap(find.text('Easy'));
      await tester.pump();
      expect(repo.writes, 2);
      repo.pending!.complete();
      await tester.pumpAndSettle();
      expect(find.text('Fixture back'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
