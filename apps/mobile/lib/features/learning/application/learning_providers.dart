import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_provider.dart';
import '../../../core/sync/sync_provider.dart';
import '../../../app/config/app_config.dart';
import '../../auth/application/auth_controller.dart';
import '../data/local_learning_repository.dart';
import '../domain/learning_models.dart';

final learningRepositoryProvider = Provider<LearningRepository>(
  (ref) => LocalLearningRepository(
    ref.watch(databaseProvider),
    ref.watch(syncCoordinatorProvider),
    includeReviewedContent:
        ref.watch(appConfigProvider).environment != AppEnvironment.production,
  ),
);
final lessonsProvider = FutureProvider<List<LearningLesson>>(
  (ref) => ref.watch(learningRepositoryProvider).lessons(),
);
final learningDashboardProvider = FutureProvider<LearningDashboard>(
  (ref) => ref.watch(learningRepositoryProvider).dashboard(),
);
final dueFlashcardsProvider = FutureProvider<List<Flashcard>>(
  (ref) => ref.watch(learningRepositoryProvider).dueFlashcards(),
);
