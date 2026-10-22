import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediexplain/core/network/development_server.dart';
import 'package:mediexplain/app/config/app_config.dart';
import 'package:mediexplain/features/auth/application/auth_controller.dart';
import 'package:mediexplain/features/settings/application/settings_controller.dart';
import 'package:mediexplain/features/settings/data/settings_repository.dart';
import 'package:mediexplain/features/settings/domain/app_settings.dart';

class _Preferences implements SettingsRepository {
  AppSettings value = const AppSettings.defaults().copyWith(
    developmentServerUrl: 'http://192.168.100.59:8000/api/v1/',
  );
  @override
  Future<AppSettings> load() async => value;
  @override
  Future<void> save(AppSettings next) async {
    value = next;
  }

  @override
  Future<void> resetOnboarding() async {}
  @override
  Future<void> clearLocalPreferences() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('accepts trusted LAN URLs and normalizes the API path', () {
    for (final host in [
      '192.168.100.59',
      '10.0.0.8',
      '172.16.2.3',
      'mac.local',
    ]) {
      expect(
        validateDevelopmentServerUrl('http://$host:8000').toString(),
        'http://$host:8000/api/v1/',
      );
    }
    expect(
      validateDevelopmentServerUrl('https://api.example.com/api/v1/').scheme,
      'https',
    );
    for (final invalid in [
      'http://8.8.8.8:8000',
      'http://169.254.1.2:8000',
      'http://127.0.0.1:8000',
      'ftp://mac.local',
      'https://user:password@api.example.com',
      'https://api.example.com?key=secret',
      'https://api.example.com/#x',
      'https://api.example.com/wrong',
      'not a URL',
    ]) {
      expect(
        () => validateDevelopmentServerUrl(invalid),
        throwsFormatException,
        reason: invalid,
      );
    }
  });
  for (final status in [200, 302, 503]) {
    test(
      'readiness check is anonymous and rejects non-ready responses ($status)',
      () async {
        final http = Dio()
          ..interceptors.add(
            InterceptorsWrapper(
              onRequest: (request, handler) {
                expect(
                  request.uri.toString(),
                  'http://192.168.100.59:8000/api/v1/ready',
                );
                expect(request.followRedirects, isFalse);
                expect(
                  request.headers.keys.map((k) => k.toLowerCase()),
                  isNot(contains('authorization')),
                );
                handler.resolve(
                  Response(
                    requestOptions: request,
                    statusCode: status,
                    data: {'status': 'ready'},
                  ),
                );
              },
            ),
          );
        final request = checkDevelopmentServer(
          Uri.parse('http://192.168.100.59:8000/api/v1/'),
          client: http,
        );
        if (status == 200) {
          await request;
        } else {
          await expectLater(request, throwsFormatException);
        }
        http.close(force: true);
      },
    );
  }
  test(
    'saved address configures both API and refresh clients without reacting to unrelated settings',
    () async {
      final container = ProviderContainer(
        overrides: [
          settingsRepositoryProvider.overrideWithValue(_Preferences()),
        ],
      );
      try {
        await container.read(settingsControllerProvider.future);
        expect(
          container.read(appConfigProvider).apiBaseUrl.host,
          '192.168.100.59',
        );
        final firstManager = container.read(sessionManagerProvider);
        await container
            .read(settingsControllerProvider.notifier)
            .persist((s) => s.copyWith(notificationsEnabled: false));
        expect(
          identical(container.read(sessionManagerProvider), firstManager),
          isTrue,
        );
        await container
            .read(settingsControllerProvider.notifier)
            .persist(
              (s) => s.copyWith(
                developmentServerUrl: 'http://192.168.100.60:8000/api/v1/',
              ),
            );
        expect(
          container.read(appConfigProvider).apiBaseUrl.host,
          '192.168.100.60',
        );
        expect(
          identical(container.read(sessionManagerProvider), firstManager),
          isFalse,
        );
        expect(
          container.read(apiClientProvider).dio.options.baseUrl,
          'http://192.168.100.60:8000/api/v1/',
        );
      } finally {
        container.dispose();
      }
    },
  );
  test(
    'automatic mode replaces old LAN pins and manual mode remains explicit',
    () async {
      final preferences = _Preferences();
      final container = ProviderContainer(
        overrides: [
          settingsRepositoryProvider.overrideWithValue(preferences),
          bundledAppConfigProvider.overrideWithValue(
            AppConfig(
              environment: AppEnvironment.development,
              apiBaseUrl: Uri.parse('http://my-mac.local:8000/api/v1/'),
              enableDebugLogs: false,
            ),
          ),
        ],
      );
      try {
        await container.read(settingsControllerProvider.future);
        expect(
          container.read(appConfigProvider).apiBaseUrl.host,
          'my-mac.local',
        );
        expect(
          container.read(apiClientProvider).dio.options.baseUrl,
          'http://my-mac.local:8000/api/v1/',
        );
        await container
            .read(settingsControllerProvider.notifier)
            .setDevelopmentServerUrl('http://10.0.0.9:8000/api/v1/');
        expect(container.read(appConfigProvider).apiBaseUrl.host, '10.0.0.9');
        expect(preferences.value.automaticServerConnection, isFalse);
        await container
            .read(settingsControllerProvider.notifier)
            .setDevelopmentServerUrl('', automatic: true);
        expect(
          container.read(appConfigProvider).apiBaseUrl.host,
          'my-mac.local',
        );
        expect(preferences.value.automaticServerConnection, isTrue);
      } finally {
        container.dispose();
      }
    },
  );
}
