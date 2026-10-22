import 'dart:math';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../database/app_database.dart';
import '../network/api_client.dart';

// Outbox metadata only. It is removed before requests reach the strict API schemas.
const syncDependenciesKey = '_sync_dependencies';
const syncCancelledKey = '_sync_cancelled';

abstract interface class SyncTransport {
  Future<SyncReceipt> send(SyncOperation operation);
}

/// Upload preferences never prevent a user-requested deletion of an old backup.
class DeletionOnlySyncTransport implements SyncTransport {
  const DeletionOnlySyncTransport(this.delegate);
  final SyncTransport delegate;
  bool allows(SyncOperation operation) =>
      operation.entityType == 'user_medication' &&
      operation.operationType == 'delete';
  @override
  Future<SyncReceipt> send(SyncOperation operation) => delegate.send(operation);
}

class SyncReceipt {
  const SyncReceipt({required this.serverRevision});
  final String serverRevision;
}

class SyncCoordinator {
  factory SyncCoordinator({
    required AppDatabase database,
    required SyncTransport transport,
    Uuid uuid = const Uuid(),
    DateTime Function()? clock,
  }) => SyncCoordinator._(database, transport, uuid, clock ?? _utcNow);

  SyncCoordinator._(this._database, this._transport, this._uuid, this._clock);

  final AppDatabase _database;
  final SyncTransport _transport;
  final Uuid _uuid;
  final DateTime Function() _clock;
  bool _running = false;
  bool _disposed = false;

  void dispose() => _disposed = true;

  static DateTime _utcNow() => DateTime.now().toUtc();

  Future<void> enqueue({
    required String entityType,
    required String entityId,
    required String operationType,
    required String payload,
    bool tombstone = false,
  }) async {
    final now = _clock();
    final operationId = _uuid.v4();
    await _database.enqueue(
      SyncOperationsCompanion.insert(
        id: operationId,
        entityType: entityType,
        entityId: entityId,
        operationType: operationType,
        payload: payload,
        idempotencyKey: _uuid.v4(),
        createdAt: now,
        updatedAt: now,
        tombstone: Value(tombstone),
      ),
    );
  }

  Future<void> synchronize() async {
    if (_running || _disposed || _transport is DisabledSyncTransport) return;
    _running = true;
    try {
      while (!_disposed) {
        // A prerequisite may be newer than dozens of waiting dependants. Include
        // the complete due queue so a batch boundary cannot starve it forever.
        final operations = await _database.pendingOperations(limit: null);
        if (operations.isEmpty) break;
        var batchFailed = false;
        var attempted = false;
        for (final queued in operations) {
          if (_disposed) return;
          // A local mutation can remove or amend a queued operation while an
          // earlier network request is in flight. Never send its stale snapshot.
          final operation = await (_database.select(
            _database.syncOperations,
          )..where((row) => row.id.equals(queued.id))).getSingleOrNull();
          if (operation == null ||
              !['pending', 'failed'].contains(operation.syncState) ||
              !await _dependenciesSatisfied(operation)) {
            continue;
          }
          if ((jsonDecode(operation.payload) as Map)[syncCancelledKey] ==
              true) {
            await _database.markSynced(operation.id);
            attempted = true;
            continue;
          }
          final transport = _transport;
          if (transport is DeletionOnlySyncTransport &&
              !transport.allows(operation)) {
            continue;
          }
          attempted = true;
          await _database.markSyncing(operation.id);
          try {
            final receipt = await _transport.send(operation);
            if (_disposed) return;
            await _database.markSynced(
              operation.id,
              serverRevision: receipt.serverRevision,
            );
          } catch (_) {
            if (_disposed) return;
            batchFailed = true;
            final retry = operation.retryCount + 1;
            final seconds = min(3600, pow(2, retry).toInt());
            await _database.markFailed(
              operation.id,
              retryCount: retry,
              safeErrorCode: 'transport_failure',
              nextAttemptAt: _clock().add(Duration(seconds: seconds)),
            );
          }
        }
        // Drain healthy batches, but back off after a transport failure.
        if (batchFailed || !attempted) break;
      }
    } on Object {
      if (!_disposed) rethrow;
    } finally {
      _running = false;
    }
  }

  Future<bool> _dependenciesSatisfied(SyncOperation operation) async {
    final payload = (jsonDecode(operation.payload) as Map)
        .cast<String, Object?>();
    final dependencies = (payload[syncDependenciesKey] as List?)
        ?.cast<String>()
        .toSet();
    if (dependencies == null || dependencies.isEmpty) return true;
    final rows = await (_database.select(
      _database.syncOperations,
    )..where((row) => row.id.isIn(dependencies))).get();
    return rows.length == dependencies.length &&
        rows.every((row) => row.syncState == 'synced');
  }
}

