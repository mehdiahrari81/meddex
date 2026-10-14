import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediexplain/core/auth/auth_repository.dart';
import 'package:mediexplain/domain/models/session.dart';
import 'package:mediexplain/domain/models/user.dart';
import 'package:mediexplain/features/auth/application/auth_controller.dart';

void main() {
  test('missing persisted session starts in guest state', () async {
    final repository = _FakeAuthRepository();
    final container = ProviderContainer(
      overrides: [authRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);

    final state = await container.read(authControllerProvider.future);
    expect(state.status, AuthStatus.guest);
  });

  test(
    'sign in creates authenticated state and logout revokes session',
    () async {
      final repository = _FakeAuthRepository();
      final container = ProviderContainer(
        overrides: [authRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);
      await container.read(authControllerProvider.future);

      await container
          .read(authControllerProvider.notifier)
          .signIn('person@example.com', 'ValidPassword!1');
      expect(
        container.read(authControllerProvider).value?.status,
        AuthStatus.authenticated,
      );

      await container.read(authControllerProvider.notifier).signOut();
      expect(repository.revoked, isTrue);
      expect(
        container.read(authControllerProvider).value?.status,
        AuthStatus.guest,
      );
    },
  );
}

class _FakeAuthRepository implements AuthRepository {
  bool revoked = false;
  Session? session;

  @override
  Future<Session?> restoreSession() async => session;

  @override
  Future<Session> signIn({
    required String email,
    required String password,
  }) async {
    final now = DateTime.now().toUtc();
    return session = Session(
      id: 'session-id',
      userId: 'user-id',
      accessToken: 'access',
      refreshToken: 'refresh',
      accessTokenExpiresAt: now.add(const Duration(minutes: 10)),
      createdAt: now,
    );
  }

  @override
  Future<void> signOut() => revokeCurrentSession();

  @override
  Future<void> revokeCurrentSession() async {
    revoked = true;
    session = null;
  }

  @override
  Future<Session> register({
    required String email,
    required String password,
    required String displayName,
  }) => signIn(email: email, password: password);

  @override
  Future<AppUser> currentUser() => throw UnimplementedError();

  @override
  Future<void> requestPasswordReset(String email) async {}

  @override
  Future<void> resetPassword({
    required String token,
    required String password,
  }) async {}
}
