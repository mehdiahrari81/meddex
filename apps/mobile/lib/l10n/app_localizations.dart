import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ur.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ur'),
  ];

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'MediExplain'**
  String get appName;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get retry;

  /// No description provided for @passwordResetInstructions.
  ///
  /// In en, this message translates to:
  /// **'Enter your account email to request a reset code. Check your inbox, then enter the code below.'**
  String get passwordResetInstructions;

  /// No description provided for @enterResetCode.
  ///
  /// In en, this message translates to:
  /// **'Enter reset code'**
  String get enterResetCode;

  /// No description provided for @resetPasswordTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset password'**
  String get resetPasswordTitle;

  /// No description provided for @resetPasswordDescription.
  ///
  /// In en, this message translates to:
  /// **'Paste the code from your reset email and choose a new password. This signs out all existing sessions.'**
  String get resetPasswordDescription;

  /// No description provided for @resetCode.
  ///
  /// In en, this message translates to:
  /// **'Reset code'**
  String get resetCode;

  /// No description provided for @resetCodeRequired.
  ///
  /// In en, this message translates to:
  /// **'Paste the complete code from your email.'**
  String get resetCodeRequired;

  /// No description provided for @newPassword.
  ///
  /// In en, this message translates to:
  /// **'New password'**
  String get newPassword;

  /// No description provided for @confirmPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm password'**
  String get confirmPassword;

  /// No description provided for @passwordsDoNotMatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match.'**
  String get passwordsDoNotMatch;

  /// No description provided for @passwordResetComplete.
  ///
  /// In en, this message translates to:
  /// **'Password updated. Sign in with your new password.'**
  String get passwordResetComplete;

  /// No description provided for @passwordResetFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not reset your password. Check your connection and code, or request a new code if it has expired.'**
  String get passwordResetFailed;

  /// No description provided for @loadingSessions.
  ///
  /// In en, this message translates to:
  /// **'Loading active sessions'**
  String get loadingSessions;

  /// No description provided for @sessionsDescription.
  ///
  /// In en, this message translates to:
  /// **'Review your active sign-ins. Revoke a session to sign that device out. An internet connection is required.'**
  String get sessionsDescription;

  /// No description provided for @sessionsLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load sessions. Check your connection and try again.'**
  String get sessionsLoadFailed;

  /// No description provided for @currentSession.
  ///
  /// In en, this message translates to:
  /// **'This device'**
  String get currentSession;

  /// No description provided for @otherSession.
  ///
  /// In en, this message translates to:
  /// **'Another sign-in'**
  String get otherSession;

  /// No description provided for @sessionCreated.
  ///
  /// In en, this message translates to:
  /// **'Signed in: {date}'**
  String sessionCreated(String date);

  /// No description provided for @sessionExpires.
  ///
  /// In en, this message translates to:
  /// **'Expires: {date}'**
  String sessionExpires(String date);

  /// No description provided for @revokeSession.
  ///
  /// In en, this message translates to:
  /// **'Revoke session'**
  String get revokeSession;

  /// No description provided for @revokeSessionConfirmation.
  ///
  /// In en, this message translates to:
  /// **'This sign-in will lose access to your account. Revoking this device signs you out here too.'**
  String get revokeSessionConfirmation;

  /// No description provided for @sessionRevokeFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not revoke the session. Check your connection and try again.'**
  String get sessionRevokeFailed;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @continueLabel.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueLabel;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @notAvailableYet.
  ///
  /// In en, this message translates to:
  /// **'Coming in a later module'**
  String get notAvailableYet;

  /// No description provided for @startupTitle.
  ///
  /// In en, this message translates to:
  /// **'Preparing MediExplain'**
  String get startupTitle;

  /// No description provided for @startupMessage.
  ///
  /// In en, this message translates to:
  /// **'Setting up your secure, offline-ready experience.'**
  String get startupMessage;

  /// No description provided for @startupErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'MediExplain could not start'**
  String get startupErrorTitle;

  /// No description provided for @startupErrorMessage.
  ///
  /// In en, this message translates to:
  /// **'Your data was not changed. Check your device storage and try again.'**
  String get startupErrorMessage;

  /// No description provided for @offline.
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get offline;

  /// No description provided for @reconnecting.
  ///
  /// In en, this message translates to:
  /// **'Reconnecting'**
  String get reconnecting;

  /// No description provided for @synchronizing.
  ///
  /// In en, this message translates to:
  /// **'Synchronizing'**
  String get synchronizing;

  /// No description provided for @home.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// No description provided for @scan.
  ///
  /// In en, this message translates to:
  /// **'Scan'**
  String get scan;

  /// No description provided for @learn.
  ///
  /// In en, this message translates to:
  /// **'Learn'**
  String get learn;

  /// No description provided for @saved.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get saved;

  /// No description provided for @profile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profile;

  /// No description provided for @welcomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Medical language, made clearer'**
  String get welcomeTitle;

  /// No description provided for @welcomeBody.
  ///
  /// In en, this message translates to:
  /// **'Build confidence when reading medical terms and prescription information.'**
  String get welcomeBody;

  /// No description provided for @understandTitle.
  ///
  /// In en, this message translates to:
  /// **'Understand'**
  String get understandTitle;

  /// No description provided for @understandBody.
  ///
  /// In en, this message translates to:
  /// **'Get plain-language, source-aware explanations of medical terms.'**
  String get understandBody;

  /// No description provided for @prescriptionTitle.
  ///
  /// In en, this message translates to:
  /// **'Prescription Helper'**
  String get prescriptionTitle;

  /// No description provided for @prescriptionBody.
  ///
  /// In en, this message translates to:
  /// **'Later, scan prescription text and verify every important detail before using it.'**
  String get prescriptionBody;

  /// No description provided for @learnTitle.
  ///
  /// In en, this message translates to:
  /// **'Learn'**
  String get learnTitle;

  /// No description provided for @learnBody.
  ///
  /// In en, this message translates to:
  /// **'Study terminology at a level that fits your goals.'**
  String get learnBody;

  /// No description provided for @privacyTitle.
  ///
  /// In en, this message translates to:
  /// **'Privacy by design'**
  String get privacyTitle;

  /// No description provided for @privacyBody.
  ///
  /// In en, this message translates to:
  /// **'We minimize data collection. Sensitive credentials use secure device storage, and prescription images are never uploaded automatically.'**
  String get privacyBody;

  /// No description provided for @safetyTitle.
  ///
  /// In en, this message translates to:
  /// **'Education, not medical advice'**
  String get safetyTitle;

  /// No description provided for @safetyBody.
  ///
  /// In en, this message translates to:
  /// **'MediExplain does not diagnose, prescribe, change doses, or replace a doctor or pharmacist. Unclear scanned information must be verified.'**
  String get safetyBody;

  /// No description provided for @languageTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose your language'**
  String get languageTitle;

  /// No description provided for @english.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @urdu.
  ///
  /// In en, this message translates to:
  /// **'Urdu'**
  String get urdu;

  /// No description provided for @accessibilityTitle.
  ///
  /// In en, this message translates to:
  /// **'Make it comfortable'**
  String get accessibilityTitle;

  /// No description provided for @largerText.
  ///
  /// In en, this message translates to:
  /// **'Larger text'**
  String get largerText;

  /// No description provided for @largerControls.
  ///
  /// In en, this message translates to:
  /// **'Larger controls'**
  String get largerControls;

  /// No description provided for @reduceMotion.
  ///
  /// In en, this message translates to:
  /// **'Reduce motion'**
  String get reduceMotion;

  /// No description provided for @highReadability.
  ///
  /// In en, this message translates to:
  /// **'High-readability mode'**
  String get highReadability;

  /// No description provided for @usageModeTitle.
  ///
  /// In en, this message translates to:
  /// **'How will you use MediExplain?'**
  String get usageModeTitle;

  /// No description provided for @patientMode.
  ///
  /// In en, this message translates to:
  /// **'Patient'**
  String get patientMode;

  /// No description provided for @patientModeBody.
  ///
  /// In en, this message translates to:
  /// **'Clear, practical language and readable information.'**
  String get patientModeBody;

  /// No description provided for @studentMode.
  ///
  /// In en, this message translates to:
  /// **'Student'**
  String get studentMode;

  /// No description provided for @studentModeBody.
  ///
  /// In en, this message translates to:
  /// **'Technical vocabulary and learning-focused detail.'**
  String get studentModeBody;

  /// No description provided for @guestMode.
  ///
  /// In en, this message translates to:
  /// **'Guest'**
  String get guestMode;

  /// No description provided for @guestModeBody.
  ///
  /// In en, this message translates to:
  /// **'Use non-sensitive features without an account.'**
  String get guestModeBody;

  /// No description provided for @consentTitle.
  ///
  /// In en, this message translates to:
  /// **'One final check'**
  String get consentTitle;

  /// No description provided for @consentBody.
  ///
  /// In en, this message translates to:
  /// **'I understand that MediExplain provides educational information and does not replace professional medical advice.'**
  String get consentBody;

  /// No description provided for @consentRequired.
  ///
  /// In en, this message translates to:
  /// **'Please acknowledge the medical-safety notice to continue.'**
  String get consentRequired;

  /// No description provided for @getStarted.
  ///
  /// In en, this message translates to:
  /// **'Get started'**
  String get getStarted;

  /// No description provided for @homeGreeting.
  ///
  /// In en, this message translates to:
  /// **'A clearer path through medical language'**
  String get homeGreeting;

  /// No description provided for @homeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'What would you like to understand today?'**
  String get homeSubtitle;

  /// No description provided for @scanPrescription.
  ///
  /// In en, this message translates to:
  /// **'Scan prescription'**
  String get scanPrescription;

  /// No description provided for @scanPrescriptionBody.
  ///
  /// In en, this message translates to:
  /// **'Capture and verify prescription information'**
  String get scanPrescriptionBody;

  /// No description provided for @scanMedicalTerm.
  ///
  /// In en, this message translates to:
  /// **'Scan medical term'**
  String get scanMedicalTerm;

  /// No description provided for @scanMedicalTermBody.
  ///
  /// In en, this message translates to:
  /// **'Recognize a term from text'**
  String get scanMedicalTermBody;

  /// No description provided for @searchMedicalTerm.
  ///
  /// In en, this message translates to:
  /// **'Search medical term'**
  String get searchMedicalTerm;

  /// No description provided for @searchMedicalTermBody.
  ///
  /// In en, this message translates to:
  /// **'Type a term to understand it'**
  String get searchMedicalTermBody;

  /// No description provided for @learnMedicalTerms.
  ///
  /// In en, this message translates to:
  /// **'Learn medical terms'**
  String get learnMedicalTerms;

  /// No description provided for @learnMedicalTermsBody.
  ///
  /// In en, this message translates to:
  /// **'Build knowledge step by step'**
  String get learnMedicalTermsBody;

  /// No description provided for @yourSpace.
  ///
  /// In en, this message translates to:
  /// **'Your space'**
  String get yourSpace;

  /// No description provided for @continueLearning.
  ///
  /// In en, this message translates to:
  /// **'Continue learning'**
  String get continueLearning;

  /// No description provided for @recentActivity.
  ///
  /// In en, this message translates to:
  /// **'Recent activity'**
  String get recentActivity;

  /// No description provided for @savedContent.
  ///
  /// In en, this message translates to:
  /// **'Saved content'**
  String get savedContent;

  /// No description provided for @medicationReminders.
  ///
  /// In en, this message translates to:
  /// **'Medication reminders'**
  String get medicationReminders;

  /// No description provided for @nothingHereYet.
  ///
  /// In en, this message translates to:
  /// **'Nothing here yet'**
  String get nothingHereYet;

  /// No description provided for @futureContentBody.
  ///
  /// In en, this message translates to:
  /// **'This area is ready for a future MediExplain module.'**
  String get futureContentBody;

  /// No description provided for @medicalDisclaimerShort.
  ///
  /// In en, this message translates to:
  /// **'Educational information only — not a diagnosis or prescription.'**
  String get medicalDisclaimerShort;

  /// No description provided for @signIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get signIn;

  /// No description provided for @createAccount.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get createAccount;

  /// No description provided for @continueAsGuest.
  ///
  /// In en, this message translates to:
  /// **'Continue as guest'**
  String get continueAsGuest;

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @displayName.
  ///
  /// In en, this message translates to:
  /// **'Display name'**
  String get displayName;

  /// No description provided for @forgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get forgotPassword;

  /// No description provided for @emailRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter your email address.'**
  String get emailRequired;

  /// No description provided for @emailInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email address.'**
  String get emailInvalid;

  /// No description provided for @passwordRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter your password.'**
  String get passwordRequired;

  /// No description provided for @passwordRequirements.
  ///
  /// In en, this message translates to:
  /// **'Use at least 12 characters with upper and lowercase letters, a number, and a symbol.'**
  String get passwordRequirements;

  /// No description provided for @nameRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter your name.'**
  String get nameRequired;

  /// No description provided for @authenticationFailed.
  ///
  /// In en, this message translates to:
  /// **'We could not complete that request. Check your details and connection.'**
  String get authenticationFailed;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @appearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearance;

  /// No description provided for @theme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get theme;

  /// No description provided for @systemTheme.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get systemTheme;

  /// No description provided for @lightTheme.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get lightTheme;

  /// No description provided for @darkTheme.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get darkTheme;

  /// No description provided for @textSize.
  ///
  /// In en, this message translates to:
  /// **'Text size'**
  String get textSize;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @accessibility.
  ///
  /// In en, this message translates to:
  /// **'Accessibility'**
  String get accessibility;

  /// No description provided for @hapticFeedback.
  ///
  /// In en, this message translates to:
  /// **'Haptic feedback'**
  String get hapticFeedback;

  /// No description provided for @textToSpeech.
  ///
  /// In en, this message translates to:
  /// **'Text to speech'**
  String get textToSpeech;

  /// No description provided for @medicalExplanation.
  ///
  /// In en, this message translates to:
  /// **'Medical explanation'**
  String get medicalExplanation;

  /// No description provided for @userMode.
  ///
  /// In en, this message translates to:
  /// **'User mode'**
  String get userMode;

  /// No description provided for @explanationLevel.
  ///
  /// In en, this message translates to:
  /// **'Explanation level'**
  String get explanationLevel;

  /// No description provided for @simple.
  ///
  /// In en, this message translates to:
  /// **'Simple'**
  String get simple;

  /// No description provided for @standard.
  ///
  /// In en, this message translates to:
  /// **'Standard'**
  String get standard;

  /// No description provided for @technical.
  ///
  /// In en, this message translates to:
  /// **'Technical'**
  String get technical;

  /// No description provided for @notifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// No description provided for @notificationsMaster.
  ///
  /// In en, this message translates to:
  /// **'Allow notifications'**
  String get notificationsMaster;

  /// No description provided for @remindersPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Medication reminders'**
  String get remindersPlaceholder;

  /// No description provided for @remindersNotConfigured.
  ///
  /// In en, this message translates to:
  /// **'Available in Module 5'**
  String get remindersNotConfigured;

  /// No description provided for @privacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy'**
  String get privacy;

  /// No description provided for @localData.
  ///
  /// In en, this message translates to:
  /// **'Local data'**
  String get localData;

  /// No description provided for @manageSavedData.
  ///
  /// In en, this message translates to:
  /// **'Manage saved data'**
  String get manageSavedData;

  /// No description provided for @syncPreference.
  ///
  /// In en, this message translates to:
  /// **'Synchronize account data'**
  String get syncPreference;

  /// No description provided for @analyticsPreference.
  ///
  /// In en, this message translates to:
  /// **'Share anonymous app analytics'**
  String get analyticsPreference;

  /// No description provided for @deleteAccount.
  ///
  /// In en, this message translates to:
  /// **'Delete account'**
  String get deleteAccount;

  /// No description provided for @security.
  ///
  /// In en, this message translates to:
  /// **'Security'**
  String get security;

  /// No description provided for @manageSessions.
  ///
  /// In en, this message translates to:
  /// **'Manage sessions'**
  String get manageSessions;

  /// No description provided for @biometricLock.
  ///
  /// In en, this message translates to:
  /// **'Biometric app lock'**
  String get biometricLock;

  /// No description provided for @about.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about;

  /// No description provided for @appVersion.
  ///
  /// In en, this message translates to:
  /// **'App version'**
  String get appVersion;

  /// No description provided for @privacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy policy'**
  String get privacyPolicy;

  /// No description provided for @terms.
  ///
  /// In en, this message translates to:
  /// **'Terms'**
  String get terms;

  /// No description provided for @dataSources.
  ///
  /// In en, this message translates to:
  /// **'Data sources'**
  String get dataSources;

  /// No description provided for @openSourceLicenses.
  ///
  /// In en, this message translates to:
  /// **'Open-source licences'**
  String get openSourceLicenses;

  /// No description provided for @medicalDisclaimer.
  ///
  /// In en, this message translates to:
  /// **'Medical-information disclaimer'**
  String get medicalDisclaimer;

  /// No description provided for @signOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get signOut;

  /// No description provided for @resetOnboarding.
  ///
  /// In en, this message translates to:
  /// **'Review onboarding again'**
  String get resetOnboarding;

  /// No description provided for @account.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get account;

  /// No description provided for @signedOut.
  ///
  /// In en, this message translates to:
  /// **'You are using MediExplain as a guest.'**
  String get signedOut;

  /// No description provided for @signedIn.
  ///
  /// In en, this message translates to:
  /// **'Your account session is active on this device.'**
  String get signedIn;

  /// No description provided for @confirmSignOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out on this device?'**
  String get confirmSignOut;

  /// No description provided for @confirmDeleteLocalData.
  ///
  /// In en, this message translates to:
  /// **'Delete this profile’s prescriptions, images, medications, dose history, bookmarks, and learning progress from this device, and reset app preferences? This cannot be undone. Your account, existing cloud backups, reference lessons, and other profiles stay available. Unsynced uploads are discarded; existing cloud-deletion requests are kept for retry.'**
  String get confirmDeleteLocalData;

  /// No description provided for @deleteLocalData.
  ///
  /// In en, this message translates to:
  /// **'Delete local data'**
  String get deleteLocalData;

  /// No description provided for @dataDeleted.
  ///
  /// In en, this message translates to:
  /// **'Local data was deleted.'**
  String get dataDeleted;

  /// No description provided for @accountDeletionInfo.
  ///
  /// In en, this message translates to:
  /// **'Account deletion requires an authenticated connection and will revoke all sessions.'**
  String get accountDeletionInfo;

  /// No description provided for @signedInAs.
  ///
  /// In en, this message translates to:
  /// **'Signed in as {email}'**
  String signedInAs(String email);

  /// No description provided for @unknownPageTitle.
  ///
  /// In en, this message translates to:
  /// **'Page not found'**
  String get unknownPageTitle;

  /// No description provided for @unknownPageBody.
  ///
  /// In en, this message translates to:
  /// **'That page does not exist or is no longer available.'**
  String get unknownPageBody;

  /// No description provided for @goHome.
  ///
  /// In en, this message translates to:
  /// **'Go home'**
  String get goHome;

  /// No description provided for @source.
  ///
  /// In en, this message translates to:
  /// **'Source'**
  String get source;

  /// No description provided for @confidence.
  ///
  /// In en, this message translates to:
  /// **'Confidence'**
  String get confidence;

  /// No description provided for @verificationRequired.
  ///
  /// In en, this message translates to:
  /// **'Verification required'**
  String get verificationRequired;

  /// No description provided for @developmentEmailNotice.
  ///
  /// In en, this message translates to:
  /// **'Password-reset email delivery is not configured for production.'**
  String get developmentEmailNotice;

  /// No description provided for @requestReset.
  ///
  /// In en, this message translates to:
  /// **'Request reset'**
  String get requestReset;

  /// No description provided for @resetRequestSent.
  ///
  /// In en, this message translates to:
  /// **'If an account exists, reset instructions will be sent by the configured delivery service.'**
  String get resetRequestSent;

  /// No description provided for @terminologySearch.
  ///
  /// In en, this message translates to:
  /// **'Medical terminology'**
  String get terminologySearch;

  /// No description provided for @searchHint.
  ///
  /// In en, this message translates to:
  /// **'Search a term, phrase, or abbreviation'**
  String get searchHint;

  /// No description provided for @searchStartTitle.
  ///
  /// In en, this message translates to:
  /// **'What would you like to understand?'**
  String get searchStartTitle;

  /// No description provided for @searchStartBody.
  ///
  /// In en, this message translates to:
  /// **'Try a medical term, common phrase such as ‘high blood pressure,’ or an abbreviation.'**
  String get searchStartBody;

  /// No description provided for @recentSearches.
  ///
  /// In en, this message translates to:
  /// **'Recent searches'**
  String get recentSearches;

  /// No description provided for @clearAll.
  ///
  /// In en, this message translates to:
  /// **'Clear all'**
  String get clearAll;

  /// No description provided for @noSearchResults.
  ///
  /// In en, this message translates to:
  /// **'No matching term found'**
  String get noSearchResults;

  /// No description provided for @noSearchResultsBody.
  ///
  /// In en, this message translates to:
  /// **'Check the spelling or try a shorter phrase. MediExplain will not guess a medical meaning.'**
  String get noSearchResultsBody;

  /// No description provided for @didYouMean.
  ///
  /// In en, this message translates to:
  /// **'Did you mean {term}?'**
  String didYouMean(String term);

  /// No description provided for @multipleMeanings.
  ///
  /// In en, this message translates to:
  /// **'Multiple medical meanings found'**
  String get multipleMeanings;

  /// No description provided for @multipleMeaningsBody.
  ///
  /// In en, this message translates to:
  /// **'This abbreviation is context-dependent. Choose only when the surrounding information makes the meaning clear.'**
  String get multipleMeaningsBody;

  /// No description provided for @matchedAs.
  ///
  /// In en, this message translates to:
  /// **'Matched as {type}'**
  String matchedAs(String type);

  /// No description provided for @simpleMeaning.
  ///
  /// In en, this message translates to:
  /// **'Simple meaning'**
  String get simpleMeaning;

  /// No description provided for @standardMeaning.
  ///
  /// In en, this message translates to:
  /// **'Standard explanation'**
  String get standardMeaning;

  /// No description provided for @technicalDefinition.
  ///
  /// In en, this message translates to:
  /// **'Technical definition'**
  String get technicalDefinition;

  /// No description provided for @wordBreakdown.
  ///
  /// In en, this message translates to:
  /// **'Word breakdown'**
  String get wordBreakdown;

  /// No description provided for @commonLanguage.
  ///
  /// In en, this message translates to:
  /// **'Common-language equivalent'**
  String get commonLanguage;

  /// No description provided for @synonyms.
  ///
  /// In en, this message translates to:
  /// **'Synonyms'**
  String get synonyms;

  /// No description provided for @relatedTerms.
  ///
  /// In en, this message translates to:
  /// **'Related terms'**
  String get relatedTerms;

  /// No description provided for @examples.
  ///
  /// In en, this message translates to:
  /// **'Examples'**
  String get examples;

  /// No description provided for @sourceInformation.
  ///
  /// In en, this message translates to:
  /// **'Source information'**
  String get sourceInformation;

  /// No description provided for @developmentContentNotice.
  ///
  /// In en, this message translates to:
  /// **'Reviewed development content — not yet an approved production corpus'**
  String get developmentContentNotice;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @unsave.
  ///
  /// In en, this message translates to:
  /// **'Remove from saved'**
  String get unsave;

  /// No description provided for @speak.
  ///
  /// In en, this message translates to:
  /// **'Hear pronunciation'**
  String get speak;

  /// No description provided for @stopSpeaking.
  ///
  /// In en, this message translates to:
  /// **'Stop pronunciation'**
  String get stopSpeaking;

  /// No description provided for @reportContent.
  ///
  /// In en, this message translates to:
  /// **'Report a content issue'**
  String get reportContent;

  /// No description provided for @wordDecoder.
  ///
  /// In en, this message translates to:
  /// **'Medical word decoder'**
  String get wordDecoder;

  /// No description provided for @decoderHint.
  ///
  /// In en, this message translates to:
  /// **'Enter a medical word'**
  String get decoderHint;

  /// No description provided for @decode.
  ///
  /// In en, this message translates to:
  /// **'Break down word'**
  String get decode;

  /// No description provided for @partialBreakdown.
  ///
  /// In en, this message translates to:
  /// **'Partial word breakdown available'**
  String get partialBreakdown;

  /// No description provided for @noBreakdown.
  ///
  /// In en, this message translates to:
  /// **'No defensible breakdown found'**
  String get noBreakdown;

  /// No description provided for @noBreakdownBody.
  ///
  /// In en, this message translates to:
  /// **'Unknown fragments are left unresolved. MediExplain does not force a word into familiar parts.'**
  String get noBreakdownBody;

  /// No description provided for @unknownFragment.
  ///
  /// In en, this message translates to:
  /// **'Unknown fragment: {fragment}'**
  String unknownFragment(String fragment);

  /// No description provided for @abbreviationExplorer.
  ///
  /// In en, this message translates to:
  /// **'Abbreviation explorer'**
  String get abbreviationExplorer;

  /// No description provided for @abbreviationSafety.
  ///
  /// In en, this message translates to:
  /// **'Medical abbreviations can have more than one meaning. Always use the surrounding context.'**
  String get abbreviationSafety;

  /// No description provided for @prefixes.
  ///
  /// In en, this message translates to:
  /// **'Prefixes'**
  String get prefixes;

  /// No description provided for @roots.
  ///
  /// In en, this message translates to:
  /// **'Roots'**
  String get roots;

  /// No description provided for @suffixes.
  ///
  /// In en, this message translates to:
  /// **'Suffixes'**
  String get suffixes;

  /// No description provided for @categories.
  ///
  /// In en, this message translates to:
  /// **'Categories'**
  String get categories;

  /// No description provided for @browseWordParts.
  ///
  /// In en, this message translates to:
  /// **'Browse word parts'**
  String get browseWordParts;

  /// No description provided for @origin.
  ///
  /// In en, this message translates to:
  /// **'Origin'**
  String get origin;

  /// No description provided for @savedTerminology.
  ///
  /// In en, this message translates to:
  /// **'Saved terminology'**
  String get savedTerminology;

  /// No description provided for @sortAlphabetically.
  ///
  /// In en, this message translates to:
  /// **'Alphabetical'**
  String get sortAlphabetically;

  /// No description provided for @sortRecentlySaved.
  ///
  /// In en, this message translates to:
  /// **'Recently saved'**
  String get sortRecentlySaved;

  /// No description provided for @searchSaved.
  ///
  /// In en, this message translates to:
  /// **'Search saved items'**
  String get searchSaved;

  /// No description provided for @learningHome.
  ///
  /// In en, this message translates to:
  /// **'Learn medical language'**
  String get learningHome;

  /// No description provided for @todayTerm.
  ///
  /// In en, this message translates to:
  /// **'Today\'s term'**
  String get todayTerm;

  /// No description provided for @lessons.
  ///
  /// In en, this message translates to:
  /// **'Lessons'**
  String get lessons;

  /// No description provided for @flashcards.
  ///
  /// In en, this message translates to:
  /// **'Flashcards'**
  String get flashcards;

  /// No description provided for @quizzes.
  ///
  /// In en, this message translates to:
  /// **'Quizzes'**
  String get quizzes;

  /// No description provided for @progress.
  ///
  /// In en, this message translates to:
  /// **'Progress'**
  String get progress;

  /// No description provided for @currentStreak.
  ///
  /// In en, this message translates to:
  /// **'Current streak'**
  String get currentStreak;

  /// No description provided for @dayCount.
  ///
  /// In en, this message translates to:
  /// **'{count} days'**
  String dayCount(int count);

  /// No description provided for @dueReviewCount.
  ///
  /// In en, this message translates to:
  /// **'{count} reviews due'**
  String dueReviewCount(int count);

  /// No description provided for @lessonList.
  ///
  /// In en, this message translates to:
  /// **'Learning lessons'**
  String get lessonList;

  /// No description provided for @minutes.
  ///
  /// In en, this message translates to:
  /// **'{count} min'**
  String minutes(int count);

  /// No description provided for @learningObjectives.
  ///
  /// In en, this message translates to:
  /// **'Learning objectives'**
  String get learningObjectives;

  /// No description provided for @resumeLesson.
  ///
  /// In en, this message translates to:
  /// **'Resume lesson'**
  String get resumeLesson;

  /// No description provided for @startLesson.
  ///
  /// In en, this message translates to:
  /// **'Start lesson'**
  String get startLesson;

  /// No description provided for @nextSection.
  ///
  /// In en, this message translates to:
  /// **'Next section'**
  String get nextSection;

  /// No description provided for @completeLesson.
  ///
  /// In en, this message translates to:
  /// **'Complete lesson'**
  String get completeLesson;

  /// No description provided for @lessonCompleted.
  ///
  /// In en, this message translates to:
  /// **'Lesson completed'**
  String get lessonCompleted;

  /// No description provided for @revealAnswer.
  ///
  /// In en, this message translates to:
  /// **'Reveal answer'**
  String get revealAnswer;

  /// No description provided for @knewIt.
  ///
  /// In en, this message translates to:
  /// **'Knew it'**
  String get knewIt;

  /// No description provided for @unsure.
  ///
  /// In en, this message translates to:
  /// **'Unsure'**
  String get unsure;

  /// No description provided for @didNotKnow.
  ///
  /// In en, this message translates to:
  /// **'Didn\'t know'**
  String get didNotKnow;

  /// No description provided for @easy.
  ///
  /// In en, this message translates to:
  /// **'Easy'**
  String get easy;

  /// No description provided for @flashcardComplete.
  ///
  /// In en, this message translates to:
  /// **'Review session complete'**
  String get flashcardComplete;

  /// No description provided for @quizSetup.
  ///
  /// In en, this message translates to:
  /// **'Quiz setup'**
  String get quizSetup;

  /// No description provided for @questionCount.
  ///
  /// In en, this message translates to:
  /// **'Number of questions'**
  String get questionCount;

  /// No description provided for @difficulty.
  ///
  /// In en, this message translates to:
  /// **'Difficulty'**
  String get difficulty;

  /// No description provided for @beginner.
  ///
  /// In en, this message translates to:
  /// **'Beginner'**
  String get beginner;

  /// No description provided for @intermediate.
  ///
  /// In en, this message translates to:
  /// **'Intermediate'**
  String get intermediate;

  /// No description provided for @advanced.
  ///
  /// In en, this message translates to:
  /// **'Advanced'**
  String get advanced;

  /// No description provided for @startQuiz.
  ///
  /// In en, this message translates to:
  /// **'Start quiz'**
  String get startQuiz;

  /// No description provided for @submitAnswer.
  ///
  /// In en, this message translates to:
  /// **'Submit answer'**
  String get submitAnswer;

  /// No description provided for @nextQuestion.
  ///
  /// In en, this message translates to:
  /// **'Next question'**
  String get nextQuestion;

  /// No description provided for @quizResults.
  ///
  /// In en, this message translates to:
  /// **'Quiz results'**
  String get quizResults;

  /// No description provided for @score.
  ///
  /// In en, this message translates to:
  /// **'Score: {correct} of {total}'**
  String score(int correct, int total);

  /// No description provided for @reviewMistakes.
  ///
  /// In en, this message translates to:
  /// **'Review mistakes'**
  String get reviewMistakes;

  /// No description provided for @retryWeakAreas.
  ///
  /// In en, this message translates to:
  /// **'Retry weak areas'**
  String get retryWeakAreas;

  /// No description provided for @yourAnswer.
  ///
  /// In en, this message translates to:
  /// **'Your answer'**
  String get yourAnswer;

  /// No description provided for @correctAnswer.
  ///
  /// In en, this message translates to:
  /// **'Correct answer'**
  String get correctAnswer;

  /// No description provided for @termsLearned.
  ///
  /// In en, this message translates to:
  /// **'Terms learned'**
  String get termsLearned;

  /// No description provided for @lessonsCompleted.
  ///
  /// In en, this message translates to:
  /// **'Lessons completed'**
  String get lessonsCompleted;

  /// No description provided for @flashcardsReviewed.
  ///
  /// In en, this message translates to:
  /// **'Flashcards reviewed'**
  String get flashcardsReviewed;

  /// No description provided for @quizAccuracy.
  ///
  /// In en, this message translates to:
  /// **'Quiz accuracy'**
  String get quizAccuracy;

  /// No description provided for @dueReviews.
  ///
  /// In en, this message translates to:
  /// **'Due reviews'**
  String get dueReviews;

  /// No description provided for @longestStreak.
  ///
  /// In en, this message translates to:
  /// **'Longest streak'**
  String get longestStreak;

  /// No description provided for @termOfTheDay.
  ///
  /// In en, this message translates to:
  /// **'Term of the day'**
  String get termOfTheDay;

  /// No description provided for @reportReason.
  ///
  /// In en, this message translates to:
  /// **'What seems wrong?'**
  String get reportReason;

  /// No description provided for @incorrectDefinition.
  ///
  /// In en, this message translates to:
  /// **'Incorrect definition'**
  String get incorrectDefinition;

  /// No description provided for @confusingExplanation.
  ///
  /// In en, this message translates to:
  /// **'Confusing explanation'**
  String get confusingExplanation;

  /// No description provided for @pronunciationIssue.
  ///
  /// In en, this message translates to:
  /// **'Pronunciation issue'**
  String get pronunciationIssue;

  /// No description provided for @translationIssue.
  ///
  /// In en, this message translates to:
  /// **'Translation issue'**
  String get translationIssue;

  /// No description provided for @incorrectRelatedTerm.
  ///
  /// In en, this message translates to:
  /// **'Incorrect related term'**
  String get incorrectRelatedTerm;

  /// No description provided for @other.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get other;

  /// No description provided for @optionalNote.
  ///
  /// In en, this message translates to:
  /// **'Optional note'**
  String get optionalNote;

  /// No description provided for @submitReport.
  ///
  /// In en, this message translates to:
  /// **'Submit report'**
  String get submitReport;

  /// No description provided for @reportQueued.
  ///
  /// In en, this message translates to:
  /// **'Report saved and queued for review.'**
  String get reportQueued;

  /// No description provided for @offlineAvailable.
  ///
  /// In en, this message translates to:
  /// **'Available offline from the local terminology dataset'**
  String get offlineAvailable;

  /// No description provided for @answerRequired.
  ///
  /// In en, this message translates to:
  /// **'Select an answer to continue.'**
  String get answerRequired;

  /// No description provided for @searchAbbreviations.
  ///
  /// In en, this message translates to:
  /// **'Search abbreviations'**
  String get searchAbbreviations;

  /// No description provided for @contextLabel.
  ///
  /// In en, this message translates to:
  /// **'Context'**
  String get contextLabel;

  /// No description provided for @alternativeMeanings.
  ///
  /// In en, this message translates to:
  /// **'Other possible meanings'**
  String get alternativeMeanings;

  /// No description provided for @allCategories.
  ///
  /// In en, this message translates to:
  /// **'All categories'**
  String get allCategories;

  /// No description provided for @noSavedItems.
  ///
  /// In en, this message translates to:
  /// **'No saved terminology yet'**
  String get noSavedItems;

  /// No description provided for @noSavedItemsBody.
  ///
  /// In en, this message translates to:
  /// **'Save terms and word parts to keep them available here offline.'**
  String get noSavedItemsBody;

  /// No description provided for @remove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get remove;

  /// No description provided for @previous.
  ///
  /// In en, this message translates to:
  /// **'Previous'**
  String get previous;

  /// No description provided for @sessionProgress.
  ///
  /// In en, this message translates to:
  /// **'{current} of {total}'**
  String sessionProgress(int current, int total);

  /// No description provided for @learningRecommendation.
  ///
  /// In en, this message translates to:
  /// **'Learning recommendation'**
  String get learningRecommendation;

  /// No description provided for @continueUnfinishedLesson.
  ///
  /// In en, this message translates to:
  /// **'Continue your unfinished lesson, then review due flashcards.'**
  String get continueUnfinishedLesson;

  /// No description provided for @noLessons.
  ///
  /// In en, this message translates to:
  /// **'No lessons match these filters.'**
  String get noLessons;

  /// No description provided for @lessonSection.
  ///
  /// In en, this message translates to:
  /// **'Lesson section'**
  String get lessonSection;

  /// No description provided for @lessonProgressLabel.
  ///
  /// In en, this message translates to:
  /// **'{percent}% complete'**
  String lessonProgressLabel(int percent);

  /// No description provided for @noFlashcardsDue.
  ///
  /// In en, this message translates to:
  /// **'No flashcards are due'**
  String get noFlashcardsDue;

  /// No description provided for @noFlashcardsDueBody.
  ///
  /// In en, this message translates to:
  /// **'Your review schedule is clear for now.'**
  String get noFlashcardsDueBody;

  /// No description provided for @again.
  ///
  /// In en, this message translates to:
  /// **'Again'**
  String get again;

  /// No description provided for @hard.
  ///
  /// In en, this message translates to:
  /// **'Hard'**
  String get hard;

  /// No description provided for @good.
  ///
  /// In en, this message translates to:
  /// **'Good'**
  String get good;

  /// No description provided for @quizComplete.
  ///
  /// In en, this message translates to:
  /// **'Finish quiz'**
  String get quizComplete;

  /// No description provided for @answerExplanation.
  ///
  /// In en, this message translates to:
  /// **'Answer explanation'**
  String get answerExplanation;

  /// No description provided for @noMistakes.
  ///
  /// In en, this message translates to:
  /// **'No mistakes to review.'**
  String get noMistakes;

  /// No description provided for @accuracyPercent.
  ///
  /// In en, this message translates to:
  /// **'{percent}%'**
  String accuracyPercent(int percent);

  /// No description provided for @contentType.
  ///
  /// In en, this message translates to:
  /// **'Content type'**
  String get contentType;

  /// No description provided for @reportPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Reports are stored for editorial review and never change medical content automatically.'**
  String get reportPrivacy;

  /// No description provided for @categoryTerms.
  ///
  /// In en, this message translates to:
  /// **'Terms in this category'**
  String get categoryTerms;

  /// No description provided for @openTerm.
  ///
  /// In en, this message translates to:
  /// **'Open term'**
  String get openTerm;

  /// No description provided for @reviewedContent.
  ///
  /// In en, this message translates to:
  /// **'Reviewed content'**
  String get reviewedContent;

  /// No description provided for @unknownValue.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get unknownValue;

  /// No description provided for @noAbbreviations.
  ///
  /// In en, this message translates to:
  /// **'No matching abbreviations found.'**
  String get noAbbreviations;

  /// No description provided for @decoderDefinitionNote.
  ///
  /// In en, this message translates to:
  /// **'Word parts explain structure. The medical meaning below comes from the reviewed term record.'**
  String get decoderDefinitionNote;

  /// No description provided for @dailyTermUnavailable.
  ///
  /// In en, this message translates to:
  /// **'No daily term is available.'**
  String get dailyTermUnavailable;

  /// No description provided for @strongestCategory.
  ///
  /// In en, this message translates to:
  /// **'Strongest category'**
  String get strongestCategory;

  /// No description provided for @needsReviewCategory.
  ///
  /// In en, this message translates to:
  /// **'Category needing review'**
  String get needsReviewCategory;

  /// No description provided for @commonTerms.
  ///
  /// In en, this message translates to:
  /// **'Common terms'**
  String get commonTerms;

  /// No description provided for @authEmailExists.
  ///
  /// In en, this message translates to:
  /// **'An account with this email already exists. Sign in or reset your password.'**
  String get authEmailExists;

  /// No description provided for @authInvalidCredentials.
  ///
  /// In en, this message translates to:
  /// **'The email or password is incorrect.'**
  String get authInvalidCredentials;

  /// No description provided for @authConnectionFailed.
  ///
  /// In en, this message translates to:
  /// **'Cannot reach the server. Check your connection and try again.'**
  String get authConnectionFailed;

  /// No description provided for @authRateLimited.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Please wait a minute and try again.'**
  String get authRateLimited;

  /// No description provided for @confirmDeleteAccount.
  ///
  /// In en, this message translates to:
  /// **'Permanently delete your signed-in account and its server records, revoke every session, and remove this profile’s local records, prescription images, and reminders? This cannot be undone and requires a connection to the server. Other profiles on this device are not deleted.'**
  String get confirmDeleteAccount;

  /// No description provided for @accountDeleted.
  ///
  /// In en, this message translates to:
  /// **'Your account and this profile’s local data were deleted.'**
  String get accountDeleted;

  /// No description provided for @dataDeletionFailed.
  ///
  /// In en, this message translates to:
  /// **'Deletion could not finish. Check your connection or device storage and try again. Completion has not been confirmed.'**
  String get dataDeletionFailed;

  /// No description provided for @privacyPolicyBody.
  ///
  /// In en, this message translates to:
  /// **'Your data on this device\nMediExplain stores prescriptions, private scan images, medication plans, dose history, bookmarks, and learning progress in the app’s local storage. Signed-in profiles use separate local databases. Session credentials use platform secure storage.\n\nServer and AI processing\nSigning in sends account information to your configured server. Account synchronization uploads supported records when enabled. Pending medication deletions may still be sent when backup uploads are off. Choosing a prescription image for recognition sends that image to the server and Google Gemini or Groq. Medicine explanations and assistant questions can also be processed by Gemini or Groq, or by Ollama on the computer hosting your backend when fallback is available. Images are not sent to the text-only Ollama model. Avoid including unnecessary identifying details. Provider processing is subject to that provider’s policies.\n\nYour controls\nManage saved data removes this profile’s local records, images, and reminders and resets app preferences; it does not delete your account or existing cloud backups. Existing cloud-deletion requests are retained. Delete account requires an authenticated server connection and also clears this profile locally after server confirmation. Other signed-in devices may retain their own local copies until those devices are cleared. You can separately remove individual medications or prescription scans. Turning off notifications cancels app reminders without deleting your dose history.\n\nRetention and limits\nPrescription images can be removed automatically after confirmation using the image-retention setting. Already shared files and copies outside the app cannot be withdrawn. This local development setup depends on the configured backend and its operator’s storage and access controls. App analytics are not sent by the current no-op analytics implementation.'**
  String get privacyPolicyBody;

  /// No description provided for @termsBody.
  ///
  /// In en, this message translates to:
  /// **'Using MediExplain\nMediExplain helps you understand medical words, prescriptions, and general medicine information. It does not diagnose conditions, prescribe treatment, or replace a pharmacist or clinician.\n\nCheck recognized information\nHandwriting recognition and AI explanations can be incomplete or wrong. Compare each medicine name, strength, form, dose, and frequency with the original prescription or medicine label. Ask a pharmacist or prescriber to clarify anything uncertain. Do not change treatment based only on an app result.\n\nReminders and availability\nReminders record the instructions you reviewed; they do not establish which treatment is appropriate. Device permissions, notification limits, battery settings, and connectivity can affect reminders and cloud features. Keep another way to track time-sensitive medication. Cloud recognition depends on provider availability and quota.\n\nYour records\nOnly upload images and information you are entitled to use. Protect your device and account. Review the Privacy policy and the deletion confirmation before removing data. These in-app use guidelines describe the current build; they do not claim regulatory approval or clinical validation.'**
  String get termsBody;

  /// No description provided for @dataSourcesBody.
  ///
  /// In en, this message translates to:
  /// **'Medicine references\nMedicine identity and ingredient relationships use available NLM RxNorm references. Patient information can use MedlinePlus and DailyMed label material. Source coverage varies by medicine and country. A reference for an ingredient does not confirm a prescribed product, dose, or release type.\n\nLearning content\nThe bundled development catalogue contains 30 lessons, 60 flashcards, four quiz questions, and medical terminology. It includes original development summaries with attributed source references. It is not a clinically approved production catalogue. Each term’s Source information shows its own provenance and review details.\n\nAI and image recognition\nGemini reads selected prescription images and separates medicine fields, with Groq as cloud fallback. The assistant uses Gemini first, then Groq, then qwen3:1.7b through Ollama as its text fallback. Apple Vision, Android ML Kit, and an optional server handwriting recognizer support other recognition tools. AI models are processing tools, not medical reference sources. Explanations must retain source attribution.\n\nReview the source\nMedicine explanations include their actual source references. A failed lookup or an ambiguous name should be corrected or checked with a pharmacist; the app must not invent the missing information.'**
  String get dataSourcesBody;

  /// No description provided for @sourceWebsite.
  ///
  /// In en, this message translates to:
  /// **'Reference website'**
  String get sourceWebsite;

  /// No description provided for @serverConnection.
  ///
  /// In en, this message translates to:
  /// **'Server connection'**
  String get serverConnection;

  /// No description provided for @serverAddress.
  ///
  /// In en, this message translates to:
  /// **'Server address'**
  String get serverAddress;

  /// No description provided for @testAndSave.
  ///
  /// In en, this message translates to:
  /// **'Test and save'**
  String get testAndSave;

  /// No description provided for @serverConnectionSaved.
  ///
  /// In en, this message translates to:
  /// **'Server connection updated. You can retry your saved scan.'**
  String get serverConnectionSaved;

  /// No description provided for @serverAddressInvalid.
  ///
  /// In en, this message translates to:
  /// **'Use a private LAN HTTP address or HTTPS server URL ending with /api/v1/, without a username, password or query.'**
  String get serverAddressInvalid;

  /// No description provided for @serverConnectionFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not verify the server or save the address. Keep the Mac and phone on the same Wi-Fi, keep the API running, and allow Local Network access.'**
  String get serverConnectionFailed;

  /// No description provided for @serverConnectionHelp.
  ///
  /// In en, this message translates to:
  /// **'Automatic connection follows your Mac’s address on the same Wi-Fi. For a different trusted server, turn automatic connection off and enter its address. Testing sends no login or prescription.'**
  String get serverConnectionHelp;

  /// No description provided for @automaticServerConnection.
  ///
  /// In en, this message translates to:
  /// **'Find my Mac automatically'**
  String get automaticServerConnection;

  /// No description provided for @automaticServerConnectionHelp.
  ///
  /// In en, this message translates to:
  /// **'Reconnect using the Mac’s name when both devices change Wi-Fi.'**
  String get automaticServerConnectionHelp;

  /// No description provided for @learningSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Progress could not be saved. Try again.'**
  String get learningSaveFailed;

  /// No description provided for @learningLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'This lesson could not be loaded. Try again.'**
  String get learningLoadFailed;

  /// No description provided for @speechUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Audio could not be played on this device. Try again.'**
  String get speechUnavailable;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ur'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ur':
      return AppLocalizationsUr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
