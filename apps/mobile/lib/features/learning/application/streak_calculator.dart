import '../domain/learning_models.dart';

class StreakCalculator {
  const StreakCalculator();

  LearningStreak record(LearningStreak current, DateTime occurredAt) {
    final date = _dateOnly(occurredAt);
    final previous = current.lastLearningDate == null
        ? null
        : _dateOnly(current.lastLearningDate!);
    if (previous == date) return current;
    final yesterday = date.subtract(const Duration(days: 1));
    final nextCurrent = previous == yesterday ? current.current + 1 : 1;
    return LearningStreak(
      current: nextCurrent,
      longest: nextCurrent > current.longest ? nextCurrent : current.longest,
      lastLearningDate: date,
    );
  }

  DateTime _dateOnly(DateTime value) {
    final local = value.toLocal();
    return DateTime(local.year, local.month, local.day);
  }
}
