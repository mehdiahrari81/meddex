import 'package:dio/dio.dart';

import 'app_error.dart';

abstract final class ErrorMapper {
  static AppError from(Object error) {
    if (error is AppError) return error;
    if (error is DioException) {
      if (error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.receiveTimeout ||
          error.type == DioExceptionType.sendTimeout) {
        return RequestTimeoutError(cause: error);
      }
      if (error.type == DioExceptionType.connectionError) {
        return NetworkUnavailableError(cause: error);
      }
      final status = error.response?.statusCode;
      if (status == 401) return AuthenticationExpiredError(cause: error);
      final body = error.response?.data;
      if (body is Map && body['error'] is Map) {
        final code = (body['error'] as Map)['code'];
        if (const {
          'image_upload_interrupted',
          'gemini_limit_reached',
          'cloud_limit_reached',
          'cloud_temporarily_unavailable',
          'medicine_extraction_unavailable',
          'medicine_extraction_unverified',
          'medicine_information_unavailable',
          'gemini_handwriting_unavailable',
          'gemini_request_timeout',
          'gemini_temporarily_busy',
        }.contains(code)) {
          return PrescriptionServiceError(code as String, cause: error);
        }
      }
      if (status == 409 &&
          body is Map &&
          body['error'] is Map &&
          (body['error'] as Map)['code'] == 'email_exists') {
        return AccountExistsError(cause: error);
      }
      if (status == 422) return ValidationError(cause: error);
      if (status == 429) return RateLimitedError(cause: error);
      if (status != null && status >= 500) {
        return ServerError(statusCode: status, cause: error);
      }
    }
    return UnknownAppError(cause: error);
  }
}
