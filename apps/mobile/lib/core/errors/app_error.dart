sealed class AppError implements Exception {
  const AppError(this.code, {this.cause});

  final String code;
  final Object? cause;
}

final class NetworkUnavailableError extends AppError {
  const NetworkUnavailableError({super.cause}) : super('network_unavailable');
}

final class RequestTimeoutError extends AppError {
  const RequestTimeoutError({super.cause}) : super('request_timeout');
}

final class AuthenticationExpiredError extends AppError {
  const AuthenticationExpiredError({super.cause})
    : super('authentication_expired');
}

final class ServerError extends AppError {
  const ServerError({this.statusCode, super.cause}) : super('server_error');
  final int? statusCode;
}

final class RateLimitedError extends AppError {
  const RateLimitedError({this.retryAfter, super.cause})
    : super('rate_limited');
  final Duration? retryAfter;
}

final class ValidationError extends AppError {
  const ValidationError({this.fields = const {}, super.cause})
    : super('validation_error');
  final Map<String, String> fields;
}

final class LocalDatabaseError extends AppError {
  const LocalDatabaseError({super.cause}) : super('local_database_error');
}

final class SynchronizationError extends AppError {
  const SynchronizationError({super.cause}) : super('synchronization_error');
}

final class ExternalProviderError extends AppError {
  const ExternalProviderError({super.cause}) : super('external_provider_error');
}

final class UnknownAppError extends AppError {
  const UnknownAppError({super.cause}) : super('unknown_error');
}
