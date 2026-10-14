import '../../../domain/models/user.dart';

class AppSettings {
  const AppSettings({
    required this.onboardingComplete,
    required this.consentVersion,
    required this.userMode,
    required this.explanationLevel,
    required this.languageCode,
    required this.theme,
    required this.textScale,
    required this.largeControls,
    required this.highReadability,
    required this.reducedMotion,
    required this.hapticsEnabled,
    required this.ttsEnabled,
    required this.notificationsEnabled,
    required this.syncEnabled,
    required this.analyticsEnabled,
    required this.biometricLockEnabled,
    required this.deletePrescriptionImagesAfterConfirmation,
    required this.lastUsefulLocation,
  });

  const AppSettings.defaults()
    : onboardingComplete = false,
      consentVersion = 0,
      userMode = UserMode.patient,
      explanationLevel = ExplanationLevel.standard,
      languageCode = 'en',
      theme = AppThemePreference.system,
      textScale = 1,
      largeControls = false,
      highReadability = false,
      reducedMotion = false,
      hapticsEnabled = true,
      ttsEnabled = false,
      notificationsEnabled = true,
      syncEnabled = true,
      analyticsEnabled = false,
      biometricLockEnabled = false,
      deletePrescriptionImagesAfterConfirmation = true,
      lastUsefulLocation = '/home';

  final bool onboardingComplete;
  final int consentVersion;
  final UserMode userMode;
  final ExplanationLevel explanationLevel;
  final String languageCode;
  final AppThemePreference theme;
  final double textScale;
  final bool largeControls;
  final bool highReadability;
  final bool reducedMotion;
  final bool hapticsEnabled;
  final bool ttsEnabled;
  final bool notificationsEnabled;
  final bool syncEnabled;
  final bool analyticsEnabled;
  final bool biometricLockEnabled;
  final bool deletePrescriptionImagesAfterConfirmation;
  final String lastUsefulLocation;

  AppSettings copyWith({
    bool? onboardingComplete,
    int? consentVersion,
    UserMode? userMode,
    ExplanationLevel? explanationLevel,
    String? languageCode,
    AppThemePreference? theme,
    double? textScale,
    bool? largeControls,
    bool? highReadability,
    bool? reducedMotion,
    bool? hapticsEnabled,
    bool? ttsEnabled,
    bool? notificationsEnabled,
    bool? syncEnabled,
    bool? analyticsEnabled,
    bool? biometricLockEnabled,
    bool? deletePrescriptionImagesAfterConfirmation,
    String? lastUsefulLocation,
  }) => AppSettings(
    onboardingComplete: onboardingComplete ?? this.onboardingComplete,
    consentVersion: consentVersion ?? this.consentVersion,
    userMode: userMode ?? this.userMode,
    explanationLevel: explanationLevel ?? this.explanationLevel,
    languageCode: languageCode ?? this.languageCode,
    theme: theme ?? this.theme,
    textScale: textScale ?? this.textScale,
    largeControls: largeControls ?? this.largeControls,
    highReadability: highReadability ?? this.highReadability,
    reducedMotion: reducedMotion ?? this.reducedMotion,
    hapticsEnabled: hapticsEnabled ?? this.hapticsEnabled,
    ttsEnabled: ttsEnabled ?? this.ttsEnabled,
    notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
    syncEnabled: syncEnabled ?? this.syncEnabled,
    analyticsEnabled: analyticsEnabled ?? this.analyticsEnabled,
    biometricLockEnabled: biometricLockEnabled ?? this.biometricLockEnabled,
    deletePrescriptionImagesAfterConfirmation:
        deletePrescriptionImagesAfterConfirmation ??
        this.deletePrescriptionImagesAfterConfirmation,
    lastUsefulLocation: lastUsefulLocation ?? this.lastUsefulLocation,
  );
}
