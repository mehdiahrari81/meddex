import '../domain/learning_models.dart';

class StreakCalculator {
  const StreakCalculator();

  LearningStreak currentOn(LearningStreak stored, DateTime now) {
    final previous = stored.lastLearningDate;
    final gap = previous == null
        ? null
        : _calendarDay(now).difference(_calendarDay(previous)).inDays;
    return LearningStreak(
      current: gap == 0 || gap == 1 ? stored.current : 0,
      longest: stored.longest,
      lastLearningDate: previous,
    );
  }

  LearningStreak record(LearningStreak current, DateTime occurredAt) {
    final date = _dateOnly(occurredAt);
    final previous = current.lastLearningDate == null
        ? null
        : _dateOnly(current.lastLearningDate!);
    if (previous == date) return current;
    if (previous != null && date.isBefore(previous)) return current;
    final consecutive =
        previous != null &&
        _calendarDay(date).difference(_calendarDay(previous)).inDays == 1;
    final nextCurrent = consecutive ? current.current + 1 : 1;
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

  DateTime _calendarDay(DateTime value) {
    final local = value.toLocal();
    return DateTime.utc(local.year, local.month, local.day);
  }
}
