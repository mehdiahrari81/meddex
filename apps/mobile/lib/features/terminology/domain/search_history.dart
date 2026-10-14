class SearchHistoryEntry {
  const SearchHistoryEntry({
    required this.id,
    required this.query,
    required this.searchedAt,
    this.selectedTermId,
  });
  final String id;
  final String query;
  final String? selectedTermId;
  final DateTime searchedAt;
}

abstract interface class SearchHistoryRepository {
  Future<List<SearchHistoryEntry>> recent({int limit = 20});
  Future<void> record(String query, {String? selectedTermId});
  Future<void> remove(String id);
  Future<void> clear();
}
