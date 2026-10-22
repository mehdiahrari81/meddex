import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as path;

import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/network/api_client.dart';
import '../../../core/storage/safe_path_provider.dart';
import '../../../core/sync/sync_coordinator.dart';
import '../../../core/sync/sync_provider.dart';
import '../../auth/application/auth_controller.dart';
import '../../medications/application/medication_providers.dart';
import '../../prescription/application/prescription_providers.dart';
import '../../prescription/application/prescription_workflow_controller.dart';
import '../../prescription/domain/prescription_providers.dart';
import '../data/settings_repository.dart';
import 'settings_controller.dart';

/// Erases only the currently opened profile database. Reference lessons and
/// medical reference content remain available; other profiles are untouched.
class LocalUserDataEraser {
  const LocalUserDataEraser({
    required this.database,
    required this.images,
    required this.cancelNotifications,
    required this.clearTemporaryFiles,
    required this.preferences,
  });
  final AppDatabase database;
  final PrescriptionImageStore images;
  final Future<void> Function() cancelNotifications;
  final Future<void> Function() clearTemporaryFiles;
  final SettingsRepository preferences;

  Future<void> erase({bool preservePendingDeletions = true}) async {
    // Leave the database's image IDs available for an idempotent retry if a
    // platform/file operation fails. Never announce completion after failure.
    await cancelNotifications();
    final pages = await database.select(database.prescriptionPages).get();
    final scans = await database.select(database.prescriptions).get();
    final ids = <String>{
      for (final page in pages) ...[
        if (page.originalImageId != null) page.originalImageId!,
        if (page.processedImageId != null) page.processedImageId!,
      ],
      for (final scan in scans) ...[
        if (scan.originalImageId != null) scan.originalImageId!,
        if (scan.processedImageId != null) scan.processedImageId!,
      ],
    };
    for (final id in ids) {
      await images.deleteByPrivateId(id);
    }
    await clearTemporaryFiles();
    await database.transaction(() async {
      for (final table in <TableInfo<Table, dynamic>>[
        database.doseEvents,
        database.medicationNotes,
        database.refillReminders,
        database.medicationPlanHistory,
        database.reminderTimes,
        database.medicationSchedules,
        database.medicationPlanSources,
        database.medicationPlans,
        database.userMedications,
        database.prescriptionVerificationEvents,
        database.prescriptionFieldEdits,
        database.prescriptionFieldCandidates,
        database.prescriptionItems,
        database.prescriptionOcrResults,
        database.barcodeScans,
        database.prescriptionPages,
        database.prescriptions,
        database.medicationExportMetadata,
        database.userPrivacyPreferences,
        database.recentActivityItems,
        database.medicationResolutionHistory,
        database.cachedMedicationIdentities,
        database.searchHistoryItems,
        database.savedContentItems,
        database.lessonProgressEntries,
        database.flashcardSchedules,
        database.quizAttempts,
        database.learningStreaks,
        database.contentReports,
        database.appMetadata,
      ]) {
        await database.delete(table).go();
      }
      final operations = await database.select(database.syncOperations).get();
      for (final operation in operations) {
        final deletion =
            operation.operationType == 'delete' || operation.tombstone;
        if (preservePendingDeletions &&
            deletion &&
            operation.syncState != 'synced') {
          final payload =
              (jsonDecode(operation.payload) as Map).cast<String, Object?>()
                ..remove(syncDependenciesKey);
          await (database.update(
            database.syncOperations,
          )..where((row) => row.id.equals(operation.id))).write(
            SyncOperationsCompanion(
              payload: Value(jsonEncode(payload)),
              syncState: const Value('pending'),
              retryCount: const Value(0),
              nextAttemptAt: const Value(null),
              lastError: const Value(null),
            ),
          );
        } else {
          await (database.delete(
            database.syncOperations,
          )..where((row) => row.id.equals(operation.id))).go();
        }
      }
    });
    await preferences.clearLocalPreferences();
  }
}

final localUserDataEraserProvider = Provider(
  (ref) => LocalUserDataEraser(
    database: ref.watch(databaseProvider),
    images: ref.watch(prescriptionImageStoreProvider),
    preferences: ref.watch(settingsRepositoryProvider),
    cancelNotifications: () => ref
        .read(accountReminderCoordinatorProvider)
        .cancelAll(ref.read(notificationAdapterProvider).cancelAll),
    clearTemporaryFiles: () async {
      await ref
          .read(privatePrescriptionImageStoreProvider)
          .clearTemporaryFiles();
      final directory = await getSafeTemporaryDirectory();
      final export = File(
        path.join(directory.path, 'mediexplain-user-medication-summary.pdf'),
      );
      if (await export.exists()) await export.delete();
    },
  ),
);

/// Hold one instance while the confirmation dialog is open so a local cleanup
/// retry never repeats an already acknowledged remote account deletion.
class AccountDeletionService {
  AccountDeletionService({
    required this.api,
    required this.eraseLocal,
    required this.signOut,
  });
  final ApiClient api;
  final Future<void> Function() eraseLocal;
  final Future<void> Function() signOut;
  bool _remoteDeleted = false;

  Future<void> delete() async {
    if (!_remoteDeleted) {
      if (api.currentUserId == null) {
        throw StateError('Sign in before deleting your account.');
      }
      await api.delete('users/me');
      _remoteDeleted = true;
    }
    await eraseLocal();
    await signOut();
  }
}

Future<void> eraseCurrentProfile(Ref ref, {bool accountDeleted = false}) async {
  final eraser = ref.read(localUserDataEraserProvider);
  ref.read(prescriptionWorkflowControllerProvider.notifier).cancelProcessing();
  ref.read(syncCoordinatorProvider).dispose();
  try {
    await eraser.erase(preservePendingDeletions: !accountDeleted);
    ref.invalidate(prescriptionWorkflowControllerProvider);
    ref.invalidate(databaseProvider);
  } finally {
    ref.invalidate(syncCoordinatorProvider);
    ref.invalidate(settingsControllerProvider);
    ref.invalidate(medicationPrivacyProvider);
    ref.invalidate(medicationTimezoneReviewProvider);
  }
}

final clearLocalProfileProvider = Provider<Future<void> Function()>(
  (ref) =>
      () => eraseCurrentProfile(ref),
);
final accountDeletionServiceProvider = Provider((ref) {
  ref.watch(
    authControllerProvider.select((auth) => auth.valueOrNull?.session?.userId),
  );
  return AccountDeletionService(
    api: ref.read(apiClientProvider),
    eraseLocal: () => eraseCurrentProfile(ref, accountDeleted: true),
    signOut: () => ref.read(authControllerProvider.notifier).signOut(),
  );
});
