// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Urdu (`ur`).
class AppLocalizationsUr extends AppLocalizations {
  AppLocalizationsUr([String locale = 'ur']) : super(locale);

  @override
  String get appName => 'میڈی ایکسپلین';

  @override
  String get retry => 'دوبارہ کوشش کریں';

  @override
  String get passwordResetInstructions =>
      'ری سیٹ کوڈ کے لیے اپنا اکاؤنٹ ای میل درج کریں۔ ای میل دیکھ کر کوڈ درج کریں۔';

  @override
  String get enterResetCode => 'ری سیٹ کوڈ درج کریں';

  @override
  String get resetPasswordTitle => 'پاس ورڈ دوبارہ مقرر کریں';

  @override
  String get resetPasswordDescription =>
      'ای میل سے کوڈ پیسٹ کریں اور نیا پاس ورڈ منتخب کریں۔ تمام موجودہ سیشن سائن آؤٹ ہو جائیں گے۔';

  @override
  String get resetCode => 'ری سیٹ کوڈ';

  @override
  String get resetCodeRequired => 'ای میل سے مکمل کوڈ پیسٹ کریں۔';

  @override
  String get newPassword => 'نیا پاس ورڈ';

  @override
  String get confirmPassword => 'پاس ورڈ کی تصدیق کریں';

  @override
  String get passwordsDoNotMatch => 'پاس ورڈ یکساں نہیں ہیں۔';

  @override
  String get passwordResetComplete =>
      'پاس ورڈ تبدیل ہو گیا۔ نئے پاس ورڈ سے سائن اِن کریں۔';

  @override
  String get passwordResetFailed =>
      'پاس ورڈ تبدیل نہیں ہو سکا۔ کنکشن اور کوڈ دیکھیں، یا کوڈ کی میعاد ختم ہونے پر نیا کوڈ منگوائیں۔';

  @override
  String get loadingSessions => 'فعال سیشن لوڈ ہو رہے ہیں';

  @override
  String get sessionsDescription =>
      'اپنے فعال سائن اِن دیکھیں۔ کسی آلے کو سائن آؤٹ کرنے کے لیے اس کا سیشن منسوخ کریں۔ انٹرنیٹ ضروری ہے۔';

  @override
  String get sessionsLoadFailed =>
      'سیشن لوڈ نہیں ہو سکے۔ اپنا کنکشن دیکھ کر دوبارہ کوشش کریں۔';

  @override
  String get currentSession => 'یہ آلہ';

  @override
  String get otherSession => 'دوسرا سائن اِن';

  @override
  String sessionCreated(String date) {
    return 'سائن اِن: $date';
  }

  @override
  String sessionExpires(String date) {
    return 'میعاد ختم: $date';
  }

  @override
  String get revokeSession => 'سیشن منسوخ کریں';

  @override
  String get revokeSessionConfirmation =>
      'اس سائن اِن کی اکاؤنٹ تک رسائی ختم ہو جائے گی۔ یہ آلہ منسوخ کرنے پر آپ یہاں بھی سائن آؤٹ ہو جائیں گے۔';

  @override
  String get sessionRevokeFailed =>
      'سیشن منسوخ نہیں ہو سکا۔ کنکشن دیکھ کر دوبارہ کوشش کریں۔';

  @override
  String get cancel => 'منسوخ کریں';

  @override
  String get continueLabel => 'جاری رکھیں';

  @override
  String get back => 'واپس';

  @override
  String get done => 'مکمل';

  @override
  String get notAvailableYet => 'آئندہ ماڈیول میں دستیاب ہوگا';

  @override
  String get startupTitle => 'میڈی ایکسپلین تیار ہو رہا ہے';

  @override
  String get startupMessage =>
      'آپ کے محفوظ اور آف لائن تجربے کی تیاری جاری ہے۔';

  @override
  String get startupErrorTitle => 'میڈی ایکسپلین شروع نہیں ہو سکا';

  @override
  String get startupErrorMessage =>
      'آپ کا ڈیٹا تبدیل نہیں ہوا۔ ڈیوائس اسٹوریج چیک کر کے دوبارہ کوشش کریں۔';

  @override
  String get offline => 'آف لائن';

  @override
  String get reconnecting => 'دوبارہ رابطہ ہو رہا ہے';

  @override
  String get synchronizing => 'ہم وقت ہو رہا ہے';

  @override
  String get home => 'ہوم';

  @override
  String get scan => 'اسکین';

  @override
  String get learn => 'سیکھیں';

  @override
  String get saved => 'محفوظ شدہ';

  @override
  String get profile => 'پروفائل';

  @override
  String get welcomeTitle => 'طبی زبان، اب زیادہ واضح';

  @override
  String get welcomeBody =>
      'طبی اصطلاحات اور نسخے کی معلومات پڑھتے وقت اعتماد حاصل کریں۔';

