import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';

import '../../core/connectivity/connectivity_service.dart';
import '../../core/database/database_provider.dart';
import '../../core/sync/sync_provider.dart';
import '../../features/auth/application/auth_controller.dart';
import '../../features/settings/application/settings_controller.dart';
import '../../features/prescription/application/prescription_providers.dart';
import '../../features/medications/application/medication_providers.dart';
import 'startup_coordinator.dart';

final startupCoordinatorProvider = Provider<StartupCoordinator>((ref) {
  return StartupCoordinator(
    tasks: [
      StartupTask(StartupStep.environment, () async {
        await ref.read(settingsControllerProvider.future);
        ref.read(appConfigProvider);
      }),
      StartupTask(StartupStep.secureStorage, () async {
        await ref.read(sessionVaultProvider).read();
      }),
      StartupTask(StartupStep.authentication, () async {
        await ref.read(authControllerProvider.future);
      }),
      StartupTask(StartupStep.localDatabase, () async {
        final database = ref.read(databaseProvider);
        await database.customSelect('SELECT 1').getSingle();
      }),
      StartupTask(StartupStep.privateFileCleanup, () async {
        await ref.read(prescriptionImageStoreProvider).cleanupTemporaryFiles();
      }),
      StartupTask(StartupStep.settings, () async {
        await ref.read(settingsControllerProvider.future);
      }),
      StartupTask(StartupStep.connectivity, () async {
        await ref.read(connectivityServiceProvider).current();
      }),
      StartupTask(StartupStep.localization, () async {
        final code = (await ref.read(
          settingsControllerProvider.future,
        )).languageCode;
        if (!const {'en', 'ur'}.contains(code)) {
          throw StateError('Unsupported stored locale.');
        }
      }),
      StartupTask(StartupStep.synchronization, () async {
        final database = ref.read(databaseProvider);
        try {
          final currentTimezone =
              (await FlutterTimezone.getLocalTimezone()).identifier;
          final previousTimezone = await database.getMetadata(
            'medication.last_timezone',
          );
          if (previousTimezone != null && previousTimezone != currentTimezone) {
            await database.setMetadata(
              'medication.timezone_review_required',
              'true',
            );
          }
          await database.setMetadata(
            'medication.last_timezone',
            currentTimezone,
          );
        } on Object {
          // Platform timezone lookup is unavailable in some test/desktop
          // environments. Stored schedules remain unchanged.
        }
        final authenticated =
            (await ref.read(authControllerProvider.future)).status ==
            AuthStatus.authenticated;
        if (authenticated) {
          unawaited(synchronizeSafely(ref.read(syncCoordinatorProvider)));
        }
        try {
          final adapter = ref.read(notificationAdapterProvider);
          final reminderService = ref.read(medicationReminderServiceProvider);
          await adapter.initialize(
            (response) =>
                ref.read(medicationReminderServiceProvider).handle(response),
          );
          final plans = await ref.read(medicationPlansProvider.future);
          await reminderService.rebuild(plans: plans);
        } on Object {
          // Non-fatal notification adapter failure
        }
      }),
      const StartupTask(StartupStep.router, _routerReady),
    ],
  );
});

Future<void> _routerReady() async {}

final bootstrapProvider = FutureProvider<StartupResult>(
  (ref) => ref.watch(startupCoordinatorProvider).initialize(),
);
