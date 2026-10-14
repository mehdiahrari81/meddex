import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../domain/search_history.dart';

class LocalSearchHistoryRepository implements SearchHistoryRepository {
  const LocalSearchHistoryRepository(this._database);
  final AppDatabase _database;

  @override
  Future<void> clear() => _database.delete(_database.searchHistoryItems).go();

  @override
  Future<List<SearchHistoryEntry>> recent({int limit = 20}) async {
    final rows =
        await (_database.select(_database.searchHistoryItems)
              ..orderBy([(row) => OrderingTerm.desc(row.searchedAt)])
              ..limit(limit.clamp(1, 100)))
            .get();
    return rows
        .map(
          (row) => SearchHistoryEntry(
            id: row.id,
            query: row.query,
            selectedTermId: row.selectedTermId,
            searchedAt: row.searchedAt,
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<void> record(String query, {String? selectedTermId}) => _database
      .into(_database.searchHistoryItems)
      .insert(
        SearchHistoryItemsCompanion.insert(
          id: const Uuid().v4(),
          query: query.trim(),
          selectedTermId: Value(selectedTermId),
          searchedAt: DateTime.now().toUtc(),
        ),
      );

  @override
  Future<void> remove(String id) => (_database.delete(
    _database.searchHistoryItems,
  )..where((row) => row.id.equals(id))).go();
}
