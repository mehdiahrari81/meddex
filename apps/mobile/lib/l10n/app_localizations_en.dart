// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'MediExplain';

  @override
  String get retry => 'Try again';

  @override
  String get passwordResetInstructions =>
      'Enter your account email to request a reset code. Check your inbox, then enter the code below.';

  @override
  String get enterResetCode => 'Enter reset code';

  @override
  String get resetPasswordTitle => 'Reset password';

  @override
  String get resetPasswordDescription =>
      'Paste the code from your reset email and choose a new password. This signs out all existing sessions.';

  @override
  String get resetCode => 'Reset code';

  @override
  String get resetCodeRequired => 'Paste the complete code from your email.';

  @override
  String get newPassword => 'New password';

  @override
  String get confirmPassword => 'Confirm password';

  @override
  String get passwordsDoNotMatch => 'Passwords do not match.';

  @override
  String get passwordResetComplete =>
      'Password updated. Sign in with your new password.';

  @override
  String get passwordResetFailed =>
      'Could not reset your password. Check your connection and code, or request a new code if it has expired.';

  @override
  String get loadingSessions => 'Loading active sessions';

  @override
  String get sessionsDescription =>
      'Review your active sign-ins. Revoke a session to sign that device out. An internet connection is required.';

  @override
  String get sessionsLoadFailed =>
      'Could not load sessions. Check your connection and try again.';

  @override
  String get currentSession => 'This device';

  @override
  String get otherSession => 'Another sign-in';

  @override
  String sessionCreated(String date) {
    return 'Signed in: $date';
  }

  @override
  String sessionExpires(String date) {
    return 'Expires: $date';
  }

  @override
  String get revokeSession => 'Revoke session';

  @override
  String get revokeSessionConfirmation =>
      'This sign-in will lose access to your account. Revoking this device signs you out here too.';

  @override
  String get sessionRevokeFailed =>
      'Could not revoke the session. Check your connection and try again.';

  @override
  String get cancel => 'Cancel';

  @override
  String get continueLabel => 'Continue';

  @override
  String get back => 'Back';

  @override
  String get done => 'Done';

  @override
  String get notAvailableYet => 'Coming in a later module';

  @override
  String get startupTitle => 'Preparing MediExplain';

  @override
  String get startupMessage =>
      'Setting up your secure, offline-ready experience.';

  @override
  String get startupErrorTitle => 'MediExplain could not start';

  @override
  String get startupErrorMessage =>
      'Your data was not changed. Check your device storage and try again.';

  @override
  String get offline => 'Offline';

  @override
  String get reconnecting => 'Reconnecting';

  @override
  String get synchronizing => 'Synchronizing';

  @override
  String get home => 'Home';

  @override
  String get scan => 'Scan';

  @override
  String get learn => 'Learn';

  @override
  String get saved => 'Saved';

  @override
  String get profile => 'Profile';

  @override
  String get welcomeTitle => 'Medical language, made clearer';

  @override
  String get welcomeBody =>
      'Build confidence when reading medical terms and prescription information.';

  @override
  String get understandTitle => 'Understand';

  @override
  String get understandBody =>
      'Get plain-language, source-aware explanations of medical terms.';

  @override
  String get prescriptionTitle => 'Prescription Helper';

  @override
  String get prescriptionBody =>
      'Later, scan prescription text and verify every important detail before using it.';

  @override
  String get learnTitle => 'Learn';

  @override
  String get learnBody => 'Study terminology at a level that fits your goals.';

  @override
  String get privacyTitle => 'Privacy by design';

  @override
  String get privacyBody =>
      'We minimize data collection. Sensitive credentials use secure device storage, and prescription images are never uploaded automatically.';

  @override
  String get safetyTitle => 'Education, not medical advice';

  @override
  String get safetyBody =>
      'MediExplain does not diagnose, prescribe, change doses, or replace a doctor or pharmacist. Unclear scanned information must be verified.';

  @override
  String get languageTitle => 'Choose your language';

  @override
  String get english => 'English';

  @override
  String get urdu => 'Urdu';

  @override
  String get accessibilityTitle => 'Make it comfortable';

  @override
  String get largerText => 'Larger text';

  @override
  String get largerControls => 'Larger controls';

  @override
  String get reduceMotion => 'Reduce motion';

  @override
  String get highReadability => 'High-readability mode';

  @override
  String get usageModeTitle => 'How will you use MediExplain?';

  @override
  String get patientMode => 'Patient';

  @override
  String get patientModeBody =>
      'Clear, practical language and readable information.';

  @override
  String get studentMode => 'Student';

  @override
  String get studentModeBody =>
      'Technical vocabulary and learning-focused detail.';

  @override
  String get guestMode => 'Guest';

  @override
  String get guestModeBody => 'Use non-sensitive features without an account.';

  @override
  String get consentTitle => 'One final check';

  @override
  String get consentBody =>
      'I understand that MediExplain provides educational information and does not replace professional medical advice.';

  @override
  String get consentRequired =>
      'Please acknowledge the medical-safety notice to continue.';

  @override
  String get getStarted => 'Get started';

  @override
  String get homeGreeting => 'A clearer path through medical language';

  @override
  String get homeSubtitle => 'What would you like to understand today?';

  @override
  String get scanPrescription => 'Scan prescription';

  @override
  String get scanPrescriptionBody =>
      'Capture and verify prescription information';

  @override
  String get scanMedicalTerm => 'Scan medical term';

  @override
  String get scanMedicalTermBody => 'Recognize a term from text';

  @override
  String get searchMedicalTerm => 'Search medical term';

  @override
  String get searchMedicalTermBody => 'Type a term to understand it';

  @override
  String get learnMedicalTerms => 'Learn medical terms';

  @override
  String get learnMedicalTermsBody => 'Build knowledge step by step';

  @override
  String get yourSpace => 'Your space';

  @override
  String get continueLearning => 'Continue learning';

  @override
  String get recentActivity => 'Recent activity';

  @override
  String get savedContent => 'Saved content';

  @override
  String get medicationReminders => 'Medication reminders';

  @override
  String get nothingHereYet => 'Nothing here yet';

  @override
  String get futureContentBody =>
      'This area is ready for a future MediExplain module.';

  @override
  String get medicalDisclaimerShort =>
      'Educational information only — not a diagnosis or prescription.';

  @override
  String get signIn => 'Sign in';

  @override
  String get createAccount => 'Create account';

  @override
  String get continueAsGuest => 'Continue as guest';

  @override
  String get email => 'Email';

  @override
  String get password => 'Password';

  @override
  String get displayName => 'Display name';

  @override
  String get forgotPassword => 'Forgot password?';

  @override
  String get emailRequired => 'Enter your email address.';

  @override
  String get emailInvalid => 'Enter a valid email address.';

  @override
  String get passwordRequired => 'Enter your password.';

  @override
  String get passwordRequirements =>
      'Use at least 12 characters with upper and lowercase letters, a number, and a symbol.';

  @override
  String get nameRequired => 'Enter your name.';

  @override
  String get authenticationFailed =>
      'We could not complete that request. Check your details and connection.';

  @override
  String get settings => 'Settings';

  @override
  String get appearance => 'Appearance';

  @override
  String get theme => 'Theme';

  @override
  String get systemTheme => 'System';

  @override
  String get lightTheme => 'Light';

  @override
  String get darkTheme => 'Dark';

  @override
  String get textSize => 'Text size';

  @override
  String get language => 'Language';

  @override
  String get accessibility => 'Accessibility';

  @override
  String get hapticFeedback => 'Haptic feedback';

  @override
  String get textToSpeech => 'Text to speech';

  @override
  String get medicalExplanation => 'Medical explanation';

  @override
  String get userMode => 'User mode';

  @override
  String get explanationLevel => 'Explanation level';

  @override
  String get simple => 'Simple';

  @override
  String get standard => 'Standard';

  @override
  String get technical => 'Technical';

  @override
  String get notifications => 'Notifications';

  @override
  String get notificationsMaster => 'Allow notifications';

  @override
  String get remindersPlaceholder => 'Medication reminders';

  @override
  String get remindersNotConfigured => 'Available in Module 5';

  @override
  String get privacy => 'Privacy';

  @override
  String get localData => 'Local data';

  @override
  String get manageSavedData => 'Manage saved data';

  @override
  String get syncPreference => 'Synchronize account data';

  @override
  String get analyticsPreference => 'Share anonymous app analytics';

  @override
  String get deleteAccount => 'Delete account';

  @override
  String get security => 'Security';

  @override
  String get manageSessions => 'Manage sessions';

  @override
  String get biometricLock => 'Biometric app lock';

  @override
  String get about => 'About';

  @override
  String get appVersion => 'App version';

  @override
  String get privacyPolicy => 'Privacy policy';

  @override
  String get terms => 'Terms';

  @override
  String get dataSources => 'Data sources';

  @override
  String get openSourceLicenses => 'Open-source licences';

  @override
  String get medicalDisclaimer => 'Medical-information disclaimer';

  @override
  String get signOut => 'Sign out';

  @override
  String get resetOnboarding => 'Review onboarding again';

  @override
  String get account => 'Account';

  @override
  String get signedOut => 'You are using MediExplain as a guest.';

  @override
  String get signedIn => 'Your account session is active on this device.';

  @override
  String get confirmSignOut => 'Sign out on this device?';

  @override
  String get confirmDeleteLocalData =>
      'Delete this profile’s prescriptions, images, medications, dose history, bookmarks, and learning progress from this device, and reset app preferences? This cannot be undone. Your account, existing cloud backups, reference lessons, and other profiles stay available. Unsynced uploads are discarded; existing cloud-deletion requests are kept for retry.';

  @override
  String get deleteLocalData => 'Delete local data';

  @override
  String get dataDeleted => 'Local data was deleted.';

  @override
  String get accountDeletionInfo =>
      'Account deletion requires an authenticated connection and will revoke all sessions.';

  @override
  String signedInAs(String email) {
    return 'Signed in as $email';
  }

  @override
  String get unknownPageTitle => 'Page not found';

  @override
  String get unknownPageBody =>
      'That page does not exist or is no longer available.';

  @override
  String get goHome => 'Go home';

  @override
  String get source => 'Source';

  @override
  String get confidence => 'Confidence';

  @override
  String get verificationRequired => 'Verification required';

  @override
  String get developmentEmailNotice =>
      'Password-reset email delivery is not configured for production.';

  @override
  String get requestReset => 'Request reset';

  @override
  String get resetRequestSent =>
      'If an account exists, reset instructions will be sent by the configured delivery service.';

  @override
  String get terminologySearch => 'Medical terminology';

  @override
  String get searchHint => 'Search a term, phrase, or abbreviation';

  @override
  String get searchStartTitle => 'What would you like to understand?';

  @override
  String get searchStartBody =>
      'Try a medical term, common phrase such as ‘high blood pressure,’ or an abbreviation.';

  @override
  String get recentSearches => 'Recent searches';

  @override
  String get clearAll => 'Clear all';

  @override
  String get noSearchResults => 'No matching term found';

  @override
  String get noSearchResultsBody =>
      'Check the spelling or try a shorter phrase. MediExplain will not guess a medical meaning.';

  @override
  String didYouMean(String term) {
    return 'Did you mean $term?';
  }

  @override
  String get multipleMeanings => 'Multiple medical meanings found';

  @override
  String get multipleMeaningsBody =>
      'This abbreviation is context-dependent. Choose only when the surrounding information makes the meaning clear.';

  @override
  String matchedAs(String type) {
    return 'Matched as $type';
  }

  @override
  String get simpleMeaning => 'Simple meaning';

  @override
  String get standardMeaning => 'Standard explanation';

  @override
  String get technicalDefinition => 'Technical definition';

  @override
  String get wordBreakdown => 'Word breakdown';

  @override
  String get commonLanguage => 'Common-language equivalent';

  @override
  String get synonyms => 'Synonyms';

  @override
  String get relatedTerms => 'Related terms';

  @override
  String get examples => 'Examples';

  @override
  String get sourceInformation => 'Source information';

  @override
  String get developmentContentNotice =>
      'Reviewed development content — not yet an approved production corpus';

  @override
  String get save => 'Save';

  @override
  String get unsave => 'Remove from saved';

  @override
  String get speak => 'Hear pronunciation';

  @override
  String get stopSpeaking => 'Stop pronunciation';

  @override
  String get reportContent => 'Report a content issue';

  @override
  String get wordDecoder => 'Medical word decoder';

  @override
  String get decoderHint => 'Enter a medical word';

  @override
  String get decode => 'Break down word';

  @override
  String get partialBreakdown => 'Partial word breakdown available';

  @override
  String get noBreakdown => 'No defensible breakdown found';

  @override
  String get noBreakdownBody =>
      'Unknown fragments are left unresolved. MediExplain does not force a word into familiar parts.';

  @override
  String unknownFragment(String fragment) {
    return 'Unknown fragment: $fragment';
  }

  @override
  String get abbreviationExplorer => 'Abbreviation explorer';

  @override
  String get abbreviationSafety =>
      'Medical abbreviations can have more than one meaning. Always use the surrounding context.';

  @override
  String get prefixes => 'Prefixes';

  @override
  String get roots => 'Roots';

  @override
  String get suffixes => 'Suffixes';

  @override
  String get categories => 'Categories';

  @override
  String get browseWordParts => 'Browse word parts';

  @override
  String get origin => 'Origin';

  @override
  String get savedTerminology => 'Saved terminology';

  @override
  String get sortAlphabetically => 'Alphabetical';

  @override
  String get sortRecentlySaved => 'Recently saved';

  @override
  String get searchSaved => 'Search saved items';

  @override
  String get learningHome => 'Learn medical language';

  @override
  String get todayTerm => 'Today\'s term';

  @override
  String get lessons => 'Lessons';

  @override
  String get flashcards => 'Flashcards';

  @override
  String get quizzes => 'Quizzes';

  @override
  String get progress => 'Progress';

  @override
  String get currentStreak => 'Current streak';

  @override
  String dayCount(int count) {
    return '$count days';
  }

  @override
  String dueReviewCount(int count) {
    return '$count reviews due';
  }

  @override
  String get lessonList => 'Learning lessons';

  @override
  String minutes(int count) {
    return '$count min';
  }

  @override
  String get learningObjectives => 'Learning objectives';

  @override
  String get resumeLesson => 'Resume lesson';

  @override
  String get startLesson => 'Start lesson';

  @override
  String get nextSection => 'Next section';

  @override
  String get completeLesson => 'Complete lesson';

  @override
  String get lessonCompleted => 'Lesson completed';

  @override
  String get revealAnswer => 'Reveal answer';

  @override
  String get knewIt => 'Knew it';

  @override
  String get unsure => 'Unsure';

  @override
  String get didNotKnow => 'Didn\'t know';

  @override
  String get easy => 'Easy';

  @override
  String get flashcardComplete => 'Review session complete';

  @override
  String get quizSetup => 'Quiz setup';

  @override
  String get questionCount => 'Number of questions';

  @override
  String get difficulty => 'Difficulty';

  @override
  String get beginner => 'Beginner';

  @override
  String get intermediate => 'Intermediate';

  @override
  String get advanced => 'Advanced';

  @override
  String get startQuiz => 'Start quiz';

  @override
  String get submitAnswer => 'Submit answer';

  @override
  String get nextQuestion => 'Next question';

  @override
  String get quizResults => 'Quiz results';

  @override
  String score(int correct, int total) {
    return 'Score: $correct of $total';
  }

  @override
  String get reviewMistakes => 'Review mistakes';

  @override
  String get retryWeakAreas => 'Retry weak areas';

  @override
  String get yourAnswer => 'Your answer';

  @override
  String get correctAnswer => 'Correct answer';

  @override
  String get termsLearned => 'Terms learned';

  @override
  String get lessonsCompleted => 'Lessons completed';

  @override
  String get flashcardsReviewed => 'Flashcards reviewed';

  @override
  String get quizAccuracy => 'Quiz accuracy';

  @override
  String get dueReviews => 'Due reviews';

  @override
  String get longestStreak => 'Longest streak';

  @override
  String get termOfTheDay => 'Term of the day';

  @override
  String get reportReason => 'What seems wrong?';

  @override
  String get incorrectDefinition => 'Incorrect definition';

  @override
  String get confusingExplanation => 'Confusing explanation';

  @override
  String get pronunciationIssue => 'Pronunciation issue';

  @override
  String get translationIssue => 'Translation issue';

  @override
  String get incorrectRelatedTerm => 'Incorrect related term';

  @override
  String get other => 'Other';

  @override
  String get optionalNote => 'Optional note';

  @override
  String get submitReport => 'Submit report';

  @override
  String get reportQueued => 'Report saved and queued for review.';

  @override
  String get offlineAvailable =>
      'Available offline from the local terminology dataset';

  @override
  String get answerRequired => 'Select an answer to continue.';

  @override
  String get searchAbbreviations => 'Search abbreviations';

  @override
  String get contextLabel => 'Context';

  @override
  String get alternativeMeanings => 'Other possible meanings';

  @override
  String get allCategories => 'All categories';

  @override
  String get noSavedItems => 'No saved terminology yet';

  @override
  String get noSavedItemsBody =>
      'Save terms and word parts to keep them available here offline.';

  @override
  String get remove => 'Remove';

  @override
  String get previous => 'Previous';

  @override
  String sessionProgress(int current, int total) {
    return '$current of $total';
  }

  @override
  String get learningRecommendation => 'Learning recommendation';

  @override
  String get continueUnfinishedLesson =>
      'Continue your unfinished lesson, then review due flashcards.';

  @override
  String get noLessons => 'No lessons match these filters.';

  @override
  String get lessonSection => 'Lesson section';

  @override
  String lessonProgressLabel(int percent) {
    return '$percent% complete';
  }

  @override
  String get noFlashcardsDue => 'No flashcards are due';

  @override
  String get noFlashcardsDueBody => 'Your review schedule is clear for now.';

  @override
  String get again => 'Again';

  @override
  String get hard => 'Hard';

  @override
  String get good => 'Good';

  @override
  String get quizComplete => 'Finish quiz';

  @override
  String get answerExplanation => 'Answer explanation';

  @override
  String get noMistakes => 'No mistakes to review.';

  @override
  String accuracyPercent(int percent) {
    return '$percent%';
  }

  @override
  String get contentType => 'Content type';

  @override
  String get reportPrivacy =>
      'Reports are stored for editorial review and never change medical content automatically.';

  @override
  String get categoryTerms => 'Terms in this category';

  @override
  String get openTerm => 'Open term';

  @override
  String get reviewedContent => 'Reviewed content';

  @override
  String get unknownValue => 'Unknown';

  @override
  String get noAbbreviations => 'No matching abbreviations found.';

  @override
  String get decoderDefinitionNote =>
      'Word parts explain structure. The medical meaning below comes from the reviewed term record.';

  @override
  String get dailyTermUnavailable => 'No daily term is available.';

  @override
  String get strongestCategory => 'Strongest category';

  @override
  String get needsReviewCategory => 'Category needing review';

  @override
  String get commonTerms => 'Common terms';

  @override
  String get authEmailExists =>
      'An account with this email already exists. Sign in or reset your password.';

  @override
  String get authInvalidCredentials => 'The email or password is incorrect.';

  @override
  String get authConnectionFailed =>
      'Cannot reach the server. Check your connection and try again.';

  @override
  String get authRateLimited =>
      'Too many attempts. Please wait a minute and try again.';

  @override
  String get confirmDeleteAccount =>
      'Permanently delete your signed-in account and its server records, revoke every session, and remove this profile’s local records, prescription images, and reminders? This cannot be undone and requires a connection to the server. Other profiles on this device are not deleted.';

  @override
  String get accountDeleted =>
      'Your account and this profile’s local data were deleted.';

  @override
  String get dataDeletionFailed =>
      'Deletion could not finish. Check your connection or device storage and try again. Completion has not been confirmed.';

  @override
  String get privacyPolicyBody =>
      'Your data on this device\nMediExplain stores prescriptions, private scan images, medication plans, dose history, bookmarks, and learning progress in the app’s local storage. Signed-in profiles use separate local databases. Session credentials use platform secure storage.\n\nServer and AI processing\nSigning in sends account information to your configured server. Account synchronization uploads supported records when enabled. Pending medication deletions may still be sent when backup uploads are off. Choosing a prescription image for recognition sends that image to the server and Google Gemini or Groq. Medicine explanations and assistant questions can also be processed by Gemini or Groq, or by Ollama on the computer hosting your backend when fallback is available. Images are not sent to the text-only Ollama model. Avoid including unnecessary identifying details. Provider processing is subject to that provider’s policies.\n\nYour controls\nManage saved data removes this profile’s local records, images, and reminders and resets app preferences; it does not delete your account or existing cloud backups. Existing cloud-deletion requests are retained. Delete account requires an authenticated server connection and also clears this profile locally after server confirmation. Other signed-in devices may retain their own local copies until those devices are cleared. You can separately remove individual medications or prescription scans. Turning off notifications cancels app reminders without deleting your dose history.\n\nRetention and limits\nPrescription images can be removed automatically after confirmation using the image-retention setting. Already shared files and copies outside the app cannot be withdrawn. This local development setup depends on the configured backend and its operator’s storage and access controls. App analytics are not sent by the current no-op analytics implementation.';

  @override
  String get termsBody =>
      'Using MediExplain\nMediExplain helps you understand medical words, prescriptions, and general medicine information. It does not diagnose conditions, prescribe treatment, or replace a pharmacist or clinician.\n\nCheck recognized information\nHandwriting recognition and AI explanations can be incomplete or wrong. Compare each medicine name, strength, form, dose, and frequency with the original prescription or medicine label. Ask a pharmacist or prescriber to clarify anything uncertain. Do not change treatment based only on an app result.\n\nReminders and availability\nReminders record the instructions you reviewed; they do not establish which treatment is appropriate. Device permissions, notification limits, battery settings, and connectivity can affect reminders and cloud features. Keep another way to track time-sensitive medication. Cloud recognition depends on provider availability and quota.\n\nYour records\nOnly upload images and information you are entitled to use. Protect your device and account. Review the Privacy policy and the deletion confirmation before removing data. These in-app use guidelines describe the current build; they do not claim regulatory approval or clinical validation.';

  @override
  String get dataSourcesBody =>
      'Medicine references\nMedicine identity and ingredient relationships use available NLM RxNorm references. Patient information can use MedlinePlus and DailyMed label material. Source coverage varies by medicine and country. A reference for an ingredient does not confirm a prescribed product, dose, or release type.\n\nLearning content\nThe bundled development catalogue contains 30 lessons, 60 flashcards, four quiz questions, and medical terminology. It includes original development summaries with attributed source references. It is not a clinically approved production catalogue. Each term’s Source information shows its own provenance and review details.\n\nAI and image recognition\nGemini reads selected prescription images and separates medicine fields, with Groq as cloud fallback. The assistant uses Gemini first, then Groq, then qwen3:1.7b through Ollama as its text fallback. Apple Vision, Android ML Kit, and an optional server handwriting recognizer support other recognition tools. AI models are processing tools, not medical reference sources. Explanations must retain source attribution.\n\nReview the source\nMedicine explanations include their actual source references. A failed lookup or an ambiguous name should be corrected or checked with a pharmacist; the app must not invent the missing information.';

  @override
  String get sourceWebsite => 'Reference website';

  @override
  String get serverConnection => 'Server connection';

  @override
  String get serverAddress => 'Server address';

  @override
  String get testAndSave => 'Test and save';

  @override
  String get serverConnectionSaved =>
      'Server connection updated. You can retry your saved scan.';

  @override
  String get serverAddressInvalid =>
      'Use a private LAN HTTP address or HTTPS server URL ending with /api/v1/, without a username, password or query.';

  @override
  String get serverConnectionFailed =>
      'Could not verify the server or save the address. Keep the Mac and phone on the same Wi-Fi, keep the API running, and allow Local Network access.';

  @override
  String get serverConnectionHelp =>
      'Automatic connection follows your Mac’s address on the same Wi-Fi. For a different trusted server, turn automatic connection off and enter its address. Testing sends no login or prescription.';

  @override
  String get automaticServerConnection => 'Find my Mac automatically';

  @override
  String get automaticServerConnectionHelp =>
      'Reconnect using the Mac’s name when both devices change Wi-Fi.';

  @override
  String get learningSaveFailed => 'Progress could not be saved. Try again.';

  @override
  String get learningLoadFailed =>
      'This lesson could not be loaded. Try again.';

  @override
  String get speechUnavailable =>
      'Audio could not be played on this device. Try again.';
}
