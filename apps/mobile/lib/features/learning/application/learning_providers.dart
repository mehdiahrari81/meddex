import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_provider.dart';
import '../../../core/sync/sync_provider.dart';
import '../../../app/config/app_config.dart';
import '../../auth/application/auth_controller.dart';
import '../data/local_learning_repository.dart';
import '../domain/learning_models.dart';
import 'daily_term.dart';

final learningRepositoryProvider = Provider<LearningRepository>(
  (ref) => LocalLearningRepository(
    ref.watch(databaseProvider),
    ref.watch(syncCoordinatorProvider),
    clock: ref.watch(learningClockProvider),
    includeReviewedContent:
        ref.watch(appConfigProvider).environment != AppEnvironment.production,
  ),
);
final _learningChangesProvider = StreamProvider((ref) {
  final db = ref.watch(databaseProvider);
  return db
      .customSelect(
        'SELECT 1',
        readsFrom: {
          db.learningLessons,
          db.lessonProgressEntries,
          db.flashcards,
          db.flashcardSchedules,
          db.quizAttempts,
          db.learningStreaks,
          db.contentSources,
        },
      )
      .watch();
});
final lessonsProvider = FutureProvider<List<LearningLesson>>((ref) {
  ref.watch(_learningChangesProvider);
  return ref.watch(learningRepositoryProvider).lessons();
});
final learningDashboardProvider = FutureProvider<LearningDashboard>((ref) {
  ref.watch(_learningChangesProvider);
  ref.watch(localLearningDayProvider);
  return ref.watch(learningRepositoryProvider).dashboard();
});
final dueFlashcardsProvider = FutureProvider.autoDispose<List<Flashcard>>(
  (ref) => ref.watch(learningRepositoryProvider).dueFlashcards(),
);