  @override
  String get understandTitle => 'سمجھیں';

  @override
  String get understandBody =>
      'طبی اصطلاحات کی سادہ اور ماخذ کے ساتھ وضاحت حاصل کریں۔';

  @override
  String get prescriptionTitle => 'نسخہ مددگار';

  @override
  String get prescriptionBody =>
      'بعد میں نسخے کا متن اسکین کریں اور استعمال سے پہلے ہر اہم تفصیل کی تصدیق کریں۔';

  @override
  String get learnTitle => 'سیکھیں';

  @override
  String get learnBody => 'اپنے مقصد کے مطابق طبی اصطلاحات کا مطالعہ کریں۔';

  @override
  String get privacyTitle => 'رازداری اولین ترجیح';

  @override
  String get privacyBody =>
      'ہم کم سے کم ڈیٹا جمع کرتے ہیں۔ حساس اسناد محفوظ ڈیوائس اسٹوریج میں رہتی ہیں اور نسخے کی تصاویر خودکار طور پر اپ لوڈ نہیں ہوتیں۔';

  @override
  String get safetyTitle => 'تعلیم، طبی مشورہ نہیں';

  @override
  String get safetyBody =>
      'میڈی ایکسپلین تشخیص، دوا تجویز یا خوراک تبدیل نہیں کرتا اور ڈاکٹر یا فارماسسٹ کا متبادل نہیں۔ غیر واضح اسکین شدہ معلومات کی تصدیق ضروری ہے۔';

  @override
  String get languageTitle => 'اپنی زبان منتخب کریں';

  @override
  String get english => 'انگریزی';

  @override
  String get urdu => 'اردو';

  @override
  String get accessibilityTitle => 'اپنی سہولت کے مطابق بنائیں';

  @override
  String get largerText => 'بڑا متن';

  @override
  String get largerControls => 'بڑے کنٹرولز';

  @override
  String get reduceMotion => 'حرکت کم کریں';

  @override
  String get highReadability => 'زیادہ واضح مطالعہ';

  @override
  String get usageModeTitle => 'آپ میڈی ایکسپلین کیسے استعمال کریں گے؟';

  @override
  String get patientMode => 'مریض';

  @override
  String get patientModeBody => 'واضح، عملی زبان اور آسان مطالعہ۔';

  @override
  String get studentMode => 'طالب علم';

  @override
  String get studentModeBody => 'تکنیکی اصطلاحات اور سیکھنے کی تفصیل۔';

  @override
  String get guestMode => 'مہمان';

  @override
  String get guestModeBody => 'اکاؤنٹ کے بغیر غیر حساس خصوصیات استعمال کریں۔';

  @override
  String get consentTitle => 'ایک آخری تصدیق';

  @override
  String get consentBody =>
      'میں سمجھتا/سمجھتی ہوں کہ میڈی ایکسپلین تعلیمی معلومات دیتا ہے اور پیشہ ورانہ طبی مشورے کا متبادل نہیں۔';

  @override
  String get consentRequired =>
      'جاری رکھنے کے لیے طبی حفاظت کے نوٹس کو تسلیم کریں۔';

  @override
  String get getStarted => 'شروع کریں';

  @override
  String get homeGreeting => 'طبی زبان سمجھنے کا واضح راستہ';

  @override
  String get homeSubtitle => 'آج آپ کیا سمجھنا چاہیں گے؟';

  @override
  String get scanPrescription => 'نسخہ اسکین کریں';

  @override
  String get scanPrescriptionBody => 'نسخے کی معلومات حاصل اور تصدیق کریں';

  @override
  String get scanMedicalTerm => 'طبی اصطلاح اسکین کریں';

  @override
  String get scanMedicalTermBody => 'متن سے اصطلاح پہچانیں';

  @override
  String get searchMedicalTerm => 'طبی اصطلاح تلاش کریں';

  @override
  String get searchMedicalTermBody => 'سمجھنے کے لیے اصطلاح لکھیں';

  @override
  String get learnMedicalTerms => 'طبی اصطلاحات سیکھیں';

  @override
  String get learnMedicalTermsBody => 'مرحلہ وار علم بڑھائیں';

  @override
  String get yourSpace => 'آپ کی جگہ';

  @override
  String get continueLearning => 'سیکھنا جاری رکھیں';

  @override
  String get recentActivity => 'حالیہ سرگرمی';

  @override
  String get savedContent => 'محفوظ مواد';

  @override
  String get medicationReminders => 'ادویات کی یاد دہانیاں';

  @override
  String get nothingHereYet => 'ابھی یہاں کچھ نہیں';

  @override
  String get futureContentBody =>
      'یہ حصہ میڈی ایکسپلین کے آئندہ ماڈیول کے لیے تیار ہے۔';

  @override
  String get medicalDisclaimerShort =>
      'صرف تعلیمی معلومات — تشخیص یا نسخہ نہیں۔';

