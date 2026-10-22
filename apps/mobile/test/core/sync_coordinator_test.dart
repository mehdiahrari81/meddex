import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediexplain/core/database/app_database.dart';
import 'package:mediexplain/core/sync/sync_coordinator.dart';

void main() {
  late AppDatabase database;

  setUp(() => database = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => database.close());

  test(
    'local mutation creates an idempotent pending outbox operation',
    () async {
      final coordinator = SyncCoordinator(
        database: database,
        transport: _SuccessTransport(),
      );

      await coordinator.enqueue(
        entityType: 'saved_term',
        entityId: 'term-id',
        operationType: 'create',
        payload: '{"term_id":"term-id"}',
      );

      final operations = await database.select(database.syncOperations).get();
      expect(operations, hasLength(1));
      expect(operations.single.syncState, 'pending');
      expect(operations.single.idempotencyKey, isNotEmpty);
      expect(operations.single.retryCount, 0);
    },
  );

  test('successful synchronization stores server revision', () async {
    final coordinator = SyncCoordinator(
      database: database,
      transport: _SuccessTransport(),
    );
    await coordinator.enqueue(
      entityType: 'profile',
      entityId: 'user-id',
      operationType: 'update',
      payload: '{}',
    );

    await coordinator.synchronize();

    final operation = await database
        .select(database.syncOperations)
        .getSingle();
    expect(operation.syncState, 'synced');
    expect(operation.serverRevision, 'revision-1');
  });

  test('failed synchronization schedules exponential retry safely', () async {
    final now = DateTime.now().toUtc();
    final coordinator = SyncCoordinator(
      database: database,
      transport: _FailingTransport(),
      clock: () => now,
    );
    await coordinator.enqueue(
      entityType: 'profile',
      entityId: 'user-id',
      operationType: 'update',
      payload: '{}',
    );

    await coordinator.synchronize();

    final operation = await database
        .select(database.syncOperations)
        .getSingle();
    expect(operation.syncState, 'failed');
    expect(operation.retryCount, 1);
    expect(operation.lastError, 'transport_failure');
    final actual = operation.nextAttemptAt!.toUtc();
    final expected = now.add(const Duration(seconds: 2));
    expect(actual.difference(expected).inSeconds.abs(), lessThanOrEqualTo(1));
  });

  test('a healthy synchronization drains more than one batch', () async {
    final coordinator = SyncCoordinator(
      database: database,
      transport: _SuccessTransport(),
    );
    for (var index = 0; index < 55; index++) {
      await coordinator.enqueue(
        entityType: 'saved_item',
        entityId: 'item-$index',
        operationType: 'create',
        payload: '{}',
      );
    }
    await coordinator.synchronize();
    expect(await database.pendingOperations(), isEmpty);
  });

  test(
    'upload opt-out still sends requested backup deletions and nothing else',
    () async {
      final recorder = _RecordingTransport();
      final sync = SyncCoordinator(
        database: database,
        transport: DeletionOnlySyncTransport(recorder),
      );
      await sync.enqueue(
        entityType: 'medication_plan',
        entityId: 'keep-local',
        operationType: 'upsert',
        payload: '{}',
      );
      await sync.enqueue(
        entityType: 'user_medication',
        entityId: 'erase-backup',
        operationType: 'delete',
        payload: '{"id":"erase-backup"}',
        tombstone: true,
      );
      await sync.synchronize();
      expect(recorder.sent, ['erase-backup']);
      final pending = (await database.pendingOperations()).single;
      expect(pending.entityId, 'keep-local');
      expect(pending.retryCount, 0);
    },
  );

  test(
    'disabled synchronization preserves pending operations without retries',
    () async {
      final coordinator = SyncCoordinator(
        database: database,
        transport: const DisabledSyncTransport(),
      );
      await coordinator.enqueue(
        entityType: 'saved_item',
        entityId: 'local-item',
        operationType: 'create',
        payload: '{}',
      );
      await coordinator.synchronize();
      final pending = (await database.pendingOperations()).single;
      expect(pending.syncState, 'pending');
      expect(pending.retryCount, 0);
    },
  );
}

class _SuccessTransport implements SyncTransport {
  @override
  Future<SyncReceipt> send(SyncOperation operation) async =>
      const SyncReceipt(serverRevision: 'revision-1');
}

class _FailingTransport implements SyncTransport {
  @override
  Future<SyncReceipt> send(SyncOperation operation) =>
      throw StateError('simulated network failure');
}

class _RecordingTransport implements SyncTransport {
  final sent = <String>[];
  @override
  Future<SyncReceipt> send(SyncOperation operation) async {
    sent.add(operation.entityId);
    return const SyncReceipt(serverRevision: '1');
  }
}
