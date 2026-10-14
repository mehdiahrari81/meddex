abstract interface class Analytics {
  Future<void> track(
    String event, {
    Map<String, Object?> properties = const {},
  });
}

class NoOpAnalytics implements Analytics {
  const NoOpAnalytics();

  @override
  Future<void> track(
    String event, {
    Map<String, Object?> properties = const {},
  }) async {}
}

abstract interface class CrashReporter {
  Future<void> record(Object error, StackTrace stackTrace);
}

class NoOpCrashReporter implements CrashReporter {
  const NoOpCrashReporter();

  @override
  Future<void> record(Object error, StackTrace stackTrace) async {}
}
