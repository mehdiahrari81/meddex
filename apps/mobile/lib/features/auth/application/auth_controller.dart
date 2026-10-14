import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../app/config/app_config.dart';
import '../../../core/auth/auth_repository.dart';
import '../../../core/network/api_client.dart';
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

final appConfigProvider = Provider<AppConfig>(
  (ref) => AppConfig.fromEnvironment(),
);
final sessionVaultProvider = Provider<SessionVault>(
  (ref) => SecureSessionVault(const FlutterSecureStorage()),
);
final sessionManagerProvider = Provider<SessionManager>((ref) {
  final config = ref.watch(appConfigProvider);
  return SessionManager(
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
});
final apiClientProvider = Provider<ApiClient>((ref) {
  final config = ref.watch(appConfigProvider);
  return ApiClient(
    baseUrl: config.apiBaseUrl,
    sessionManager: ref.watch(sessionManagerProvider),
  );
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
