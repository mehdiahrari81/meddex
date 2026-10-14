import '../domain/medication_models.dart';

class AdherenceCalculator {
  const AdherenceCalculator();

  AdherenceSummary calculate({
    required List<ScheduledDose> scheduled,
    required List<DoseEvent> events,
  }) {
    final latest = <String, DoseEvent>{};
    for (final event in events) {
      final current = latest[event.logicalDoseId];
      if (current == null ||
          event.revision > current.revision ||
          (event.revision == current.revision &&
              event.recordedAt.isAfter(current.recordedAt))) {
        latest[event.logicalDoseId] = event;
      }
    }
    var taken = 0;
    var skipped = 0;
    var unrecorded = 0;
    for (final dose in scheduled) {
      switch (latest[dose.logicalDoseId]?.action ?? DoseAction.notRecorded) {
        case DoseAction.taken || DoseAction.late:
          taken++;
        case DoseAction.skipped:
          skipped++;
        case DoseAction.notRecorded:
          unrecorded++;
      }
    }
    final manualCount = events
        .where((event) => event.source == DoseEventSource.manualEntry)
        .length;
    return AdherenceSummary(
      scheduledCount: scheduled.length,
      takenCount: taken,
      skippedCount: skipped,
      unrecordedCount: unrecorded,
      manualCount: manualCount,
    );
  }
}
