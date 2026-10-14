import 'package:shared_preferences/shared_preferences.dart';

import '../../../domain/models/user.dart';
import '../domain/app_settings.dart';

abstract interface class SettingsRepository {
  Future<AppSettings> load();
  Future<void> save(AppSettings settings);
  Future<void> resetOnboarding();
  Future<void> clearLocalPreferences();
}

class SharedPreferencesSettingsRepository implements SettingsRepository {
  SharedPreferencesSettingsRepository(this._preferences);

  final SharedPreferencesAsync _preferences;

  static const _prefix = 'settings.';

  @override
  Future<AppSettings> load() async {
    final defaults = const AppSettings.defaults();
    try {
      return AppSettings(
        onboardingComplete:
            await _preferences.getBool('${_prefix}onboarding_complete') ??
            defaults.onboardingComplete,
        consentVersion:
            await _preferences.getInt('${_prefix}consent_version') ??
            defaults.consentVersion,
        userMode: _enumValue(
          UserMode.values,
          await _preferences.getString('${_prefix}user_mode'),
          defaults.userMode,
        ),
        explanationLevel: _enumValue(
          ExplanationLevel.values,
          await _preferences.getString('${_prefix}explanation_level'),
          defaults.explanationLevel,
        ),
        languageCode:
            await _preferences.getString('${_prefix}language_code') ??
            defaults.languageCode,
        theme: _enumValue(
          AppThemePreference.values,
          await _preferences.getString('${_prefix}theme'),
          defaults.theme,
        ),
        textScale:
            await _preferences.getDouble('${_prefix}text_scale') ??
            defaults.textScale,
        largeControls:
            await _preferences.getBool('${_prefix}large_controls') ??
            defaults.largeControls,
        highReadability:
            await _preferences.getBool('${_prefix}high_readability') ??
            defaults.highReadability,
        reducedMotion:
            await _preferences.getBool('${_prefix}reduced_motion') ??
            defaults.reducedMotion,
        hapticsEnabled:
            await _preferences.getBool('${_prefix}haptics') ??
            defaults.hapticsEnabled,
        ttsEnabled:
            await _preferences.getBool('${_prefix}tts') ?? defaults.ttsEnabled,
        notificationsEnabled:
            await _preferences.getBool('${_prefix}notifications') ??
            defaults.notificationsEnabled,
        syncEnabled:
            await _preferences.getBool('${_prefix}sync') ??
            defaults.syncEnabled,
        analyticsEnabled:
            await _preferences.getBool('${_prefix}analytics') ??
            defaults.analyticsEnabled,
        biometricLockEnabled:
            await _preferences.getBool('${_prefix}biometric_lock') ??
            defaults.biometricLockEnabled,
        deletePrescriptionImagesAfterConfirmation:
            await _preferences.getBool(
              '${_prefix}delete_prescription_images_after_confirmation',
            ) ??
            defaults.deletePrescriptionImagesAfterConfirmation,
        lastUsefulLocation:
            await _preferences.getString('${_prefix}last_location') ??
            defaults.lastUsefulLocation,
      );
    } on Object {
      return defaults;
    }
  }

  T _enumValue<T extends Enum>(List<T> values, String? name, T fallback) {
    for (final value in values) {
      if (value.name == name) return value;
    }
    return fallback;
  }

  @override
  Future<void> save(AppSettings settings) async {
    try {
      await Future.wait([
        _preferences.setBool(
          '${_prefix}onboarding_complete',
          settings.onboardingComplete,
        ),
        _preferences.setInt(
          '${_prefix}consent_version',
          settings.consentVersion,
        ),
        _preferences.setString('${_prefix}user_mode', settings.userMode.name),
        _preferences.setString(
          '${_prefix}explanation_level',
          settings.explanationLevel.name,
        ),
        _preferences.setString(
          '${_prefix}language_code',
          settings.languageCode,
        ),
        _preferences.setString('${_prefix}theme', settings.theme.name),
        _preferences.setDouble('${_prefix}text_scale', settings.textScale),
        _preferences.setBool(
          '${_prefix}large_controls',
          settings.largeControls,
        ),
        _preferences.setBool(
          '${_prefix}high_readability',
          settings.highReadability,
        ),
        _preferences.setBool(
          '${_prefix}reduced_motion',
          settings.reducedMotion,
        ),
        _preferences.setBool('${_prefix}haptics', settings.hapticsEnabled),
        _preferences.setBool('${_prefix}tts', settings.ttsEnabled),
        _preferences.setBool(
          '${_prefix}notifications',
          settings.notificationsEnabled,
        ),
        _preferences.setBool('${_prefix}sync', settings.syncEnabled),
        _preferences.setBool('${_prefix}analytics', settings.analyticsEnabled),
        _preferences.setBool(
          '${_prefix}biometric_lock',
          settings.biometricLockEnabled,
        ),
        _preferences.setBool(
          '${_prefix}delete_prescription_images_after_confirmation',
          settings.deletePrescriptionImagesAfterConfirmation,
        ),
        _preferences.setString(
          '${_prefix}last_location',
          settings.lastUsefulLocation,
        ),
      ]);
    } on Object {
      // Ignore preference save errors on platform channel failure
    }
  }

  @override
  Future<void> resetOnboarding() async {
    await _preferences.setBool('${_prefix}onboarding_complete', false);
  }

  @override
  Future<void> clearLocalPreferences() async {
    final keys = await _preferences.getKeys();
    await Future.wait(
      keys.where((key) => key.startsWith(_prefix)).map(_preferences.remove),
    );
  }
}