  @override
  String get signIn => 'سائن ان';

  @override
  String get createAccount => 'اکاؤنٹ بنائیں';

  @override
  String get continueAsGuest => 'بطور مہمان جاری رکھیں';

  @override
  String get email => 'ای میل';

  @override
  String get password => 'پاس ورڈ';

  @override
  String get displayName => 'نام';

  @override
  String get forgotPassword => 'پاس ورڈ بھول گئے؟';

  @override
  String get emailRequired => 'اپنا ای میل پتہ درج کریں۔';

  @override
  String get emailInvalid => 'درست ای میل پتہ درج کریں۔';

  @override
  String get passwordRequired => 'اپنا پاس ورڈ درج کریں۔';

  @override
  String get passwordRequirements =>
      'کم از کم 12 حروف، بڑے اور چھوٹے حروف، ایک عدد اور ایک علامت استعمال کریں۔';

  @override
  String get nameRequired => 'اپنا نام درج کریں۔';

  @override
  String get authenticationFailed =>
      'درخواست مکمل نہ ہو سکی۔ اپنی معلومات اور کنکشن چیک کریں۔';

  @override
  String get settings => 'ترتیبات';

  @override
  String get appearance => 'ظاہری شکل';

  @override
  String get theme => 'تھیم';

  @override
  String get systemTheme => 'سسٹم';

  @override
  String get lightTheme => 'روشن';

  @override
  String get darkTheme => 'تاریک';

  @override
  String get textSize => 'متن کا سائز';

  @override
  String get language => 'زبان';

  @override
  String get accessibility => 'رسائی';

  @override
  String get hapticFeedback => 'لمسی ردعمل';

  @override
  String get textToSpeech => 'متن سے آواز';

  @override
  String get medicalExplanation => 'طبی وضاحت';

  @override
  String get userMode => 'صارف موڈ';

  @override
  String get explanationLevel => 'وضاحت کی سطح';

  @override
  String get simple => 'سادہ';

  @override
  String get standard => 'معیاری';

  @override
  String get technical => 'تکنیکی';

  @override
  String get notifications => 'اطلاعات';

  @override
  String get notificationsMaster => 'اطلاعات کی اجازت';

  @override
  String get remindersPlaceholder => 'ادویات کی یاد دہانیاں';

  @override
  String get remindersNotConfigured => 'ماڈیول 5 میں دستیاب';

  @override
  String get privacy => 'رازداری';

  @override
  String get localData => 'مقامی ڈیٹا';

  @override
  String get manageSavedData => 'محفوظ ڈیٹا سنبھالیں';

  @override
  String get syncPreference => 'اکاؤنٹ ڈیٹا ہم وقت کریں';

  @override
  String get analyticsPreference => 'گمنام ایپ تجزیات شیئر کریں';

  @override
  String get deleteAccount => 'اکاؤنٹ حذف کریں';

  @override
  String get security => 'سیکیورٹی';

  @override
  String get manageSessions => 'سیشن سنبھالیں';

  @override
  String get biometricLock => 'بایومیٹرک ایپ لاک';

  @override
  String get about => 'متعلق';

  @override
  String get appVersion => 'ایپ ورژن';

  @override
  String get privacyPolicy => 'رازداری پالیسی';

  @override
  String get terms => 'شرائط';

  @override
  String get dataSources => 'ڈیٹا ذرائع';

  @override
  String get openSourceLicenses => 'اوپن سورس لائسنس';

  @override
  String get medicalDisclaimer => 'طبی معلومات کی وضاحت';

  @override
  String get signOut => 'سائن آؤٹ';

  @override
  String get resetOnboarding => 'ابتدائی تعارف دوبارہ دیکھیں';

  @override
  String get account => 'اکاؤنٹ';

  @override
  String get signedOut => 'آپ میڈی ایکسپلین بطور مہمان استعمال کر رہے ہیں۔';

  @override
  String get signedIn => 'اس ڈیوائس پر آپ کے اکاؤنٹ کا سیشن فعال ہے۔';

  @override
  String get confirmSignOut => 'اس ڈیوائس سے سائن آؤٹ کریں؟';

  @override
  String get confirmDeleteLocalData =>
      'اس پروفائل کے نسخے، تصاویر، ادویات، خوراک کی تاریخ، محفوظ مواد اور سیکھنے کی پیش رفت اس آلے سے حذف کر کے ایپ کی ترجیحات ری سیٹ کریں؟ یہ عمل واپس نہیں ہو سکتا۔ آپ کا اکاؤنٹ، موجودہ کلاؤڈ بیک اپ، حوالہ جاتی اسباق اور دوسرے پروفائل محفوظ رہیں گے۔ غیر بھیجے گئے اپ لوڈ ختم ہوں گے؛ کلاؤڈ سے حذف کرنے کی موجودہ درخواستیں دوبارہ کوشش کے لیے محفوظ رہیں گی۔';

