enum SyncOperationType { create, update, delete }

enum SyncState { pending, processing, synced, failed, conflict }

class SyncOperationModel {
  const SyncOperationModel({
    required this.id,
    required this.entityType,
    required this.entityId,
    required this.operationType,
    required this.payload,
    required this.idempotencyKey,
    required this.createdAt,
    required this.updatedAt,
    required this.syncState,
    required this.retryCount,
    required this.tombstone,
    this.lastError,
    this.serverRevision,
    this.nextAttemptAt,
  });

  final String id;
  final String entityType;
  final String entityId;
  final SyncOperationType operationType;
  final String payload;
  final String idempotencyKey;
  final DateTime createdAt;
  final DateTime updatedAt;
  final SyncState syncState;
  final int retryCount;
  final String? lastError;
  final String? serverRevision;
  final bool tombstone;
  final DateTime? nextAttemptAt;
}
