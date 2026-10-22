import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediexplain/core/network/api_client.dart';
import 'package:mediexplain/core/errors/app_error.dart';
import 'package:mediexplain/core/storage/session_vault.dart';
import 'package:mediexplain/domain/models/confidence_result.dart';
import 'package:mediexplain/domain/models/session.dart';
import 'package:mediexplain/features/prescription/data/api_prescription_text_structurer.dart';
import 'package:mediexplain/features/prescription/domain/prescription_models.dart';

void main() {
  late SessionManager manager;
  late _Adapter adapter;
  late ApiPrescriptionTextStructurer structurer;
  setUp(() async {
    manager = SessionManager(
      refreshClient: Dio(),
      vault: _Vault(),
      baseUrl: Uri.parse('https://api.test/api/v1/'),
    );
    await manager.set(
      Session(
        id: 'session',
        userId: 'owner',
        accessToken: 'access',
        refreshToken: 'refresh',
        accessTokenExpiresAt: DateTime.now().add(const Duration(minutes: 10)),
        createdAt: DateTime.now(),
      ),
    );
    adapter = _Adapter();
    final dio = Dio(BaseOptions(baseUrl: 'https://api.test/api/v1/'))
      ..httpClientAdapter = adapter;
    structurer = ApiPrescriptionTextStructurer(
      ApiClient(
        baseUrl: Uri.parse(dio.options.baseUrl),
        sessionManager: manager,
        dio: dio,
      ),
    );
  });

  test(
    'sends complete text only and maps medicine fields without confirmation or guessing',
    () async {
      final result = await structurer.structure(
        prescriptionId: 'rx',
        pages: [
          (pageNumber: 2, text: 'Patient: Synthetic QA\nAmoxici1lin 5O mg'),
        ],
      );
      expect(adapter.request!.path, 'prescription-ocr/structure');
      expect(adapter.request!.headers['Authorization'], 'Bearer access');
      final body = adapter.request!.data as Map;
      expect(body['cloud_consent'], isTrue);
      expect(
        (body['pages'] as List).single['text'],
        startsWith('Patient: Synthetic QA'),
      );
      expect(body.keys, unorderedEquals(['cloud_consent', 'pages']));
      final item = result.items.single;
      expect(item.pageNumber, 2);
      expect(item.lineNumber, 1);
      expect(
        item.field(PrescriptionFieldType.medicationName).currentValue,
        'Amoxici1lin',
      );
      expect(
        item.field(PrescriptionFieldType.medicationName).ambiguous,
        isTrue,
      );
      expect(
        item.fields.values.every(
          (f) => !f.userConfirmed && f.confidence == ConfidenceBand.unknown,
        ),
        isTrue,
      );
      expect(item.field(PrescriptionFieldType.dose).hasValue, isFalse);
      expect(item.state, PrescriptionItemState.needsReview);
      expect(result.parserVersion, 'gemini-text-v2:gemini-3.5-flash-lite');
    },
  );

  test('Groq failover retains actual provider and model provenance', () async {
    adapter.provider = 'groq';
    adapter.model = 'openai/gpt-oss-120b';
    final result = await structurer.structure(
      prescriptionId: 'rx',
      pages: [(pageNumber: 2, text: 'Amoxici1lin 5O mg')],
    );
    expect(result.parserVersion, 'groq-text-v2:openai/gpt-oss-120b');
    expect(result.items.single.state, PrescriptionItemState.needsReview);
    expect(
      result.items.single.fields.values.every((f) => !f.userConfirmed),
      isTrue,
    );
  });

  test('guest never uploads prescription text', () async {
    await manager.clear();
    await expectLater(
      structurer.structure(
        prescriptionId: 'rx',
        pages: [(pageNumber: 1, text: 'private')],
      ),
      throwsA(isA<AuthenticationExpiredError>()),
    );
    expect(adapter.request, isNull);
  });

  test('late response cannot be used after logout', () async {
    adapter.beforeResponse = manager.clear;
    await expectLater(
      structurer.structure(
        prescriptionId: 'rx',
        pages: [(pageNumber: 1, text: 'private')],
      ),
      throwsA(anything),
    );
  });
}

class _Adapter implements HttpClientAdapter {
  String provider = 'gemini';
  String model = 'gemini-3.5-flash-lite';
  RequestOptions? request;
  Future<void> Function()? beforeResponse;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    request = options;
    await beforeResponse?.call();
    return ResponseBody.fromString(
      jsonEncode({
        'provider': provider,
        'model': model,
        'requires_review': true,
        'ignored_line_count': 1,
        'medicines': [
          {
            'name': 'Amoxici1lin',
            'page_number': 2,
            'line_numbers': [2],
            'strength': '5O mg',
            'dosage_form': null,
            'dose': null,
            'route': null,
            'frequency': null,
            'duration': null,
            'instructions': null,
            'uncertain_fields': ['name', 'strength'],
            'source_text': 'Amoxici1lin 5O mg',
            'requires_review': true,
          },
        ],
      }),
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