  @override
  String get deleteLocalData => 'مقامی ڈیٹا حذف کریں';

  @override
  String get dataDeleted => 'مقامی ڈیٹا حذف کر دیا گیا۔';

  @override
  String get accountDeletionInfo =>
      'اکاؤنٹ حذف کرنے کے لیے تصدیق شدہ کنکشن ضروری ہے اور تمام سیشن منسوخ ہوں گے۔';

  @override
  String signedInAs(String email) {
    return '$email کے طور پر سائن ان';
  }

  @override
  String get unknownPageTitle => 'صفحہ نہیں ملا';

  @override
  String get unknownPageBody => 'یہ صفحہ موجود نہیں یا اب دستیاب نہیں۔';

  @override
  String get goHome => 'ہوم جائیں';

  @override
  String get source => 'ماخذ';

  @override
  String get confidence => 'اعتماد';

  @override
  String get verificationRequired => 'تصدیق ضروری';

  @override
  String get developmentEmailNotice =>
      'پاس ورڈ ری سیٹ ای میل کی پروڈکشن ترسیل ترتیب نہیں دی گئی۔';

  @override
  String get requestReset => 'ری سیٹ کی درخواست';

  @override
  String get resetRequestSent =>
      'اگر اکاؤنٹ موجود ہے تو ترتیب شدہ ترسیلی سروس ہدایات بھیجے گی۔';

  @override
  String get terminologySearch => 'طبی اصطلاحات';

  @override
  String get searchHint => 'اصطلاح، عام فقرہ یا مخفف تلاش کریں';

  @override
  String get searchStartTitle => 'آپ کیا سمجھنا چاہتے ہیں؟';

  @override
  String get searchStartBody => 'طبی اصطلاح، عام فقرہ یا مخفف درج کریں۔';

  @override
  String get recentSearches => 'حالیہ تلاشیں';

  @override
  String get clearAll => 'سب صاف کریں';

  @override
  String get noSearchResults => 'کوئی مماثل اصطلاح نہیں ملی';

  @override
  String get noSearchResultsBody =>
      'ہجے چیک کریں یا مختصر فقرہ آزمائیں۔ میڈی ایکسپلین طبی مطلب کا اندازہ نہیں لگاتا۔';

  @override
  String didYouMean(String term) {
    return 'کیا آپ کا مطلب $term تھا؟';
  }

  @override
  String get multipleMeanings => 'متعدد طبی معنی ملے';

  @override
  String get multipleMeaningsBody =>
      'یہ مخفف سیاق پر منحصر ہے۔ صرف واضح سیاق میں معنی منتخب کریں۔';

  @override
  String matchedAs(String type) {
    return '$type کے طور پر مماثل';
  }

  @override
  String get simpleMeaning => 'سادہ مطلب';

  @override
  String get standardMeaning => 'معیاری وضاحت';

  @override
  String get technicalDefinition => 'تکنیکی تعریف';

  @override
  String get wordBreakdown => 'لفظ کی ساخت';

  @override
  String get commonLanguage => 'عام زبان کا متبادل';

  @override
  String get synonyms => 'ہم معنی';

  @override
  String get relatedTerms => 'متعلقہ اصطلاحات';

  @override
  String get examples => 'مثالیں';

  @override
  String get sourceInformation => 'ماخذ کی معلومات';

  @override
  String get developmentContentNotice =>
      'نظرثانی شدہ ترقیاتی مواد — ابھی منظور شدہ پیداواری مجموعہ نہیں';

  @override
  String get save => 'محفوظ کریں';

  @override
  String get unsave => 'محفوظ شدہ سے ہٹائیں';

  @override
  String get speak => 'تلفظ سنیں';

  @override
  String get stopSpeaking => 'تلفظ روکیں';

  @override
  String get reportContent => 'مواد کا مسئلہ رپورٹ کریں';

  @override
  String get wordDecoder => 'طبی لفظ کا تجزیہ';

  @override
  String get decoderHint => 'طبی لفظ درج کریں';

  @override
  String get decode => 'لفظ توڑیں';

  @override
  String get partialBreakdown => 'لفظ کا جزوی تجزیہ دستیاب ہے';

  @override
  String get noBreakdown => 'قابل اعتماد تجزیہ نہیں ملا';

  @override
  String get noBreakdownBody =>
      'نامعلوم حصے حل نہیں کیے جاتے۔ میڈی ایکسپلین لفظ کو زبردستی مانوس حصوں میں نہیں بانٹتا۔';

  @override
  String unknownFragment(String fragment) {
    return 'نامعلوم حصہ: $fragment';
  }

  @override
  String get abbreviationExplorer => 'مخففات کی تلاش';

