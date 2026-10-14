import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/sync/sync_coordinator.dart';
import '../../terminology/domain/medical_term.dart';
import '../domain/saved_item.dart';

class LocalSavedContentRepository implements SavedContentRepository {
  const LocalSavedContentRepository(this._database, this._sync);
  final AppDatabase _database;
  final SyncCoordinator _sync;

  @override
  Future<bool> isSaved(String contentId, MedicalContentType type) async =>
      await (_database.select(_database.savedContentItems)..where(
            (row) =>
                row.contentId.equals(contentId) &
                row.contentType.equals(type.name),
          ))
          .getSingleOrNull() !=
      null;

  @override
  Future<void> save(String contentId, MedicalContentType type) async {
    if (await isSaved(contentId, type)) return;
    final id = const Uuid().v4();
    final now = DateTime.now().toUtc();
    await _database
        .into(_database.savedContentItems)
        .insert(
          SavedContentItemsCompanion.insert(
            id: id,
            contentId: contentId,
            contentType: type.name,
            savedAt: now,
          ),
        );
    await _sync.enqueue(
      entityType: 'saved_item',
      entityId: id,
      operationType: 'create',
      payload: jsonEncode({
        'id': id,
        'content_id': contentId,
        'content_type': type.name,
      }),
    );
  }

  @override
  Future<void> unsave(String contentId, MedicalContentType type) async {
    final existing =
        await (_database.select(_database.savedContentItems)..where(
              (row) =>
                  row.contentId.equals(contentId) &
                  row.contentType.equals(type.name),
            ))
            .getSingleOrNull();
    if (existing == null) return;
    await (_database.delete(
      _database.savedContentItems,
    )..where((row) => row.id.equals(existing.id))).go();
    await _sync.enqueue(
      entityType: 'saved_item',
      entityId: existing.id,
      operationType: 'delete',
      payload: jsonEncode({
        'id': existing.id,
        'content_id': contentId,
        'content_type': type.name,
      }),
      tombstone: true,
    );
  }

  @override
  Stream<List<SavedItem>> watch({MedicalContentType? type}) {
    final query = _database.select(_database.savedContentItems)
      ..orderBy([(row) => OrderingTerm.desc(row.savedAt)]);
    if (type != null) query.where((row) => row.contentType.equals(type.name));
    return query.watch().map(
      (rows) => rows
          .map(
            (row) => SavedItem(
              id: row.id,
              contentId: row.contentId,
              contentType: MedicalContentType.values.byName(row.contentType),
              savedAt: row.savedAt,
              syncState: row.syncState,
            ),
          )
          .toList(growable: false),
    );
  }
}
