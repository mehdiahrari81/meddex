import 'package:drift/drift.dart';

/// A server-verified medication snapshot retained for offline reading. The JSON
/// includes facts and provenance; it is never treated as a prescription.
class CachedMedicationIdentities extends Table {
  TextColumn get id => text()();
  TextColumn get payloadJson => text()();
  TextColumn get cacheState => text()();
  DateTimeColumn get sourceFetchedAt => dateTime()();
  DateTimeColumn get cachedAt => dateTime()();
  DateTimeColumn get lastOpenedAt => dateTime().nullable()();
  BoolColumn get saved => boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class MedicationResolutionHistory extends Table {
  TextColumn get id => text()();
  TextColumn get normalizedQuery => text()();
  TextColumn get state => text()();
  TextColumn get candidateEvidenceJson => text()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