  @override
  String get abbreviationSafety =>
      'طبی مخففات کے ایک سے زیادہ معنی ہو سکتے ہیں۔ ہمیشہ سیاق دیکھیں۔';

  @override
  String get prefixes => 'سابقے';

  @override
  String get roots => 'بنیادی اجزاء';

  @override
  String get suffixes => 'لاحقے';

  @override
  String get categories => 'زمرے';

  @override
  String get browseWordParts => 'لفظی اجزاء دیکھیں';

  @override
  String get origin => 'اصل';

  @override
  String get savedTerminology => 'محفوظ اصطلاحات';

  @override
  String get sortAlphabetically => 'حروف تہجی';

  @override
  String get sortRecentlySaved => 'حال ہی میں محفوظ';

  @override
  String get searchSaved => 'محفوظ اشیاء تلاش کریں';

  @override
  String get learningHome => 'طبی زبان سیکھیں';

  @override
  String get todayTerm => 'آج کی اصطلاح';

  @override
  String get lessons => 'اسباق';

  @override
  String get flashcards => 'فلیش کارڈز';

  @override
  String get quizzes => 'کوئز';

  @override
  String get progress => 'پیش رفت';

  @override
  String get currentStreak => 'موجودہ تسلسل';

  @override
  String dayCount(int count) {
    return '$count دن';
  }

  @override
  String dueReviewCount(int count) {
    return '$count جائزے باقی';
  }

  @override
  String get lessonList => 'تعلیمی اسباق';

  @override
  String minutes(int count) {
    return '$count منٹ';
  }

  @override
  String get learningObjectives => 'سیکھنے کے مقاصد';

  @override
  String get resumeLesson => 'سبق جاری رکھیں';

  @override
  String get startLesson => 'سبق شروع کریں';

  @override
  String get nextSection => 'اگلا حصہ';

  @override
  String get completeLesson => 'سبق مکمل کریں';

  @override
  String get lessonCompleted => 'سبق مکمل ہوا';

  @override
  String get revealAnswer => 'جواب دکھائیں';

  @override
  String get knewIt => 'معلوم تھا';

  @override
  String get unsure => 'یقین نہیں';

  @override
  String get didNotKnow => 'معلوم نہیں تھا';

  @override
  String get easy => 'آسان';

  @override
  String get flashcardComplete => 'جائزہ مکمل ہوا';

  @override
  String get quizSetup => 'کوئز ترتیب';

  @override
  String get questionCount => 'سوالات کی تعداد';

  @override
  String get difficulty => 'مشکل کی سطح';

  @override
  String get beginner => 'ابتدائی';

  @override
  String get intermediate => 'درمیانی';

  @override
  String get advanced => 'اعلیٰ';

  @override
  String get startQuiz => 'کوئز شروع کریں';

  @override
  String get submitAnswer => 'جواب جمع کریں';

  @override
  String get nextQuestion => 'اگلا سوال';

  @override
  String get quizResults => 'کوئز کے نتائج';

  @override
  String score(int correct, int total) {
    return 'اسکور: $correct از $total';
  }

  @override
  String get reviewMistakes => 'غلطیوں کا جائزہ';

  @override
  String get retryWeakAreas => 'کمزور حصے دوبارہ آزمائیں';

  @override
  String get yourAnswer => 'آپ کا جواب';

  @override
  String get correctAnswer => 'درست جواب';

  @override
  String get termsLearned => 'سیکھی گئی اصطلاحات';

  @override
  String get lessonsCompleted => 'مکمل اسباق';

  @override
  String get flashcardsReviewed => 'جائزہ شدہ فلیش کارڈز';

  @override
  String get quizAccuracy => 'کوئز درستگی';

  @override
  String get dueReviews => 'باقی جائزے';

  @override
  String get longestStreak => 'طویل ترین تسلسل';

  @override
  String get termOfTheDay => 'آج کی طبی اصطلاح';

  @override
  String get reportReason => 'کیا مسئلہ محسوس ہوا؟';

  @override
  String get incorrectDefinition => 'غلط تعریف';

  @override
  String get confusingExplanation => 'غیر واضح وضاحت';

  @override
  String get pronunciationIssue => 'تلفظ کا مسئلہ';

  @override
  String get translationIssue => 'ترجمے کا مسئلہ';

  @override
  String get incorrectRelatedTerm => 'غلط متعلقہ اصطلاح';

  @override
  String get other => 'دیگر';

  @override
  String get optionalNote => 'اختیاری نوٹ';

  @override
  String get submitReport => 'رپورٹ جمع کریں';

  @override
  String get reportQueued => 'رپورٹ محفوظ ہو کر جائزے کے لیے قطار میں ہے۔';

  @override
  String get offlineAvailable => 'مقامی اصطلاحاتی ڈیٹا سے آف لائن دستیاب';

  @override
  String get answerRequired => 'جاری رکھنے کے لیے جواب منتخب کریں۔';

