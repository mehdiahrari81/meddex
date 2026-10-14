import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediexplain/core/database/app_database.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

void main() {
  late AppDatabase database;

  setUp(() => database = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => database.close());

  test(
    'schema v5 persists Module 1 metadata without destructive resets',
    () async {
      expect(database.schemaVersion, 5);
      await database.setMetadata('consent.version', '1');
      expect(await database.getMetadata('consent.version'), '1');
      await database.setMetadata('consent.version', '2');
      expect(await database.getMetadata('consent.version'), '2');
    },
  );

  test('Module 2 database upgrades to v5 without data loss', () async {
    await database.close();
    final directory = await Directory.systemTemp.createTemp(
      'mediexplain-module2-migration-',
    );
    final file = File('${directory.path}/module2.sqlite');
    database = AppDatabase.forTesting(NativeDatabase(file));
    await database.setMetadata('module2.dataset', 'preserved');
    await database
        .into(database.medicalCategories)
        .insert(
          MedicalCategoriesCompanion.insert(
            id: 'category',
            name: 'General',
            description: 'test',
          ),
        );
    await database.close();

    final module2 = sqlite.sqlite3.open(file.path);
    for (final table in [
      'prescription_verification_events',
      'prescription_field_edits',
      'prescription_field_candidates',
      'prescription_ocr_results',
      'barcode_scans',
      'prescription_items',
      'prescription_pages',
      'prescriptions',
    ]) {
      module2.execute('DROP TABLE $table');
    }
    module2.execute('PRAGMA user_version = 2');
    module2.close();

    database = AppDatabase.forTesting(NativeDatabase(file));
    final tables = await database
        .customSelect("SELECT name FROM sqlite_master WHERE type = 'table'")
        .get();
    final names = tables.map((row) => row.read<String>('name'));
    expect(
      names,
      containsAll(['prescriptions', 'prescription_items', 'barcode_scans']),
    );
    expect(await database.getMetadata('module2.dataset'), 'preserved');
    expect(
      await database.select(database.medicalCategories).get(),
      hasLength(1),
    );
    final integrity = await database
        .customSelect('PRAGMA integrity_check')
        .getSingle();
    expect(integrity.data.values.single, 'ok');
    await database.close();
    await directory.delete(recursive: true);
    database = AppDatabase.forTesting(NativeDatabase.memory());
  });

  test('Module 1 database upgrades to v3 without resetting metadata', () async {
    await database.close();
    final directory = await Directory.systemTemp.createTemp(
      'mediexplain-drift-migration-',
    );
    final file = File('${directory.path}/module1.sqlite');
    final legacy = NativeDatabase(file, enableMigrations: false);
    await legacy.ensureOpen(_LegacyDatabaseUser());
    await legacy.runCustom('''
      CREATE TABLE app_metadata (
        "key" TEXT NOT NULL PRIMARY KEY,
        "value" TEXT NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');
    await legacy.runCustom('''
      CREATE TABLE sync_operations (
        id TEXT NOT NULL PRIMARY KEY,
        entity_type TEXT NOT NULL,
        entity_id TEXT NOT NULL,
        operation_type TEXT NOT NULL,
        payload TEXT NOT NULL,
        idempotency_key TEXT NOT NULL UNIQUE,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        sync_state TEXT NOT NULL DEFAULT 'pending',
        retry_count INTEGER NOT NULL DEFAULT 0,
        last_error TEXT NULL,
        server_revision TEXT NULL,
        tombstone INTEGER NOT NULL DEFAULT 0,
        next_attempt_at INTEGER NULL
      )
    ''');
    await legacy.runCustom(
      "INSERT INTO app_metadata VALUES ('consent.version', '7', 0)",
    );
    await legacy.runCustom('PRAGMA user_version = 1');
    await legacy.close();

    database = AppDatabase.forTesting(NativeDatabase(file));
    expect(await database.getMetadata('consent.version'), '7');
    final tables = await database
        .customSelect("SELECT name FROM sqlite_master WHERE type = 'table'")
        .get();
    expect(
      tables.map((row) => row.read<String>('name')),
      contains('medical_terms'),
    );
    await database.close();
    await directory.delete(recursive: true);
    database = AppDatabase.forTesting(NativeDatabase.memory());
  });
}

class _LegacyDatabaseUser extends QueryExecutorUser {
  @override
  int get schemaVersion => 1;

  @override
  Future<void> beforeOpen(
    QueryExecutor executor,
    OpeningDetails details,
  ) async {}
}
