import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mediexplain/app/router/app_routes.dart';
import 'package:mediexplain/core/network/api_client.dart';
import 'package:mediexplain/domain/models/session.dart';
import 'package:mediexplain/features/auth/application/auth_controller.dart';
import 'package:mediexplain/features/auth/presentation/sessions_screen.dart';
import 'package:mediexplain/l10n/app_localizations.dart';
import 'package:mocktail/mocktail.dart';

void main() {
  for (final current in [true, false]) {
    testWidgets(
      current
          ? 'revoking this device returns to Profile without fetching signed-out sessions'
          : 'revoking another device refreshes the list without signing out',
      (tester) async {
        final api = _MockApiClient();
        var loads = 0;
        when(() => api.getJsonList('auth/sessions')).thenAnswer((_) async {
          loads++;
          return loads == 1
              ? [
                  {
                    'id': 'smoke-session',
                    'is_current': current,
                    'created_at': '2026-10-12T00:00:00Z',
                    'expires_at': '2026-11-12T00:00:00Z',
                  },
                ]
              : [];
        });
        when(
          () => api.delete('auth/sessions/smoke-session'),
        ).thenAnswer((_) async {});
        final container = ProviderContainer(
          overrides: [
            authControllerProvider.overrideWith(_TestAuth.new),
            apiClientProvider.overrideWithValue(api),
          ],
        );
        addTearDown(container.dispose);
        await container.read(authControllerProvider.future);
        final router = GoRouter(
          initialLocation: AppRoute.sessions.path,
          routes: [
            GoRoute(
              path: AppRoute.sessions.path,
              builder: (_, _) => const SessionsScreen(),
            ),
            GoRoute(
              path: AppRoute.profile.path,
              builder: (_, _) => const Scaffold(body: Text('Profile returned')),
            ),
          ],
        );
        addTearDown(router.dispose);
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp.router(
              routerConfig: router,
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
        await tester.tap(find.widgetWithText(OutlinedButton, 'Revoke session'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Revoke session').last);
        await tester.pumpAndSettle();

        verify(() => api.delete('auth/sessions/smoke-session')).called(1);
        expect(
          container.read(authControllerProvider).valueOrNull?.status,
          current ? AuthStatus.guest : AuthStatus.authenticated,
        );
        expect(
          find.text('Profile returned'),
          current ? findsOneWidget : findsNothing,
        );
        expect(loads, current ? 1 : 2);
        expect(
          find.text(
            'Could not load sessions. Check your connection and try again.',
          ),
          findsNothing,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
}

class _MockApiClient extends Mock implements ApiClient {}

class _TestAuth extends AuthController {
  @override
  Future<AuthState> build() async => AuthState.authenticated(
    Session(
      id: 'smoke-session',
      userId: 'smoke-user',
      accessToken: 'test-access',
      refreshToken: 'test-refresh',
      accessTokenExpiresAt: DateTime.utc(2026, 11, 12),
      createdAt: DateTime.utc(2026, 10, 12),
    ),
  );

  @override
  Future<void> signOut() async {
    state = const AsyncData(AuthState.guest());
  }
}
