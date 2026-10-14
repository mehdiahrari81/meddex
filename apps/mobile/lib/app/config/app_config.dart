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
    const rawBaseUrl = String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: 'http://10.0.2.2:8000/api/v1/',
    );
    final uri = Uri.parse(rawBaseUrl);
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
