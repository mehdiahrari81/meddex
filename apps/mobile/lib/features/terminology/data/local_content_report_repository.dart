import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/sync/sync_coordinator.dart';
import '../domain/content_report.dart';

class LocalContentReportRepository implements ContentReportRepository {
  const LocalContentReportRepository(this._database, this._sync);

  final AppDatabase _database;
  final SyncCoordinator _sync;

  @override
  Future<void> submit({
    required String recordId,
    required ContentReportReason reason,
    required String locale,
    required String appVersion,
    String? note,
  }) async {
    final id = const Uuid().v4();
    final now = DateTime.now().toUtc();
    final cleanNote = note?.trim();
    await _database
        .into(_database.contentReports)
        .insert(
          ContentReportsCompanion.insert(
            id: id,
            recordId: recordId,
            reason: reason.name,
            note: Value(
              cleanNote == null || cleanNote.isEmpty ? null : cleanNote,
            ),
            locale: locale,
            appVersion: appVersion,
            createdAt: now,
          ),
        );
    await _sync.enqueue(
      entityType: 'content_report',
      entityId: id,
      operationType: 'create',
      payload: jsonEncode({
        'id': id,
        'record_id': recordId,
        'reason': reason.name,
        'note': cleanNote,
        'locale': locale,
        'app_version': appVersion,
      }),
    );
  }
}
