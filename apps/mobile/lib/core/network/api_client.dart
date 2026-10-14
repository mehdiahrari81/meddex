import 'dart:async';

import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';

import '../../domain/models/session.dart';
import '../errors/error_mapper.dart';
import '../storage/session_vault.dart';

class SessionManager {
  factory SessionManager({
    required Dio refreshClient,
    required SessionVault vault,
    required Uri baseUrl,
  }) => SessionManager._(refreshClient, vault, baseUrl);

  SessionManager._(this._refreshClient, this._vault, this._baseUrl);

  final Dio _refreshClient;
  final SessionVault _vault;
  final Uri _baseUrl;
  Session? _session;
  Future<Session?>? _refreshing;

  Session? get current => _session;

  Future<Session?> restore() async {
    _session = await _vault.read();
    return _session;
  }

  Future<void> set(Session session) async {
    _session = session;
    await _vault.write(session);
  }

  Future<void> clear() async {
    _session = null;
    await _vault.clear();
  }

  Future<Session?> refresh() {
    final existing = _refreshing;
    if (existing != null) return existing;
    final operation = _performRefresh();
    _refreshing = operation;
    return operation.whenComplete(() => _refreshing = null);
  }

  Future<Session?> _performRefresh() async {
    final currentSession = _session ?? await restore();
    if (currentSession == null) return null;
    try {
      final response = await _refreshClient.post<Map<String, Object?>>(
        _baseUrl.resolve('auth/refresh').toString(),
        data: {'refresh_token': currentSession.refreshToken},
        options: Options(headers: {'X-Request-ID': const Uuid().v4()}),
      );
      final refreshed = sessionFromJson(response.data!);
      if (_session?.refreshToken != currentSession.refreshToken) return null;
      await set(refreshed);
      return refreshed;
    } on DioException catch (error) {
      if (_session?.refreshToken == currentSession.refreshToken &&
          (error.response?.statusCode == 401 ||
              error.response?.statusCode == 403)) {
        await clear();
      }
      return null;
    } on Object {
      return null;
    }
  }
}

