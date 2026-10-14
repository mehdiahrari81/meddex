import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/database_provider.dart';
import '../network/api_client.dart';
import '../logging/app_logger.dart';
import '../../features/auth/application/auth_controller.dart';
import '../../features/settings/application/settings_controller.dart';
import 'sync_coordinator.dart';

final syncTransportProvider = Provider<SyncTransport>((ref) {
  final ownerId = ref
      .watch(authControllerProvider)
      .valueOrNull
      ?.session
      ?.userId;
  final syncEnabled =
      ref.watch(settingsControllerProvider).valueOrNull?.syncEnabled ?? false;
  if (ownerId == null || !syncEnabled) return const DisabledSyncTransport();
  final api = ApiClient(
    baseUrl: ref.watch(appConfigProvider).apiBaseUrl,
    sessionManager: ref.watch(sessionManagerProvider),
    expectedUserId: ownerId,
  );
  ref.onDispose(() => api.dio.close(force: true));
  return ApiSyncTransport(api);
});

final syncCoordinatorProvider = Provider<SyncCoordinator>((ref) {
  final coordinator = SyncCoordinator(
    database: ref.watch(databaseProvider),
    transport: ref.watch(syncTransportProvider),
  );
  ref.onDispose(coordinator.dispose);
  return coordinator;
});

Future<void> synchronizeSafely(SyncCoordinator coordinator) async {
  try {
    await coordinator.synchronize();
  } on Object catch (error) {
    AppLogger().log(
      LogLevel.warning,
      'synchronization_unavailable',
      fields: {'error_type': error.runtimeType.toString()},
    );
  }
}
