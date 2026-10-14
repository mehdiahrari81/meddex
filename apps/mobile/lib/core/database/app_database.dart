import 'dart:io';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as path;
import '../storage/safe_path_provider.dart';
import '../../features/terminology/data/terminology_seed_importer.dart';

import 'module2_tables.dart';
import 'module3_tables.dart';
import 'module4_tables.dart';
import 'module5_tables.dart';

part 'app_database.g.dart';

class AppMetadata extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}

class SyncOperations extends Table {
  TextColumn get id => text()();
  TextColumn get entityType => text()();
  TextColumn get entityId => text()();
  TextColumn get operationType => text()();
  TextColumn get payload => text()();
  TextColumn get idempotencyKey => text().unique()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  TextColumn get syncState => text().withDefault(const Constant('pending'))();
  IntColumn get retryCount => integer().withDefault(const Constant(0))();
  TextColumn get lastError => text().nullable()();
  TextColumn get serverRevision => text().nullable()();
  BoolColumn get tombstone => boolean().withDefault(const Constant(false))();
  DateTimeColumn get nextAttemptAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DriftDatabase(
  tables: [
    AppMetadata,
    SyncOperations,
    MedicalTerms,
    TermDefinitions,
    TermAliases,
    TermExamples,
    ContentSources,
    MedicalCategories,
    MorphologyElements,
    TermMorphologies,
    TermRelations,
    MedicalAbbreviations,
    SearchHistoryItems,
    SavedContentItems,
    LearningLessons,
    LessonSections,
    Flashcards,
    QuizQuestions,
    QuizOptions,
    LessonProgressEntries,
    FlashcardSchedules,
    QuizAttempts,
    LearningStreaks,
    ContentReports,
    ContentVersions,
    Prescriptions,
    PrescriptionPages,
    PrescriptionOcrResults,
    PrescriptionItems,
    PrescriptionFieldCandidates,
    PrescriptionFieldEdits,
    PrescriptionVerificationEvents,
    BarcodeScans,
    UserMedications,
    MedicationPlans,
    MedicationPlanSources,
    MedicationSchedules,
    ReminderTimes,
    DoseEvents,
    MedicationNotes,
    RefillReminders,
    MedicationPlanHistory,
    MedicationExportMetadata,
    UserPrivacyPreferences,
    RecentActivityItems,
    CachedMedicationIdentities,
    MedicationResolutionHistory,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase({String? ownerId, this.production = false})
    : _seedContent = true,
      super(_openConnection(ownerId));
  AppDatabase.forTesting(super.executor)
    : _seedContent = false,
      production = false;

  final bool _seedContent;
  final bool production;

  @override
  int get schemaVersion => 5;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) async {
      await migrator.createAll();
      await _ensureModule2Indexes();
      await _ensureModule3Indexes();
      await _ensureModule4Indexes();
      await _ensureModule5Indexes();
    },
    onUpgrade: (migrator, from, to) async {
      if (from < 2) {
        await migrator.createTable(medicalTerms);
        await migrator.createTable(termDefinitions);
        await migrator.createTable(termAliases);
        await migrator.createTable(termExamples);
        await migrator.createTable(contentSources);
        await migrator.createTable(medicalCategories);
        await migrator.createTable(morphologyElements);
        await migrator.createTable(termMorphologies);
        await migrator.createTable(termRelations);
        await migrator.createTable(medicalAbbreviations);
        await migrator.createTable(searchHistoryItems);
        await migrator.createTable(savedContentItems);
        await migrator.createTable(learningLessons);
        await migrator.createTable(lessonSections);
        await migrator.createTable(flashcards);
        await migrator.createTable(quizQuestions);
        await migrator.createTable(quizOptions);
        await migrator.createTable(lessonProgressEntries);
        await migrator.createTable(flashcardSchedules);
        await migrator.createTable(quizAttempts);
        await migrator.createTable(learningStreaks);
        await migrator.createTable(contentReports);
        await migrator.createTable(contentVersions);
        await _ensureModule2Indexes();
      }
      if (from < 3) {
        await migrator.createTable(prescriptions);
        await migrator.createTable(prescriptionPages);
        await migrator.createTable(prescriptionOcrResults);
        await migrator.createTable(prescriptionItems);
        await migrator.createTable(prescriptionFieldCandidates);
        await migrator.createTable(prescriptionFieldEdits);
        await migrator.createTable(prescriptionVerificationEvents);
        await migrator.createTable(barcodeScans);
        await _ensureModule3Indexes();
      }
      if (from < 4) {
        await migrator.createTable(userMedications);
        await migrator.createTable(medicationPlans);
        await migrator.createTable(medicationPlanSources);
        await migrator.createTable(medicationSchedules);
        await migrator.createTable(reminderTimes);
        await migrator.createTable(doseEvents);
        await migrator.createTable(medicationNotes);
        await migrator.createTable(refillReminders);
        await migrator.createTable(medicationPlanHistory);
        await migrator.createTable(medicationExportMetadata);
        await migrator.createTable(userPrivacyPreferences);
        await migrator.createTable(recentActivityItems);
        await _ensureModule5Indexes();
      }
      if (from < 5) {
        await migrator.createTable(cachedMedicationIdentities);
        await migrator.createTable(medicationResolutionHistory);
        await _ensureModule4Indexes();
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
      // A terminated sync must remain retryable after the app restarts.
      await customStatement(
        "UPDATE sync_operations SET sync_state = 'pending' WHERE sync_state = 'processing'",
      );
      if (details.hadUpgrade) {
        final result = await customSelect('PRAGMA integrity_check').getSingle();
        if (result.data.values.first != 'ok') {
          throw StateError('Local database integrity check failed.');
        }
      }
      if (_seedContent) {
        final importer = TerminologySeedImporter(this);
        final report = await importer.importBundled(dryRun: production);
        if (production && report.productionApproved) {
          await importer.importBundled();
        }
      }
    },
  );

  Future<void> _ensureModule2Indexes() async {
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_terms_normalized '
      'ON medical_terms(normalized_term)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_terms_category_language_status '
      'ON medical_terms(category_id, language, review_status, deprecated)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_aliases_normalized_type '
      'ON term_aliases(normalized_alias, alias_type)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_abbreviations_normalized '
      'ON medical_abbreviations(normalized_abbreviation)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_morphology_type_value '
      'ON morphology_elements(element_type, normalized_value)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_flashcard_due '
      'ON flashcard_schedules(next_review_at)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_search_history_recent '
      'ON search_history_items(searched_at DESC)',
    );
  }

