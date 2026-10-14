import 'package:flutter_test/flutter_test.dart';
import 'package:mediexplain/app/router/app_router.dart';
import 'package:mediexplain/app/router/app_routes.dart';
import 'package:mediexplain/domain/models/session.dart';
import 'package:mediexplain/features/auth/application/auth_controller.dart';
import 'package:mediexplain/features/settings/domain/app_settings.dart';

void main() {
  const guest = AuthState.guest();
  final completed = const AppSettings.defaults().copyWith(
    onboardingComplete: true,
    consentVersion: 1,
  );

  test('first launch is routed to onboarding', () {
    expect(
      routeRedirect(
        settings: const AppSettings.defaults(),
        auth: guest,
        matchedLocation: AppRoute.home.path,
        requestedUri: Uri.parse(AppRoute.home.path),
      ),
      AppRoute.onboarding.path,
    );
  });

  test('returning guest resumes useful unprotected route', () {
    expect(
      routeRedirect(
        settings: completed,
        auth: guest,
        matchedLocation: AppRoute.home.path,
        requestedUri: Uri.parse(AppRoute.home.path),
      ),
      isNull,
    );
  });

  test('guest is redirected away from protected session route', () {
    final redirect = routeRedirect(
      settings: completed,
      auth: guest,
      matchedLocation: AppRoute.sessions.path,
      requestedUri: Uri.parse(AppRoute.sessions.path),
    );
    expect(redirect, startsWith(AppRoute.auth.path));
    expect(redirect, contains('from='));
  });

  test('authenticated user may open protected session route', () {
    final now = DateTime.now().toUtc();
    final auth = AuthState.authenticated(
      Session(
        id: 'session-id',
        userId: 'user-id',
        accessToken: 'access',
        refreshToken: 'refresh',
        accessTokenExpiresAt: now.add(const Duration(minutes: 5)),
        createdAt: now,
      ),
    );
    expect(
      routeRedirect(
        settings: completed,
        auth: auth,
        matchedLocation: AppRoute.sessions.path,
        requestedUri: Uri.parse(AppRoute.sessions.path),
      ),
      isNull,
    );
  });
}
