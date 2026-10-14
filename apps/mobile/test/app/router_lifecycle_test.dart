import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediexplain/app/router/app_router.dart';
import 'package:mediexplain/app/router/app_routes.dart';
import 'package:mediexplain/domain/models/user.dart';
import 'package:mediexplain/features/auth/application/auth_controller.dart';
import 'package:mediexplain/features/settings/application/settings_controller.dart';
import 'package:mediexplain/features/settings/domain/app_settings.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'language and theme changes retain the router and current settings route',
    () async {
      final container = ProviderContainer(
        overrides: [
          settingsControllerProvider.overrideWith(_TestSettings.new),
          authControllerProvider.overrideWith(_GuestAuth.new),
        ],
      );
      addTearDown(container.dispose);
      await container.read(settingsControllerProvider.future);
      await container.read(authControllerProvider.future);
      final router = container.read(appRouterProvider);
      router.go(AppRoute.settings.path);
      final controller =
          container.read(settingsControllerProvider.notifier) as _TestSettings;
      await controller.update((value) => value.copyWith(languageCode: 'ur'));
      await Future<void>.delayed(Duration.zero);
      expect(container.read(appRouterProvider), same(router));
      expect(
        router.routeInformationProvider.value.uri.path,
        AppRoute.settings.path,
      );
      await controller.update(
        (value) => value.copyWith(theme: AppThemePreference.dark),
      );
      await Future<void>.delayed(Duration.zero);
      expect(container.read(appRouterProvider), same(router));
      expect(
        router.routeInformationProvider.value.uri.path,
        AppRoute.settings.path,
      );
    },
  );
}

class _TestSettings extends SettingsController {
  @override
  Future<AppSettings> build() async =>
      const AppSettings.defaults().copyWith(onboardingComplete: true);
}

class _GuestAuth extends AuthController {
  @override
  Future<AuthState> build() async => const AuthState.guest();
}