  Future<void> _ensureModule3Indexes() async {
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_prescriptions_history '
      'ON prescriptions(deleted_at, updated_at DESC)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_prescriptions_draft '
      'ON prescriptions(pipeline_state, deleted_at, updated_at DESC)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_prescriptions_fingerprint '
      'ON prescriptions(image_fingerprint, ocr_fingerprint)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_prescription_items_order '
      'ON prescription_items(prescription_id, position)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_prescription_edits_item '
      'ON prescription_field_edits(prescription_item_id, changed_at)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_barcode_duplicate '
      'ON barcode_scans(raw_value, scanned_at DESC)',
    );
  }

  Future<void> _ensureModule4Indexes() async {
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_cached_medication_recent '
      'ON cached_medication_identities(last_opened_at DESC)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_cached_medication_saved '
      'ON cached_medication_identities(saved, cached_at DESC)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_resolution_recent '
      'ON medication_resolution_history(created_at DESC)',
    );
  }

  Future<void> _ensureModule5Indexes() async {
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_user_medications_status '
      'ON user_medications(status, deleted_at, updated_at DESC)',
    );
    await customStatement(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_user_medications_prescription_item '
      'ON user_medications(prescription_item_id) '
      'WHERE prescription_item_id IS NOT NULL AND deleted_at IS NULL',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_medication_plans_active '
      'ON medication_plans(active, deleted_at, start_date, end_date)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_schedules_plan_active '
      'ON medication_schedules(medication_plan_id, active)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_dose_events_timeline '
      'ON dose_events(medication_plan_id, scheduled_at, recorded_at)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_history_plan_time '
      'ON medication_plan_history(medication_plan_id, occurred_at DESC)',
    );
  }

  Future<void> setMetadata(String key, String value) =>
      into(appMetadata).insertOnConflictUpdate(
        AppMetadataCompanion.insert(
          key: key,
          value: value,
          updatedAt: DateTime.now().toUtc(),
        ),
      );

  Future<String?> getMetadata(String key) async => (await (select(
    appMetadata,
  )..where((row) => row.key.equals(key))).getSingleOrNull())?.value;

  Future<void> enqueue(SyncOperationsCompanion operation) =>
      into(syncOperations).insert(operation, mode: InsertMode.insertOrIgnore);

  Future<List<SyncOperation>> pendingOperations({int limit = 50}) {
    final now = DateTime.now().toUtc();
    return (select(syncOperations)
          ..where(
            (row) =>
                row.syncState.isIn(['pending', 'failed']) &
                (row.nextAttemptAt.isNull() |
                    row.nextAttemptAt.isSmallerOrEqualValue(now)),
          )
          ..orderBy([(row) => OrderingTerm.asc(row.createdAt)])
          ..limit(limit))
        .get();
  }

  Future<void> markSyncing(String id) =>
      (update(syncOperations)..where((row) => row.id.equals(id))).write(
        SyncOperationsCompanion(
          syncState: const Value('processing'),
          updatedAt: Value(DateTime.now().toUtc()),
        ),
      );

  Future<void> markSynced(String id, {String? serverRevision}) =>
      (update(syncOperations)..where((row) => row.id.equals(id))).write(
        SyncOperationsCompanion(
          syncState: const Value('synced'),
          updatedAt: Value(DateTime.now().toUtc()),
          serverRevision: Value(serverRevision),
          lastError: const Value(null),
          nextAttemptAt: const Value(null),
        ),
      );

  Future<void> markFailed(
    String id, {
    required int retryCount,
    required String safeErrorCode,
    required DateTime nextAttemptAt,
  }) => (update(syncOperations)..where((row) => row.id.equals(id))).write(
    SyncOperationsCompanion(
      syncState: const Value('failed'),
      updatedAt: Value(DateTime.now().toUtc()),
      retryCount: Value(retryCount),
      lastError: Value(safeErrorCode),
      nextAttemptAt: Value(nextAttemptAt),
    ),
  );
}

String accountDatabaseFileName(String? ownerId) => ownerId == null
    ? 'mediexplain_guest.sqlite'
    : 'mediexplain_user_${sha256.convert(utf8.encode(ownerId))}.sqlite';

LazyDatabase _openConnection(String? ownerId) => LazyDatabase(() async {
  final documents = await getSafeApplicationSupportDirectory();
  final file = File(
    path.join(documents.path, accountDatabaseFileName(ownerId)),
  );
  return NativeDatabase(file);
});
