import '../domain/learning_models.dart';

class SpacedRepetitionScheduler {
  const SpacedRepetitionScheduler();

  FlashcardSchedule review({
    required FlashcardSchedule current,
    required ReviewPerformance performance,
    required DateTime reviewedAt,
  }) {
    final utcReview = reviewedAt.toUtc();
    final quality = switch (performance) {
      ReviewPerformance.again => 1,
      ReviewPerformance.hard => 3,
      ReviewPerformance.good => 4,
      ReviewPerformance.easy => 5,
    };
    if (quality < 3) {
      return FlashcardSchedule(
        flashcardId: current.flashcardId,
        repetitions: 0,
        easeFactor: (current.easeFactor - 0.2).clamp(1.3, 3.0),
        intervalDays: 1,
        lastReviewedAt: utcReview,
        nextReviewAt: utcReview.add(const Duration(days: 1)),
        lastPerformance: performance,
      );
    }
    final repetitions = current.repetitions + 1;
    final interval = switch (repetitions) {
      1 => 1,
      2 => performance == ReviewPerformance.hard ? 3 : 6,
      _ =>
        (current.intervalDays *
                current.easeFactor *
                (performance == ReviewPerformance.hard ? 0.8 : 1))
            .round()
            .clamp(current.intervalDays + 1, 365),
    };
    final easeDelta = 0.1 - ((5 - quality) * (0.08 + (5 - quality) * 0.02));
    final ease = (current.easeFactor + easeDelta).clamp(1.3, 3.0);
    return FlashcardSchedule(
      flashcardId: current.flashcardId,
      repetitions: repetitions,
      easeFactor: ease,
      intervalDays: interval,
      lastReviewedAt: utcReview,
      nextReviewAt: utcReview.add(Duration(days: interval)),
      lastPerformance: performance,
    );
  }

  FlashcardSchedule initial(String flashcardId, DateTime now) =>
      FlashcardSchedule(
        flashcardId: flashcardId,
        repetitions: 0,
        easeFactor: 2.5,
        intervalDays: 0,
        nextReviewAt: now.toUtc(),
      );
}
