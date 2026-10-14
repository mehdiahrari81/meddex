import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediexplain/core/network/api_client.dart';
import 'package:mediexplain/core/storage/session_vault.dart';
import 'package:mediexplain/domain/models/session.dart';
import 'package:mocktail/mocktail.dart';

void main() {
  setUpAll(() => registerFallbackValue(Options()));

  test('restores persisted credentials from secure-vault boundary', () async {
    final session = _session();
    final vault = _MemoryVault()..stored = session;
    final manager = SessionManager(
      refreshClient: MockDio(),
      vault: vault,
      baseUrl: Uri.parse('https://api.example.test/api/v1/'),
    );

    expect(await manager.restore(), same(session));
    expect(manager.current, same(session));
  });

  test('refresh rotates both access and refresh tokens', () async {
    final old = _session();
    final refreshed = _session(access: 'access-2', refresh: 'refresh-2');
    final vault = _MemoryVault()..stored = old;
    final dio = MockDio();
    when(
      () => dio.post<Map<String, Object?>>(
        any(),
        data: any(named: 'data'),
        options: any(named: 'options'),
      ),
    ).thenAnswer(
      (_) async => Response(
        requestOptions: RequestOptions(),
        data: {
          'session_id': refreshed.id,
          'user_id': refreshed.userId,
          'access_token': refreshed.accessToken,
          'refresh_token': refreshed.refreshToken,
          'access_token_expires_at': refreshed.accessTokenExpiresAt
              .toIso8601String(),
          'created_at': refreshed.createdAt.toIso8601String(),
        },
      ),
    );
    final manager = SessionManager(
      refreshClient: dio,
      vault: vault,
      baseUrl: Uri.parse('https://api.example.test/api/v1/'),
    );
    await manager.restore();

    final result = await manager.refresh();

    expect(result?.accessToken, 'access-2');
    expect(result?.refreshToken, 'refresh-2');
    expect(vault.stored?.refreshToken, 'refresh-2');
  });

  test('network failure preserves credentials for offline recovery', () async {
    final vault = _MemoryVault()..stored = _session();
    final dio = MockDio();
    when(
      () => dio.post<Map<String, Object?>>(
        any(),
        data: any(named: 'data'),
        options: any(named: 'options'),
      ),
    ).thenThrow(DioException(requestOptions: RequestOptions()));
    final manager = SessionManager(
      refreshClient: dio,
      vault: vault,
      baseUrl: Uri.parse('https://api.example.test/api/v1/'),
    );
    await manager.restore();

    expect(await manager.refresh(), isNull);
    expect(vault.stored, isNotNull);
    expect(manager.current, same(vault.stored));
  });

  test('rejected refresh clears invalid credentials', () async {
    final vault = _MemoryVault()..stored = _session();
    final dio = MockDio();
    when(
      () => dio.post<Map<String, Object?>>(
        any(),
        data: any(named: 'data'),
        options: any(named: 'options'),
      ),
    ).thenThrow(
      DioException(
        requestOptions: RequestOptions(),
        response: Response(requestOptions: RequestOptions(), statusCode: 401),
      ),
    );
    final manager = SessionManager(
      refreshClient: dio,
      vault: vault,
      baseUrl: Uri.parse('https://api.example.test/api/v1/'),
    );
    await manager.restore();
    expect(await manager.refresh(), isNull);
    expect(manager.current, isNull);
    expect(vault.stored, isNull);
  });

  test('an in-flight refresh cannot restore a signed-out session', () async {
    final old = _session();
    final vault = _MemoryVault()..stored = old;
    final dio = MockDio();
    final response = Completer<Response<Map<String, Object?>>>();
    when(
      () => dio.post<Map<String, Object?>>(
        any(),
        data: any(named: 'data'),
        options: any(named: 'options'),
      ),
    ).thenAnswer((_) => response.future);
    final manager = SessionManager(
      refreshClient: dio,
      vault: vault,
      baseUrl: Uri.parse('https://api.example.test/api/v1/'),
    );
    await manager.restore();
    final refreshing = manager.refresh();
    await manager.clear();
    response.complete(
      Response(
        requestOptions: RequestOptions(),
        data: {
          'session_id': old.id,
          'user_id': old.userId,
          'access_token': 'new-access',
          'refresh_token': 'new-refresh',
          'access_token_expires_at': old.accessTokenExpiresAt.toIso8601String(),
          'created_at': old.createdAt.toIso8601String(),
        },
      ),
    );
    expect(await refreshing, isNull);
    expect(manager.current, isNull);
    expect(vault.stored, isNull);
  });
}

Session _session({String access = 'access-1', String refresh = 'refresh-1'}) {
  final now = DateTime.now().toUtc();
  return Session(
    id: 'session-id',
    userId: 'user-id',
    accessToken: access,
    refreshToken: refresh,
    accessTokenExpiresAt: now.add(const Duration(minutes: 5)),
    createdAt: now,
  );
}

class MockDio extends Mock implements Dio {}

class _MemoryVault implements SessionVault {
  Session? stored;

  @override
  Future<void> clear() async => stored = null;

  @override
  Future<Session?> read() async => stored;

  @override
  Future<void> write(Session session) async => stored = session;
}