  @override
  String get searchAbbreviations => 'مخففات تلاش کریں';

  @override
  String get contextLabel => 'سیاق';

  @override
  String get alternativeMeanings => 'دیگر ممکنہ معنی';

  @override
  String get allCategories => 'تمام زمرے';

  @override
  String get noSavedItems => 'ابھی کوئی محفوظ اصطلاح نہیں';

  @override
  String get noSavedItemsBody =>
      'اصطلاحات اور لفظی اجزاء کو یہاں آف لائن رکھنے کے لیے محفوظ کریں۔';

  @override
  String get remove => 'ہٹائیں';

  @override
  String get previous => 'پچھلا';

  @override
  String sessionProgress(int current, int total) {
    return '$total میں سے $current';
  }

  @override
  String get learningRecommendation => 'سیکھنے کی تجویز';

  @override
  String get continueUnfinishedLesson =>
      'نامکمل سبق جاری رکھیں، پھر باقی فلیش کارڈز دہرائیں۔';

  @override
  String get noLessons => 'ان فلٹرز کے مطابق کوئی سبق نہیں۔';

  @override
  String get lessonSection => 'سبق کا حصہ';

  @override
  String lessonProgressLabel(int percent) {
    return '$percent% مکمل';
  }

  @override
  String get noFlashcardsDue => 'کوئی فلیش کارڈ باقی نہیں';

  @override
  String get noFlashcardsDueBody => 'فی الحال آپ کا جائزہ شیڈول مکمل ہے۔';

  @override
  String get again => 'دوبارہ';

  @override
  String get hard => 'مشکل';

  @override
  String get good => 'اچھا';

  @override
  String get quizComplete => 'کوئز مکمل کریں';

  @override
  String get answerExplanation => 'جواب کی وضاحت';

  @override
  String get noMistakes => 'جائزے کے لیے کوئی غلطی نہیں۔';

  @override
  String accuracyPercent(int percent) {
    return '$percent%';
  }

  @override
  String get contentType => 'مواد کی قسم';

  @override
  String get reportPrivacy =>
      'رپورٹس ادارتی جائزے کے لیے محفوظ ہوتی ہیں اور طبی مواد خودکار طور پر تبدیل نہیں کرتیں۔';

  @override
  String get categoryTerms => 'اس زمرے کی اصطلاحات';

  @override
  String get openTerm => 'اصطلاح کھولیں';

  @override
  String get reviewedContent => 'نظرثانی شدہ مواد';

  @override
  String get unknownValue => 'نامعلوم';

  @override
  String get noAbbreviations => 'کوئی مماثل مخفف نہیں ملا۔';

  @override
  String get decoderDefinitionNote =>
      'لفظی اجزاء ساخت سمجھاتے ہیں۔ نیچے طبی مطلب نظرثانی شدہ اصطلاحی ریکارڈ سے ہے۔';

  @override
  String get dailyTermUnavailable => 'آج کی اصطلاح دستیاب نہیں۔';

  @override
  String get strongestCategory => 'مضبوط ترین زمرہ';

  @override
  String get needsReviewCategory => 'جائزے کا محتاج زمرہ';

  @override
  String get commonTerms => 'عام اصطلاحات';

  @override
  String get authEmailExists =>
      'اس ای میل سے اکاؤنٹ پہلے سے موجود ہے۔ سائن ان کریں یا پاس ورڈ تبدیل کریں۔';

  @override
  String get authInvalidCredentials => 'ای میل یا پاس ورڈ درست نہیں ہے۔';

  @override
  String get authConnectionFailed =>
      'سرور سے رابطہ نہیں ہو سکا۔ کنکشن چیک کر کے دوبارہ کوشش کریں۔';

  @override
  String get authRateLimited =>
      'بہت زیادہ کوششیں ہوئیں۔ ایک منٹ بعد دوبارہ کوشش کریں۔';

  @override
  String get confirmDeleteAccount =>
      'اپنا سائن ان اکاؤنٹ اور سرور کے متعلقہ ریکارڈ مستقل حذف کریں، تمام سیشن ختم کریں اور اس پروفائل کا مقامی ڈیٹا، نسخوں کی تصاویر اور یاد دہانیاں ہٹا دیں؟ یہ عمل واپس نہیں ہو سکتا اور سرور سے رابطہ ضروری ہے۔ اس آلے کے دوسرے پروفائل حذف نہیں ہوں گے۔';

  @override
  String get accountDeleted =>
      'آپ کا اکاؤنٹ اور اس پروفائل کا مقامی ڈیٹا حذف ہو گیا۔';

  @override
  String get dataDeletionFailed =>
      'حذف کرنے کا عمل مکمل نہیں ہو سکا۔ کنکشن یا آلے کی اسٹوریج چیک کر کے دوبارہ کوشش کریں۔ تکمیل کی تصدیق نہیں ہوئی۔';

