import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediexplain/core/network/api_client.dart';
import 'package:mediexplain/core/errors/app_error.dart';
import 'package:mediexplain/features/prescription/data/server_handwriting_ocr_provider.dart';
import 'package:mediexplain/features/prescription/domain/prescription_providers.dart';
import 'package:mediexplain/core/storage/session_vault.dart';
import 'package:mediexplain/domain/models/session.dart';

void main() {
  test(
    'automatic Gemini scanning requires sign-in before reading or uploading an image',
    () async {
      final manager = SessionManager(
        refreshClient: Dio(),
        vault: _Vault(),
        baseUrl: Uri.parse('https://api.example.test/api/v1/'),
      );
      final adapter = _ImageAdapter();
      final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test/api/v1/'))
        ..httpClientAdapter = adapter;
      final api = ApiClient(
        baseUrl: Uri.parse(dio.options.baseUrl),
        sessionManager: manager,
        dio: dio,
      );
      await expectLater(
        ServerHandwritingOcrProvider(api, useGemini: true).recognize(
          const ImageReference(
            privateId: 'private',
            localPath: '/not-read-without-auth.jpg',
            pageNumber: 1,
          ),
        ),
        throwsA(isA<AuthenticationExpiredError>()),
      );
      expect(adapter.options, isNull);
    },
  );

  for (final useGemini in [false, true]) {
    test(
      'handwriting sends authenticated pixels; Gemini image consent=$useGemini',
      () async {
        final manager = SessionManager(
          refreshClient: Dio(),
          vault: _Vault(),
          baseUrl: Uri.parse('https://api.example.test/api/v1/'),
        );
        await manager.set(
          Session(
            id: 'session',
            userId: 'owner',
            accessToken: 'access',
            refreshToken: 'refresh',
            accessTokenExpiresAt: DateTime.now().add(
              const Duration(minutes: 10),
            ),
            createdAt: DateTime.now(),
          ),
        );
        final adapter = _ImageAdapter();
        final dio = Dio(
          BaseOptions(baseUrl: 'https://api.example.test/api/v1/'),
        )..httpClientAdapter = adapter;
        final api = ApiClient(
          baseUrl: Uri.parse(dio.options.baseUrl),
          sessionManager: manager,
          dio: dio,
        );
        final result = await api.recognizeHandwriting([
          255,
          216,
          0,
          128,
        ], useGemini: useGemini);
        expect(
          adapter.options!.path,
          useGemini
              ? 'prescription-ocr/handwriting/gemini'
              : 'prescription-ocr/handwriting',
        );
        expect(
          adapter.options!.headers['X-Cloud-Consent'],
          useGemini ? 'true' : isNull,
        );
        expect(adapter.bytes, [255, 216, 0, 128]);
        expect(adapter.options!.headers['Authorization'], 'Bearer access');
        expect(adapter.options!.contentType, 'image/jpeg');
        expect(adapter.options!.sendTimeout, const Duration(seconds: 60));
        expect(adapter.options!.receiveTimeout, const Duration(seconds: 120));
        expect(adapter.options!.extra['expectedUserId'], 'owner');
        expect(result['requires_review'], isTrue);
      },
    );
  }
  for (final type in [
    DioExceptionType.sendTimeout,
    DioExceptionType.receiveTimeout,
  ]) {
    test(
      'image upload and response timeouts remain distinguishable: $type',
      () async {
        final manager = SessionManager(
          refreshClient: Dio(),
          vault: _Vault(),
          baseUrl: Uri.parse('https://api.example.test/api/v1/'),
        );
        final dio =
            Dio(BaseOptions(baseUrl: 'https://api.example.test/api/v1/'))
              ..interceptors.add(
                InterceptorsWrapper(
                  onRequest: (options, handler) {
                    handler.reject(
                      DioException(requestOptions: options, type: type),
                    );
                  },
                ),
              );
        final api = ApiClient(
          baseUrl: Uri.parse(dio.options.baseUrl),
          sessionManager: manager,
          dio: dio,
        );
        await expectLater(
          api.recognizeHandwriting([255, 216]),
          throwsA(
            type == DioExceptionType.sendTimeout
                ? isA<PrescriptionServiceError>().having(
                    (e) => e.code,
                    'code',
                    'image_upload_interrupted',
                  )
                : isA<RequestTimeoutError>(),
          ),
        );
        dio.close(force: true);
        manager.dispose();
      },
    );
  }
}

class _ImageAdapter implements HttpClientAdapter {
  List<int> bytes = [];
  RequestOptions? options;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    this.options = options;
    await for (final part in requestStream!) {
      bytes.addAll(part);
    }
    return ResponseBody.fromString(
      jsonEncode({'text': 'uncertain', 'requires_review': true}),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _Vault implements SessionVault {
  Session? value;
  @override
  Future<void> clear() async => value = null;
  @override
  Future<Session?> read() async => value;
  @override
  Future<void> write(Session session) async => value = session;
}
