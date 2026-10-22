import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../domain/models/user.dart';
import '../data/settings_repository.dart';
import '../domain/app_settings.dart';

final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => SharedPreferencesSettingsRepository(SharedPreferencesAsync()),
);

final settingsControllerProvider =
    AsyncNotifierProvider<SettingsController, AppSettings>(
      SettingsController.new,
    );

class SettingsController extends AsyncNotifier<AppSettings> {
  SettingsRepository get _repository => ref.read(settingsRepositoryProvider);

  @override
  Future<AppSettings> build() => _repository.load();

  Future<void> persist(AppSettings Function(AppSettings current) change) async {
    final current = state.valueOrNull ?? await _repository.load();
    final updated = change(current);
    state = AsyncData(updated);
    try {
      await _repository.save(updated);
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }

  Future<void> completeOnboarding({required int consentVersion}) => persist(
    (current) => current.copyWith(
      onboardingComplete: true,
      consentVersion: consentVersion,
    ),
  );

  Future<void> setMode(UserMode value) =>
      persist((current) => current.copyWith(userMode: value));

  Future<void> setExplanationLevel(ExplanationLevel value) =>
      persist((current) => current.copyWith(explanationLevel: value));

  Future<void> setLanguage(String value) =>
      persist((current) => current.copyWith(languageCode: value));

  Future<void> setTheme(AppThemePreference value) =>
      persist((current) => current.copyWith(theme: value));

  Future<void> setDevelopmentServerUrl(
    String url, {
    bool automatic = false,
  }) async {
    final current = state.valueOrNull ?? await _repository.load();
    final updated = current.copyWith(
      developmentServerUrl: url,
      automaticServerConnection: automatic,
    );
    // Publish a different server only after the address has been saved.
    await _repository.save(updated);
    state = AsyncData(updated);
  }
}
