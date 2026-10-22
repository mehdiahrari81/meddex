import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../app/config/app_config.dart';
import '../../../core/auth/auth_repository.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/development_server.dart';
import '../../settings/application/settings_controller.dart';
import '../../../core/storage/session_vault.dart';
import '../../../domain/models/session.dart';

enum AuthStatus { guest, authenticated }

class AuthState {
  const AuthState.guest() : status = AuthStatus.guest, session = null;
  const AuthState.authenticated(this.session)
    : status = AuthStatus.authenticated;

  final AuthStatus status;
  final Session? session;
}

final bundledAppConfigProvider = Provider<AppConfig>(
  (ref) => AppConfig.fromEnvironment(),
);

final appConfigProvider = Provider<AppConfig>((ref) {
  final config = ref.watch(bundledAppConfigProvider);
  final override = ref.watch(
    settingsControllerProvider.select(
      (settings) => settings.valueOrNull?.developmentServerUrl ?? '',
    ),
  );
  final automatic = ref.watch(
    settingsControllerProvider.select(
      (settings) => settings.valueOrNull?.automaticServerConnection ?? true,
    ),
  );
  if (automatic && config.apiBaseUrl.host.endsWith('.local')) return config;
  if (config.environment == AppEnvironment.production || override.isEmpty) {
    return config;
  }
  try {
    return AppConfig(
      environment: config.environment,
      apiBaseUrl: validateDevelopmentServerUrl(override),
      enableDebugLogs: config.enableDebugLogs,
    );
  } on FormatException {
    return config;
  }
});
final sessionVaultProvider = Provider<SessionVault>(
  (ref) => SecureSessionVault(
    const FlutterSecureStorage(
      iOptions: IOSOptions(
        accessibility: KeychainAccessibility.unlocked_this_device,
      ),
    ),
  ),
);
final sessionManagerProvider = Provider<SessionManager>((ref) {
  final config = ref.watch(appConfigProvider);
  final manager = SessionManager(
    refreshClient: Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 5),
        receiveTimeout: const Duration(seconds: 5),
        sendTimeout: const Duration(seconds: 5),
      ),
    ),
    vault: ref.watch(sessionVaultProvider),
    baseUrl: config.apiBaseUrl,
  );
  ref.onDispose(manager.dispose);
  return manager;
});
final apiClientProvider = Provider<ApiClient>((ref) {
  final config = ref.watch(appConfigProvider);
  final client = ApiClient(
    baseUrl: config.apiBaseUrl,
    sessionManager: ref.watch(sessionManagerProvider),
  );
  ref.onDispose(() => client.dio.close(force: true));
  return client;
});
final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => ApiAuthRepository(
    ref.watch(apiClientProvider),
    ref.watch(sessionManagerProvider),
  ),
);
final authControllerProvider = AsyncNotifierProvider<AuthController, AuthState>(
  AuthController.new,
);

class AuthController extends AsyncNotifier<AuthState> {
  AuthRepository get _repository => ref.read(authRepositoryProvider);

  @override
  Future<AuthState> build() async {
    final session = await _repository.restoreSession();
    return session == null
        ? const AuthState.guest()
        : AuthState.authenticated(session);
  }

  Future<void> signIn(String email, String password) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () async => AuthState.authenticated(
        await _repository.signIn(email: email.trim(), password: password),
      ),
    );
  }

  Future<void> register(
    String email,
    String password,
    String displayName,
  ) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () async => AuthState.authenticated(
        await _repository.register(
          email: email.trim(),
          password: password,
          displayName: displayName.trim(),
        ),
      ),
    );
  }

  Future<void> continueAsGuest() async {
    await _repository.signOut();
    state = const AsyncData(AuthState.guest());
  }

  Future<void> signOut() async {
    try {
      await _repository.signOut();
    } finally {
      state = const AsyncData(AuthState.guest());
    }
  }
}
