import '../domain/medication_models.dart';

class DoseConflictResolver {
  const DoseConflictResolver();

  /// Deterministic last-user-action-wins resolution. Revision is preferred;
  /// timestamps break ties; IDs provide a final stable tie-break. The caller
  /// keeps all revisions so corrections are never silently erased.
  DoseEvent resolve(DoseEvent local, DoseEvent remote) {
    if (local.logicalDoseId != remote.logicalDoseId) {
      throw ArgumentError('Dose events refer to different logical doses.');
    }
    if (local.revision != remote.revision) {
      return local.revision > remote.revision ? local : remote;
    }
    final time = local.recordedAt.compareTo(remote.recordedAt);
    if (time != 0) return time > 0 ? local : remote;
    return local.id.compareTo(remote.id) >= 0 ? local : remote;
  }
}
