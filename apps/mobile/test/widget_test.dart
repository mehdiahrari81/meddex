import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediexplain/app/app.dart';
import 'package:mediexplain/app/bootstrap/bootstrap_provider.dart';
import 'package:mediexplain/app/bootstrap/startup_coordinator.dart';
import 'package:mediexplain/features/auth/application/auth_controller.dart';
import 'package:mediexplain/features/settings/application/settings_controller.dart';
import 'package:mediexplain/features/settings/domain/app_settings.dart';

void main() {
  testWidgets('startup failure offers a working retry action', (tester) async {
    var attempts = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bootstrapProvider.overrideWith((ref) async {
            attempts++;
            throw const StartupFailure(
              step: StartupStep.localDatabase,
              cause: 'unavailable',
            );
          }),
          settingsControllerProvider.overrideWith(_TestSettings.new),
          authControllerProvider.overrideWith(_GuestAuth.new),
        ],
        child: const MediExplainApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('MediExplain could not start'), findsOneWidget);
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(attempts, 2);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

class _TestSettings extends SettingsController {
  @override
  Future<AppSettings> build() async => const AppSettings.defaults();
}

class _GuestAuth extends AuthController {
  @override
  Future<AuthState> build() async => const AuthState.guest();
}