class DisabledSyncTransport implements SyncTransport {
  const DisabledSyncTransport();

  @override
  Future<SyncReceipt> send(SyncOperation operation) {
    throw UnsupportedError('Remote synchronization is not configured.');
  }
}

class ApiSyncTransport implements SyncTransport {
  const ApiSyncTransport(this._api);
  final ApiClient _api;

  @override
  Future<SyncReceipt> send(SyncOperation operation) async {
    final payload =
        (jsonDecode(operation.payload) as Map).cast<String, Object?>()
          ..remove(syncDependenciesKey);
    final response = switch ((operation.entityType, operation.operationType)) {
      ('saved_item', 'create') => await _api.postJson(
        'me/saved',
        data: payload,
        idempotencyKey: operation.idempotencyKey,
      ),
      ('saved_item', 'delete') => await _deleteSaved(operation),
      ('lesson_progress', _) => await _api.putJson(
        'me/lesson-progress/${operation.entityId}',
        data: payload,
        idempotencyKey: operation.idempotencyKey,
      ),
      ('learning_progress', _) => await _api.putJson(
        'me/learning-progress',
        data: payload,
        idempotencyKey: operation.idempotencyKey,
      ),
      ('quiz_attempt', _) => await _api.postJson(
        'me/quiz-attempts',
        data: payload,
        idempotencyKey: operation.idempotencyKey,
      ),
      ('flashcard_review', _) => await _api.postJson(
        'me/flashcard-reviews',
        data: payload,
        idempotencyKey: operation.idempotencyKey,
      ),
      ('content_report', _) => await _api.postJson(
        'reports/content',
        data: payload,
        idempotencyKey: operation.idempotencyKey,
      ),
      ('prescription', 'upsert') => await _upsertPrescription(
        operation,
        payload,
      ),
      ('prescription', 'delete') => await _deletePrescription(operation),
      ('barcode_scan', 'create') => await _api.postJson(
        'prescriptions/barcode-scans',
        data: payload,
        idempotencyKey: operation.idempotencyKey,
      ),
      ('medication_plan', 'upsert') => await _api.putJson(
        'medications/plans/${operation.entityId}',
        data: payload,
        idempotencyKey: operation.idempotencyKey,
      ),
      ('medication_plan', 'delete') => await _deleteMedicationPlan(operation),
      ('user_medication', 'delete') => await _deleteMedication(operation),
      ('dose_event', 'upsert') => await _api.putJson(
        'medications/dose-events/${operation.entityId}',
        data: payload,
        idempotencyKey: operation.idempotencyKey,
      ),
      _ => throw UnsupportedError(
        'Unsupported sync entity: ${operation.entityType}',
      ),
    };
    return SyncReceipt(
      serverRevision:
          response['updated_at']?.toString() ??
          response['id']?.toString() ??
          DateTime.now().toUtc().toIso8601String(),
    );
  }

  Future<Map<String, Object?>> _deleteSaved(SyncOperation operation) async {
    await _api.delete(
      'me/saved/${operation.entityId}',
      idempotencyKey: operation.idempotencyKey,
    );
    return {'id': operation.entityId};
  }

  Future<Map<String, Object?>> _upsertPrescription(
    SyncOperation operation,
    Map<String, Object?> payload,
  ) => _api.postJson(
    'prescriptions',
    data: payload,
    idempotencyKey: operation.idempotencyKey,
  );

  Future<Map<String, Object?>> _deletePrescription(
    SyncOperation operation,
  ) async {
    await _api.delete(
      'prescriptions/${operation.entityId}',
      idempotencyKey: operation.idempotencyKey,
    );
    return {'id': operation.entityId};
  }

  Future<Map<String, Object?>> _deleteMedication(
    SyncOperation operation,
  ) async {
    await _api.delete(
      'medications/saved/${operation.entityId}',
      idempotencyKey: operation.idempotencyKey,
    );
    return {'id': operation.entityId};
  }

  Future<Map<String, Object?>> _deleteMedicationPlan(
    SyncOperation operation,
  ) async {
    await _api.delete(
      'medications/plans/${operation.entityId}',
      idempotencyKey: operation.idempotencyKey,
    );
    return {'id': operation.entityId};
  }
}
