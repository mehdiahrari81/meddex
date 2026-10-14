import 'package:flutter_test/flutter_test.dart';
import 'package:mediexplain/domain/models/user.dart';
import 'package:mediexplain/features/settings/data/settings_repository.dart';
import 'package:mediexplain/features/settings/domain/app_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  test('first launch defaults to incomplete onboarding', () async {
    final repository = SharedPreferencesSettingsRepository(
      SharedPreferencesAsync(),
    );
    final settings = await repository.load();
    expect(settings.onboardingComplete, isFalse);
    expect(settings.consentVersion, 0);
    expect(settings.userMode, UserMode.patient);
    expect(settings.deletePrescriptionImagesAfterConfirmation, isTrue);
  });

  test('onboarding and all core preferences survive reload', () async {
    final repository = SharedPreferencesSettingsRepository(
      SharedPreferencesAsync(),
    );
    final expected = const AppSettings.defaults().copyWith(
      onboardingComplete: true,
      consentVersion: 1,
      userMode: UserMode.student,
      explanationLevel: ExplanationLevel.technical,
      languageCode: 'ur',
      theme: AppThemePreference.dark,
      textScale: 1.25,
      reducedMotion: true,
      syncEnabled: false,
      deletePrescriptionImagesAfterConfirmation: false,
    );

    await repository.save(expected);
    final restored = await repository.load();

    expect(restored.onboardingComplete, isTrue);
    expect(restored.consentVersion, 1);
    expect(restored.userMode, UserMode.student);
    expect(restored.explanationLevel, ExplanationLevel.technical);
    expect(restored.languageCode, 'ur');
    expect(restored.theme, AppThemePreference.dark);
    expect(restored.textScale, 1.25);
    expect(restored.reducedMotion, isTrue);
    expect(restored.syncEnabled, isFalse);
    expect(restored.deletePrescriptionImagesAfterConfirmation, isFalse);
  });

  test('reset onboarding preserves other preferences', () async {
    final repository = SharedPreferencesSettingsRepository(
      SharedPreferencesAsync(),
    );
    await repository.save(
      const AppSettings.defaults().copyWith(
        onboardingComplete: true,
        userMode: UserMode.student,
      ),
    );
    await repository.resetOnboarding();

    final restored = await repository.load();
    expect(restored.onboardingComplete, isFalse);
    expect(restored.userMode, UserMode.student);
  });
}
