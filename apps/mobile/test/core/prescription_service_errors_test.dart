import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediexplain/core/errors/app_error.dart';
import 'package:mediexplain/core/errors/error_mapper.dart';
import 'package:mediexplain/features/prescription/application/prescription_error_message.dart';

void main() {
  test('Google high demand has specific recovery guidance', () {
    final request = RequestOptions(path: 'prescription-ocr/handwriting/gemini');
    final error = ErrorMapper.from(
      DioException(
        requestOptions: request,
        response: Response(
          requestOptions: request,
          statusCode: 503,
          data: {
            'error': {'code': 'gemini_temporarily_busy'},
          },
        ),
      ),
    );
    expect(error, isA<PrescriptionServiceError>());
    expect(prescriptionErrorMessage(error), contains('reader is busy'));
    expect(prescriptionErrorMessage(error), contains('image is saved'));
    expect(prescriptionErrorMessage(error), isNot(contains('usage limit')));
  });

  test(
    'quota responses preserve the actionable code without displaying upstream detail',
    () {
      final request = RequestOptions(path: 'prescription-ocr/structure');
      final mapped = ErrorMapper.from(
        DioException(
          requestOptions: request,
          response: Response(
            requestOptions: request,
            statusCode: 503,
            data: {
              'error': {
                'code': 'gemini_limit_reached',
                'message': 'private upstream detail',
              },
            },
          ),
        ),
      );
      expect(mapped, isA<PrescriptionServiceError>());
      expect(prescriptionErrorMessage(mapped), contains('usage limit'));
      expect(
        prescriptionErrorMessage(mapped),
        isNot(contains('private upstream')),
      );
    },
  );

  for (final code in ['cloud_limit_reached', 'cloud_temporarily_unavailable']) {
    test('$code preserves a saved scan and offers recovery', () {
      final request = RequestOptions(
        path: 'prescription-ocr/handwriting/gemini',
      );
      final error = ErrorMapper.from(
        DioException(
          requestOptions: request,
          response: Response(
            requestOptions: request,
            statusCode: 503,
            data: {
              'error': {'code': code, 'message': 'private upstream detail'},
            },
          ),
        ),
      );
      expect(error, isA<PrescriptionServiceError>());
      final message = prescriptionErrorMessage(error);
      expect(message, contains('scan is saved'));
      expect(message, contains('cloud readers'));
      expect(message, isNot(contains('private upstream')));
    });
  }

  test(
    'network, timeout and expired session failures have different recovery instructions',
    () {
      expect(
        prescriptionErrorMessage(const NetworkUnavailableError()),
        contains('same Wi-Fi'),
      );
      expect(
        prescriptionErrorMessage(const RequestTimeoutError()),
        contains('too long'),
      );
      expect(
        prescriptionErrorMessage(const AuthenticationExpiredError()),
        contains('Sign in again'),
      );
    },
  );
}
