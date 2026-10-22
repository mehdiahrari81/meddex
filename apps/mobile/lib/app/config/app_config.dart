import 'package:flutter/foundation.dart';

enum AppEnvironment { development, testing, production }

class AppConfig {
  const AppConfig({
    required this.environment,
    required this.apiBaseUrl,
    required this.enableDebugLogs,
  });

  factory AppConfig.fromEnvironment() {
    const environmentName = String.fromEnvironment(
      'APP_ENV',
      defaultValue: 'development',
    );
    final environment = AppEnvironment.values.firstWhere(
      (value) => value.name == environmentName,
      orElse: () => AppEnvironment.development,
    );
    const rawBaseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: '');
    final uri = Uri.parse(
      rawBaseUrl.isNotEmpty
          ? rawBaseUrl
          : defaultApiBaseUrl(defaultTargetPlatform).toString(),
    );
    if (environment == AppEnvironment.production && uri.scheme != 'https') {
      throw const FormatException('Production API_BASE_URL must use HTTPS.');
    }
    return AppConfig(
      environment: environment,
      apiBaseUrl: uri,
      enableDebugLogs: environment != AppEnvironment.production,
    );
  }

  final AppEnvironment environment;
  final Uri apiBaseUrl;
  final bool enableDebugLogs;
}

Uri defaultApiBaseUrl(TargetPlatform platform) => Uri.parse(
  platform == TargetPlatform.android
      ? 'http://10.0.2.2:8000/api/v1/'
      : 'http://127.0.0.1:8000/api/v1/',
);
