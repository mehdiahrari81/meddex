import 'medication_models.dart';

/// Corrections remain in the audit log; each dose has one current display state.
List<DoseEvent> currentDoseEvents(Iterable<DoseEvent> history) {
  final latest = <String, DoseEvent>{};
  final order = <String, int>{};
  for (final event in history) {
    order[event.id] = order.length;
    final previous = latest[event.logicalDoseId];
    if (previous == null ||
        event.revision > previous.revision ||
        (event.revision == previous.revision &&
            event.recordedAt.isAfter(previous.recordedAt))) {
      latest[event.logicalDoseId] = event;
    }
  }
  return latest.values.toList()..sort((a, b) {
    final date = b.recordedAt.compareTo(a.recordedAt);
    return date != 0 ? date : order[a.id]!.compareTo(order[b.id]!);
  });
}

bool doseWasRecorded(DoseAction action) =>
    action == DoseAction.taken ||
    action == DoseAction.skipped ||
    action == DoseAction.late;
