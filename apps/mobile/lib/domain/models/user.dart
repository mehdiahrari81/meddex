enum UserMode { patient, student, guest }

enum ExplanationLevel { simple, standard, technical }

class AppUser {
  const AppUser({
    required this.id,
    required this.email,
    required this.createdAt,
    this.displayName,
  });

  final String id;
  final String email;
  final String? displayName;
  final DateTime createdAt;
}

class UserProfile {
  const UserProfile({
    required this.userId,
    required this.displayName,
    required this.email,
    required this.preferences,
    required this.createdAt,
    required this.consentVersion,
  });

  final String userId;
  final String displayName;
  final String email;
  final UserPreferences preferences;
  final DateTime createdAt;
  final int consentVersion;
}

class UserPreferences {
  const UserPreferences({
    required this.mode,
    required this.explanationLevel,
    required this.languageCode,
    required this.themeMode,
    required this.textScale,
    required this.largeControls,
    required this.highReadability,
    required this.reducedMotion,
    required this.ttsEnabled,
    required this.hapticsEnabled,
    required this.notificationsEnabled,
    required this.syncEnabled,
    required this.analyticsEnabled,
    required this.biometricLockEnabled,
  });

  final UserMode mode;
  final ExplanationLevel explanationLevel;
  final String languageCode;
  final AppThemePreference themeMode;
  final double textScale;
  final bool largeControls;
  final bool highReadability;
  final bool reducedMotion;
  final bool ttsEnabled;
  final bool hapticsEnabled;
  final bool notificationsEnabled;
  final bool syncEnabled;
  final bool analyticsEnabled;
  final bool biometricLockEnabled;
}

enum AppThemePreference { system, light, dark }
