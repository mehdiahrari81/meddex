import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/config/app_config.dart';
import '../../features/auth/application/auth_controller.dart';

import 'app_database.dart';

final accountDatabaseFactoryProvider = Provider(
  (ref) =>
      (String? ownerId, bool production) =>
          AppDatabase(ownerId: ownerId, production: production),
);

final databaseProvider = Provider<AppDatabase>((ref) {
  final ownerId = ref.watch(
    authControllerProvider.select((auth) => auth.valueOrNull?.session?.userId),
  );
  final database = ref.watch(accountDatabaseFactoryProvider)(
    ownerId,
    ref.watch(appConfigProvider).environment == AppEnvironment.production,
  );
  ref.onDispose(database.close);
  return database;
});
