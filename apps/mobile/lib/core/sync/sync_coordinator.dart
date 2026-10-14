import 'dart:math';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../database/app_database.dart';
import '../network/api_client.dart';

abstract interface class SyncTransport {
  Future<SyncReceipt> send(SyncOperation operation);
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
        final operations = await _database.pendingOperations();
        if (operations.isEmpty) break;
        var batchFailed = false;
        for (final operation in operations) {
          if (_disposed) return;
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
        if (batchFailed) break;
      }
    } on Object {
      if (!_disposed) rethrow;
    } finally {
      _running = false;
    }
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
    final payload = (jsonDecode(operation.payload) as Map)
        .cast<String, Object?>();
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