class ApiClient {
  factory ApiClient({
    required Uri baseUrl,
    required SessionManager sessionManager,
    Dio? dio,
    String? expectedUserId,
  }) {
    final client = ApiClient._(
      sessionManager,
      dio ??
          Dio(
            BaseOptions(
              baseUrl: baseUrl.toString(),
              connectTimeout: const Duration(seconds: 12),
              receiveTimeout: const Duration(seconds: 20),
              sendTimeout: const Duration(seconds: 20),
              responseType: ResponseType.json,
            ),
          ),
    );
    client.dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          if (expectedUserId != null &&
              client._sessionManager.current?.userId != expectedUserId) {
            return handler.reject(
              DioException(
                requestOptions: options,
                type: DioExceptionType.cancel,
                error: 'account_changed',
              ),
            );
          }
          options.headers['X-Request-ID'] = const Uuid().v4();
          if (options.extra['skipAuth'] != true) {
            final session = client._sessionManager.current;
            if (session != null) {
              options.headers['Authorization'] =
                  'Bearer ${session.accessToken}';
            }
          }
          handler.next(options);
        },
        onError: (error, handler) async {
          final request = error.requestOptions;
          if (error.response?.statusCode == 401 &&
              request.extra['retriedAfterRefresh'] != true &&
              request.extra['skipAuth'] != true) {
            final refreshed = await client._sessionManager.refresh();
            if (refreshed != null) {
              request.extra['retriedAfterRefresh'] = true;
              request.headers['Authorization'] =
                  'Bearer ${refreshed.accessToken}';
              try {
                return handler.resolve(await client.dio.fetch(request));
              } on DioException catch (retryError) {
                return handler.next(retryError);
              }
            }
          }
          handler.next(error);
        },
      ),
    );
    return client;
  }

  ApiClient._(this._sessionManager, this.dio);

  final Dio dio;

  String? get currentUserId => _sessionManager.current?.userId;
  final SessionManager _sessionManager;

  Future<Map<String, Object?>> getJson(
    String path, {
    Duration? receiveTimeout,
  }) async {
    try {
      final response = await dio.get<Map<String, Object?>>(
        path,
        options: Options(receiveTimeout: receiveTimeout),
      );
      return response.data ?? <String, Object?>{};
    } on Object catch (error) {
      throw ErrorMapper.from(error);
    }
  }

  Future<List<Map<String, Object?>>> getJsonList(String path) async {
    try {
      final response = await dio.get<List<Object?>>(path);
      return (response.data ?? const [])
          .map((item) => Map<String, Object?>.from(item! as Map))
          .toList(growable: false);
    } on Object catch (error) {
      throw ErrorMapper.from(error);
    }
  }

  Future<Map<String, Object?>> postJson(
    String path, {
    required Map<String, Object?> data,
    bool authenticated = true,
    String? idempotencyKey,
    CancelToken? cancelToken,
    Duration? receiveTimeout,
  }) async {
    try {
      final response = await dio.post<Map<String, Object?>>(
        path,
        data: data,
        cancelToken: cancelToken,
        options: Options(
          receiveTimeout: receiveTimeout,
          headers: idempotencyKey == null
              ? null
              : {'Idempotency-Key': idempotencyKey},
          extra: {'skipAuth': !authenticated},
        ),
      );
      return response.data ?? <String, Object?>{};
    } on Object catch (error) {
      throw ErrorMapper.from(error);
    }
  }

  Future<Map<String, Object?>?> postNullableJson(
    String path, {
    required Map<String, Object?> data,
  }) async {
    try {
      final response = await dio.post<Object?>(path, data: data);
      final value = response.data;
      return value == null ? null : Map<String, Object?>.from(value as Map);
    } on Object catch (error) {
      throw ErrorMapper.from(error);
    }
  }

  Future<void> putEmpty(String path) async {
    try {
      await dio.put<void>(path);
    } on Object catch (error) {
      throw ErrorMapper.from(error);
    }
  }

  Future<Map<String, Object?>> putJson(
    String path, {
    required Map<String, Object?> data,
    String? idempotencyKey,
  }) async {
    try {
      final response = await dio.put<Map<String, Object?>>(
        path,
        data: data,
        options: Options(
          headers: idempotencyKey == null
              ? null
              : {'Idempotency-Key': idempotencyKey},
        ),
      );
      return response.data ?? <String, Object?>{};
    } on Object catch (error) {
      throw ErrorMapper.from(error);
    }
  }

  Future<Map<String, Object?>> patchJson(
    String path, {
    required Map<String, Object?> data,
    String? idempotencyKey,
  }) async {
    try {
      final response = await dio.patch<Map<String, Object?>>(
        path,
        data: data,
        options: Options(
          headers: idempotencyKey == null
              ? null
              : {'Idempotency-Key': idempotencyKey},
        ),
      );
      return response.data ?? <String, Object?>{};
    } on Object catch (error) {
      throw ErrorMapper.from(error);
    }
  }

  Future<void> delete(String path, {String? idempotencyKey}) async {
    try {
      await dio.delete<void>(
        path,
        options: Options(
          headers: idempotencyKey == null
              ? null
              : {'Idempotency-Key': idempotencyKey},
        ),
      );
    } on Object catch (error) {
      throw ErrorMapper.from(error);
    }
  }
}

Session sessionFromJson(Map<String, Object?> json) => Session(
  id: json['session_id']! as String,
  userId: json['user_id']! as String,
  accessToken: json['access_token']! as String,
  refreshToken: json['refresh_token']! as String,
  accessTokenExpiresAt: DateTime.parse(
    json['access_token_expires_at']! as String,
  ).toUtc(),
  createdAt: DateTime.parse(json['created_at']! as String).toUtc(),
);