  @override
  String get privacyPolicyBody =>
      'اس آلے پر آپ کا ڈیٹا\nMediExplain نسخے، نجی تصاویر، ادویات کے منصوبے، خوراک کی تاریخ، محفوظ مواد اور تعلیمی پیش رفت مقامی اسٹوریج میں رکھتی ہے۔ ہر سائن ان پروفائل کا الگ ڈیٹابیس ہے۔ سیشن کی اسناد آلے کی محفوظ اسٹوریج میں رکھی جاتی ہیں۔\n\nسرور اور AI پروسیسنگ\nسائن ان کی معلومات مقررہ سرور کو بھیجی جاتی ہیں۔ ہم وقت سازی فعال ہونے پر متعلقہ ریکارڈ اپ لوڈ ہوتے ہیں۔ بیک اپ بند ہونے کے باوجود ادویات حذف کرنے کی زیر التوا درخواستیں بھیجی جا سکتی ہیں۔ شناخت کے لیے نسخے کی تصویر منتخب کرنے پر تصویر سرور اور Google Gemini یا Groq کو جاتی ہے۔ ادویات کی وضاحت اور معاون کے سوالات Gemini، Groq یا متبادل طور پر بیک اینڈ والے کمپیوٹر کے Ollama سے پراسیس ہو سکتے ہیں۔ متنی Ollama ماڈل کو تصاویر نہیں بھیجی جاتیں۔ غیر ضروری شناختی معلومات شامل نہ کریں۔ فراہم کنندہ کی اپنی پالیسیاں لاگو ہوتی ہیں۔\n\nآپ کے اختیارات\nمحفوظ ڈیٹا کا انتظام اس پروفائل کا مقامی ریکارڈ، تصاویر اور یاد دہانیاں ہٹا کر ترجیحات ری سیٹ کرتا ہے؛ اکاؤنٹ اور موجودہ کلاؤڈ بیک اپ حذف نہیں ہوتے۔ کلاؤڈ سے حذف کرنے کی موجودہ درخواستیں محفوظ رہتی ہیں۔ اکاؤنٹ حذف کرنے کے لیے سرور سے تصدیق شدہ رابطہ ضروری ہے؛ تصدیق کے بعد مقامی پروفائل بھی صاف ہوتا ہے۔ دوسرے آلات کی مقامی نقول الگ صاف کرنا ضروری ہو سکتا ہے۔ انفرادی دوا یا نسخہ بھی حذف کیا جا سکتا ہے۔ اطلاعات بند کرنے سے یاد دہانیاں منسوخ ہوتی ہیں، خوراک کی تاریخ حذف نہیں ہوتی۔\n\nمدت اور حدود\nتصویر محفوظ رکھنے کی ترتیب کے مطابق تصدیق کے بعد نسخے کی تصاویر خودکار حذف ہو سکتی ہیں۔ پہلے شیئر کی گئی فائلیں یا ایپ سے باہر کی نقول واپس نہیں لی جا سکتیں۔ مقامی ترقیاتی نظام کی حفاظت مقررہ بیک اینڈ اور اس کے منتظم پر منحصر ہے۔ موجودہ نفاذ تجزیاتی ڈیٹا نہیں بھیجتا۔';

  @override
  String get termsBody =>
      'MediExplain کا استعمال\nیہ ایپ طبی الفاظ، نسخوں اور ادویات کی عام معلومات سمجھنے میں مدد کرتی ہے۔ یہ تشخیص، علاج تجویز کرنے یا ڈاکٹر اور فارماسسٹ کی جگہ لینے کے لیے نہیں ہے۔\n\nشناخت شدہ معلومات چیک کریں\nہاتھ کی لکھائی کی شناخت اور AI کی وضاحت نامکمل یا غلط ہو سکتی ہے۔ ہر دوا کا نام، طاقت، شکل، خوراک اور اوقات اصل نسخے یا لیبل سے ملائیں۔ غیر واضح بات فارماسسٹ یا تجویز کرنے والے ڈاکٹر سے پوچھیں۔ صرف ایپ کی بنیاد پر علاج تبدیل نہ کریں۔\n\nیاد دہانیاں اور دستیابی\nیاد دہانیاں آپ کی جائزہ لی گئی ہدایات کو محفوظ کرتی ہیں؛ علاج کی موزونیت طے نہیں کرتیں۔ اجازتیں، اطلاعات کی حدود، بیٹری اور رابطہ یاد دہانیوں اور کلاؤڈ فیچرز کو متاثر کر سکتے ہیں۔ وقت کی پابند ادویات کے لیے متبادل انتظام رکھیں۔ کلاؤڈ شناخت فراہم کنندہ کی دستیابی اور کوٹے پر منحصر ہے۔\n\nآپ کے ریکارڈ\nصرف وہ تصاویر اور معلومات اپ لوڈ کریں جن کے استعمال کا حق رکھتے ہیں۔ آلہ اور اکاؤنٹ محفوظ رکھیں۔ ڈیٹا حذف کرنے سے پہلے رازداری کی پالیسی اور تصدیق پڑھیں۔ یہ ہدایات موجودہ ایپ کے استعمال کی وضاحت ہیں، طبی توثیق یا قانونی منظوری کا دعویٰ نہیں۔';

