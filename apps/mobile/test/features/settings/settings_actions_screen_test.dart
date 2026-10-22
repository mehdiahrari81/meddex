import 'dart:async';
import 'package:drift/native.dart';
import 'package:mediexplain/core/database/app_database.dart';
import 'package:mediexplain/core/database/database_provider.dart';
import 'package:mediexplain/core/sync/sync_coordinator.dart';
import 'package:mediexplain/core/sync/sync_provider.dart';
import 'package:mediexplain/features/learning/data/local_learning_repository.dart';
import 'package:mediexplain/features/prescription/data/private_image_store.dart';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:mediexplain/features/profile/presentation/profile_screen.dart';
import 'package:mediexplain/app/router/app_router.dart';
import 'package:mediexplain/app/router/app_routes.dart';
import 'package:mediexplain/design_system/app_theme.dart';
import 'package:mediexplain/domain/models/session.dart';
import 'package:mediexplain/features/auth/application/auth_controller.dart';
import 'package:mediexplain/features/auth/presentation/sessions_screen.dart';
import 'package:mediexplain/features/settings/application/data_management.dart';
import 'package:mediexplain/features/settings/application/settings_controller.dart';
import 'package:mediexplain/features/settings/data/settings_repository.dart';
import 'package:mediexplain/features/settings/domain/app_settings.dart';
import 'package:mediexplain/features/settings/presentation/app_information_screen.dart';
import 'package:mediexplain/features/settings/presentation/settings_screen.dart';
import 'package:mediexplain/l10n/app_localizations.dart';

class _Deletion extends Mock implements AccountDeletionService {}

class _Preferences implements SettingsRepository {
  AppSettings settings = const AppSettings.defaults().copyWith(
    onboardingComplete: true,
    lastUsefulLocation: '/profile/settings',
  );
  @override
  Future<AppSettings> load() async => settings;
  @override
  Future<void> save(AppSettings value) async {
    settings = value;
  }

  @override
  Future<void> resetOnboarding() async {}
  @override
  Future<void> clearLocalPreferences() async {
    settings = const AppSettings.defaults();
  }
}

class _Auth extends AuthController {
  @override
  Future<AuthState> build() async => AuthState.authenticated(
    Session(
      id: 'qa-session',
      userId: 'qa-user',
      accessToken: 'qa',
      refreshToken: 'qa',
      accessTokenExpiresAt: DateTime.now().add(const Duration(hours: 1)),
      createdAt: DateTime.now(),
    ),
  );
}

Widget localized(Widget child, {bool urdu = false, double scale = 1}) =>
    MaterialApp(
      locale: Locale(urdu ? 'ur' : 'en'),
      theme: AppTheme.light(),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: child,
    );
