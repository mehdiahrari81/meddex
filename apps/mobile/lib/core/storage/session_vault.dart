import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../domain/models/session.dart';

abstract interface class SessionVault {
  Future<Session?> read();
  Future<void> write(Session session);
  Future<void> clear();
}

class SecureSessionVault implements SessionVault {
  SecureSessionVault(this._storage);

  static const _sessionKey = 'auth.session.v1';
  final FlutterSecureStorage _storage;

  @override
  Future<void> clear() => _storage.delete(key: _sessionKey);

  @override
  Future<Session?> read() async {
    final raw = await _storage.read(key: _sessionKey);
    if (raw == null) return null;
    try {
      final json = jsonDecode(raw) as Map<String, Object?>;
      return Session(
        id: json['id']! as String,
        userId: json['user_id']! as String,
        accessToken: json['access_token']! as String,
        refreshToken: json['refresh_token']! as String,
        accessTokenExpiresAt: DateTime.parse(
          json['access_token_expires_at']! as String,
        ).toUtc(),
        createdAt: DateTime.parse(json['created_at']! as String).toUtc(),
      );
    } on Object {
      await clear();
      return null;
    }
  }

  @override
  Future<void> write(Session session) => _storage.write(
    key: _sessionKey,
    value: jsonEncode({
      'id': session.id,
      'user_id': session.userId,
      'access_token': session.accessToken,
      'refresh_token': session.refreshToken,
      'access_token_expires_at': session.accessTokenExpiresAt.toIso8601String(),
      'created_at': session.createdAt.toIso8601String(),
    }),
  );
}
