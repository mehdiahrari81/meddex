import '../../domain/models/session.dart';
import '../../domain/models/user.dart';
import '../network/api_client.dart';

abstract interface class AuthRepository {
  Future<Session?> restoreSession();
  Future<Session> signIn({required String email, required String password});
  Future<Session> register({
    required String email,
    required String password,
    required String displayName,
  });
  Future<void> requestPasswordReset(String email);
  Future<void> resetPassword({required String token, required String password});
  Future<void> signOut();
  Future<void> revokeCurrentSession();
  Future<AppUser> currentUser();
}

class ApiAuthRepository implements AuthRepository {
  ApiAuthRepository(this._api, this._sessions);

  final ApiClient _api;
  final SessionManager _sessions;

  @override
  Future<Session?> restoreSession() async {
    final session = await _sessions.restore();
    if (session == null) return null;
    if (!session.isAccessTokenExpired) return session;
    return await _sessions.refresh() ?? _sessions.current;
  }

  @override
  Future<Session> signIn({
    required String email,
    required String password,
  }) async {
    final json = await _api.postJson(
      'auth/login',
      authenticated: false,
      data: {'email': email, 'password': password},
    );
    final session = sessionFromJson(json);
    await _sessions.set(session);
    return session;
  }

  @override
  Future<Session> register({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final json = await _api.postJson(
      'auth/register',
      authenticated: false,
      data: {'email': email, 'password': password, 'display_name': displayName},
    );
    final session = sessionFromJson(json);
    await _sessions.set(session);
    return session;
  }

  @override
  Future<void> requestPasswordReset(String email) async {
    await _api.postJson(
      'auth/password/forgot',
      authenticated: false,
      data: {'email': email},
    );
  }

  @override
  Future<void> resetPassword({
    required String token,
    required String password,
  }) async {
    await _api.postJson(
      'auth/password/reset',
      authenticated: false,
      data: {'token': token, 'new_password': password},
    );
  }

  @override
  Future<void> revokeCurrentSession() async {
    try {
      await _api.postJson('auth/logout', data: const {});
    } on Object {
      // Offline sign-out still clears local credentials. Remote revocation can
      // be performed from another active session when a connection returns.
    } finally {
      await _sessions.clear();
    }
  }

  @override
  Future<void> signOut() => revokeCurrentSession();

  @override
  Future<AppUser> currentUser() async {
    final json = await _api.getJson('users/me');
    return AppUser(
      id: json['id']! as String,
      email: json['email']! as String,
      displayName: json['display_name'] as String?,
      createdAt: DateTime.parse(json['created_at']! as String).toUtc(),
    );
  }
}