  @override
  String get dataSourcesBody =>
      'ادویات کے حوالے\nدوا کی شناخت اور فعال اجزاء کے تعلقات دستیاب NLM RxNorm حوالوں سے لیے جاتے ہیں۔ مریض کی معلومات میں MedlinePlus اور DailyMed کے لیبل استعمال ہو سکتے ہیں۔ دستیابی دوا اور ملک کے لحاظ سے مختلف ہے۔ فعال جز کا حوالہ نسخے کی مخصوص دوا، خوراک یا اخراج کی قسم کی تصدیق نہیں کرتا۔\n\nتعلیمی مواد\nمقامی ترقیاتی کیٹلاگ میں 30 اسباق، 60 فلیش کارڈ، چار کوئز سوالات اور طبی اصطلاحات ہیں۔ اصل ترقیاتی خلاصوں کے ساتھ متعلقہ ماخذ موجود ہیں۔ یہ طبی طور پر منظور شدہ پیداواری کیٹلاگ نہیں ہے۔ ہر اصطلاح کی ماخذ کی معلومات میں اس کی اصل اور جائزہ کی تفصیل ہوتی ہے۔\n\nAI اور تصویر کی شناخت\nGemini منتخب نسخے کی تصویر پڑھتا اور ادویات کے خانے الگ کرتا ہے؛ حد ختم ہونے یا عارضی خرابی پر Groq استعمال ہوتا ہے۔ معاون پہلے Gemini، پھر Groq اور آخر میں متنی متبادل کے طور پر Ollama کا qwen3:1.7b استعمال کرتا ہے۔ دوسرے شناختی اوزار Apple Vision، Android ML Kit اور اختیاری سرور ماڈل استعمال کر سکتے ہیں۔ AI طبی حوالہ نہیں بلکہ پروسیسنگ کا آلہ ہے۔ وضاحت میں ماخذ کا حوالہ برقرار رہنا چاہیے۔\n\nماخذ کا جائزہ\nدوا کی وضاحت میں اس کے اصل حوالے شامل ہوتے ہیں۔ نام مبہم ہو یا معلومات نہ ملیں تو درست کریں یا فارماسسٹ سے پوچھیں؛ ایپ کو غائب معلومات نہیں گھڑنی چاہییں۔';

  @override
  String get sourceWebsite => 'حوالہ جاتی ویب سائٹ';

  @override
  String get serverConnection => 'سرور کنکشن';

  @override
  String get serverAddress => 'سرور کا پتہ';

  @override
  String get testAndSave => 'جانچیں اور محفوظ کریں';

  @override
  String get serverConnectionSaved =>
      'سرور کنکشن اپ ڈیٹ ہو گیا۔ محفوظ نسخے پر دوبارہ کوشش کریں۔';

  @override
  String get serverAddressInvalid =>
      'نجی LAN کا HTTP پتہ یا HTTPS سرور کا پتہ درج کریں جو /api/v1/ پر ختم ہو۔ صارف نام، پاس ورڈ یا کوئری شامل نہ کریں۔';

  @override
  String get serverConnectionFailed =>
      'سرور کی تصدیق یا پتہ محفوظ نہیں ہو سکا۔ میک اور فون ایک ہی وائی فائی پر رکھیں، API چلائیں اور مقامی نیٹ ورک کی اجازت دیں۔';

  @override
  String get serverConnectionHelp =>
      'خودکار کنکشن ایک ہی وائی فائی پر آپ کے میک کے موجودہ پتے سے جڑتا ہے۔ کسی دوسرے قابل اعتماد سرور کے لیے خودکار کنکشن بند کر کے پتہ درج کریں۔ جانچ میں لاگ ان یا نسخہ نہیں بھیجا جاتا۔';

  @override
  String get automaticServerConnection => 'میرا میک خودکار طور پر تلاش کریں';

  @override
  String get automaticServerConnectionHelp =>
      'دونوں آلات کا وائی فائی بدلنے پر میک کے نام سے دوبارہ جڑیں۔';

  @override
  String get learningSaveFailed =>
      'پیش رفت محفوظ نہیں ہو سکی۔ دوبارہ کوشش کریں۔';

  @override
  String get learningLoadFailed => 'یہ سبق لوڈ نہیں ہو سکا۔ دوبارہ کوشش کریں۔';

  @override
  String get speechUnavailable =>
      'اس آلے پر آواز نہیں چل سکی۔ دوبارہ کوشش کریں۔';
}