Future<void> tapSetting(WidgetTester tester, String label) async {
  tester
      .state<ScrollableState>(find.byType(Scrollable).first)
      .position
      .jumpTo(0);
  await tester.pumpAndSettle();
  await tester.scrollUntilVisible(
    find.text(label),
    400,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.ensureVisible(find.text(label));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'Settings opens pages and dispatches confirmed account deletion',
    (tester) async {
      var accountDeletions = 0;
      final deletion = _Deletion();
      when(() => deletion.delete()).thenAnswer((_) async {
        accountDeletions++;
      });
      final container = ProviderContainer(
        overrides: [
          settingsRepositoryProvider.overrideWithValue(_Preferences()),
          authControllerProvider.overrideWith(_Auth.new),
          accountDeletionServiceProvider.overrideWithValue(deletion),
          accountSessionsProvider.overrideWith((ref) async => []),
        ],
      );
      try {
        await container.read(settingsControllerProvider.future);
        await container.read(authControllerProvider.future);
        final router = container.read(appRouterProvider);
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp.router(
              routerConfig: router,
              theme: AppTheme.light(),
              localizationsDelegates: const [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
              ],
              supportedLocales: AppLocalizations.supportedLocales,
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tapSetting(tester, 'Manage sessions');
        expect(find.byType(SessionsScreen), findsOneWidget);
        router.pop();
        await tester.pumpAndSettle();
        for (final (label, _) in [
          ('Privacy policy', AppRoute.privacyPolicy.path),
          ('Terms', AppRoute.terms.path),
          ('Data sources', AppRoute.dataSources.path),
        ]) {
          await tapSetting(tester, label);
          expect(find.byType(AppInformationScreen), findsOneWidget);
          expect(find.byType(SelectableText), findsWidgets);
          expect(find.text('Coming in a later module'), findsNothing);
          router.pop();
          await tester.pumpAndSettle();
          expect(find.byType(SettingsScreen), findsOneWidget);
        }
        await tapSetting(tester, 'Delete account');
        await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
        await tester.pumpAndSettle();
        expect(accountDeletions, 0);
        await tapSetting(tester, 'Delete account');
        await tester.tap(find.widgetWithText(FilledButton, 'Delete account'));
        await tester.pumpAndSettle();
        expect(accountDeletions, 1);
        expect(find.byType(ProfileScreen), findsOneWidget);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox());
        container.dispose();
      }
    },
  );

  testWidgets(
    'local deletion can cancel, prevents double taps and retries an error',
    (tester) async {
      var attempts = 0;
      final pending = Completer<void>();
      final container = ProviderContainer(
        overrides: [
          settingsRepositoryProvider.overrideWithValue(_Preferences()),
          clearLocalProfileProvider.overrideWithValue(() async {
            attempts++;
            if (attempts == 1) {
              await pending.future;
              throw StateError('Synthetic deletion failure');
            }
          }),
        ],
      );
      try {
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: localized(const SettingsScreen()),
          ),
        );
        await tester.pumpAndSettle();
        await tapSetting(tester, 'Manage saved data');
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect(attempts, 0);
        await tapSetting(tester, 'Manage saved data');
        await tester.tap(
          find.widgetWithText(FilledButton, 'Delete local data'),
        );
        await tester.pump();
        expect(attempts, 1);
        expect(
          tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
          isNull,
        );
        expect(
          tester
              .widget<TextButton>(find.widgetWithText(TextButton, 'Cancel'))
              .onPressed,
          isNull,
        );
        pending.complete();
        await tester.pumpAndSettle();
        expect(
          find.textContaining('Deletion could not finish'),
          findsOneWidget,
        );
        expect(find.text('Local data was deleted.'), findsNothing);
        await tester.tap(find.widgetWithText(FilledButton, 'Try again'));
        await tester.pumpAndSettle();
        expect(attempts, 2);
        expect(find.byType(AlertDialog), findsNothing);
        expect(find.text('Local data was deleted.'), findsOneWidget);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox());
        container.dispose();
      }
    },
  );

  testWidgets(
    'confirmed Settings reset clears the real local database and resets preferences',
    (tester) async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      final sync = SyncCoordinator(
        database: database,
        transport: const DisabledSyncTransport(),
      );
      final preferences = _Preferences();
      await LocalLearningRepository(
        database,
        sync,
      ).recordMeaningfulActivity(DateTime.now());
      var notificationsCancelled = false;
      final deletionDone = Completer<void>();
      final container = ProviderContainer(
        overrides: [
          clearLocalProfileProvider.overrideWith(
            (ref) => () async {
              try {
                await eraseCurrentProfile(ref);
              } finally {
                deletionDone.complete();
              }
            },
          ),
          databaseProvider.overrideWithValue(database),
          syncCoordinatorProvider.overrideWithValue(sync),
          settingsRepositoryProvider.overrideWithValue(preferences),
          localUserDataEraserProvider.overrideWithValue(
            LocalUserDataEraser(
              database: database,
              images: PrivatePrescriptionImageStore(),
              preferences: preferences,
              cancelNotifications: () async {
                notificationsCancelled = true;
              },
              clearTemporaryFiles: () async {},
            ),
          ),
        ],
      );
      try {
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: localized(const SettingsScreen()),
          ),
        );
        await tester.pumpAndSettle();
        await tapSetting(tester, 'Manage saved data');
        await tester.tap(
          find.widgetWithText(FilledButton, 'Delete local data'),
        );
        await tester.runAsync(
          () => deletionDone.future.timeout(const Duration(seconds: 10)),
        );
        await tester.pumpAndSettle();
        expect(find.text('Local data was deleted.'), findsOneWidget);
        expect(
          await tester.runAsync(
            () => database.select(database.learningStreaks).get(),
          ),
          isEmpty,
        );
        expect(notificationsCancelled, isTrue);
        expect(preferences.settings.onboardingComplete, isFalse);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox());
        container.dispose();
        sync.dispose();
        await tester.runAsync(database.close);
      }
    },
  );

  for (final page in AppInformationPage.values) {
    testWidgets('${page.name} content wraps at large text size in Urdu', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        localized(AppInformationScreen(page: page), urdu: true, scale: 2),
      );
      await tester.pumpAndSettle();
      final text = find.byType(SelectableText).first;
      expect(Directionality.of(tester.element(text)), TextDirection.rtl);
      expect(tester.takeException(), isNull);
    });
  }
}
