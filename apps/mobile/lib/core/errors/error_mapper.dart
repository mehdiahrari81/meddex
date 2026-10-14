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
      if (status == 422) return ValidationError(cause: error);
      if (status == 429) return RateLimitedError(cause: error);
      if (status != null && status >= 500) {
        return ServerError(statusCode: status, cause: error);
      }
    }
    return UnknownAppError(cause: error);
  }
}
