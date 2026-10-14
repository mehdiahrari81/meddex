class TimezoneReviewResult {
  const TimezoneReviewResult({
    required this.currentTimezone,
    required this.reviewRequired,
    this.previousTimezone,
  });

  final String? previousTimezone;
  final String currentTimezone;
  final bool reviewRequired;
}

abstract interface class TimezoneStore {
  Future<String?> readLastTimezone();
  Future<void> writeLastTimezone(String timezone);
}

class TimezoneMonitor {
  const TimezoneMonitor(this._store);
  final TimezoneStore _store;

  Future<TimezoneReviewResult> check(String currentTimezone) async {
    final previous = await _store.readLastTimezone();
    await _store.writeLastTimezone(currentTimezone);
    return TimezoneReviewResult(
      previousTimezone: previous,
      currentTimezone: currentTimezone,
      reviewRequired: previous != null && previous != currentTimezone,
    );
  }
}
