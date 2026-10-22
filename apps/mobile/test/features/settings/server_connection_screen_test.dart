import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediexplain/app/config/app_config.dart';
import 'package:mediexplain/features/auth/application/auth_controller.dart';
import 'package:mediexplain/features/settings/application/settings_controller.dart';
import 'package:mediexplain/features/settings/data/settings_repository.dart';
import 'package:mediexplain/features/settings/domain/app_settings.dart';
import 'package:mediexplain/features/settings/presentation/settings_screen.dart';
import 'package:mediexplain/features/settings/presentation/server_connection_dialog.dart';
import 'package:mediexplain/l10n/app_localizations.dart';

class _Preferences implements SettingsRepository {
  AppSettings value = const AppSettings.defaults();
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
  testWidgets(
    'server connection checks before saving, retains old address on failure, then persists retry',
    (tester) async {
      final preferences = _Preferences();
      var checks = 0;
      final container = ProviderContainer(
        overrides: [
          settingsRepositoryProvider.overrideWithValue(preferences),
          appConfigProvider.overrideWithValue(
            AppConfig(
              environment: AppEnvironment.development,
              apiBaseUrl: Uri.parse('http://192.168.63.106:8000/api/v1/'),
              enableDebugLogs: false,
            ),
          ),
          developmentServerCheckProvider.overrideWithValue((uri) async {
            checks++;
            expect(uri.host, '192.168.100.59');
            if (checks == 1) throw StateError('Synthetic unreachable server');
          }),
        ],
      );
      try {
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              localizationsDelegates: const [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
              ],
              supportedLocales: AppLocalizations.supportedLocales,
              home: const SettingsScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Server connection'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), 'http://8.8.8.8:8000');
        await tester.tap(find.widgetWithText(FilledButton, 'Test and save'));
        await tester.pumpAndSettle();
        expect(checks, 0);
        expect(preferences.value.developmentServerUrl, isEmpty);
        await tester.enterText(
          find.byType(TextField),
          'http://192.168.100.59:8000',
        );
        await tester.tap(find.widgetWithText(FilledButton, 'Test and save'));
        await tester.pumpAndSettle();
        expect(
          find.textContaining('Could not verify the server'),
          findsOneWidget,
        );
        expect(preferences.value.developmentServerUrl, isEmpty);
        await tester.tap(find.widgetWithText(FilledButton, 'Test and save'));
        await tester.pumpAndSettle();
        expect(
          preferences.value.developmentServerUrl,
          'http://192.168.100.59:8000/api/v1/',
        );
        expect(find.byType(AlertDialog), findsNothing);
        expect(
          find.textContaining('Server connection updated'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox());
        container.dispose();
      }
    },
  );
  testWidgets(
    'automatic connection verifies hostname and removes the old IP pin',
    (tester) async {
      final preferences = _Preferences()
        ..value = const AppSettings.defaults().copyWith(
          developmentServerUrl: 'http://192.168.1.20:8000/api/v1/',
          automaticServerConnection: false,
        );
      var checks = 0;
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
          developmentServerCheckProvider.overrideWithValue((uri) async {
            checks++;
            expect(uri.toString(), 'http://my-mac.local:8000/api/v1/');
          }),
        ],
      );
      try {
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              localizationsDelegates: const [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
              ],
              supportedLocales: AppLocalizations.supportedLocales,
              home: const SettingsScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Server connection'));
        await tester.pumpAndSettle();
        await tester.tap(find.byType(SwitchListTile));
        await tester.pumpAndSettle();
        expect(
          tester.widget<TextField>(find.byType(TextField)).enabled,
          isFalse,
        );
        await tester.tap(find.widgetWithText(FilledButton, 'Test and save'));
        await tester.pumpAndSettle();
        expect(checks, 1);
        expect(preferences.value.developmentServerUrl, isEmpty);
        expect(preferences.value.automaticServerConnection, isTrue);
        expect(
          container.read(appConfigProvider).apiBaseUrl.host,
          'my-mac.local',
        );
        expect(find.byType(AlertDialog), findsNothing);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox());
        container.dispose();
      }
    },
  );
}
