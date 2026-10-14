import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/application/auth_controller.dart';
import '../../features/auth/presentation/auth_screen.dart';
import '../../features/auth/presentation/forgot_password_screen.dart';
import '../../features/auth/presentation/reset_password_screen.dart';
import '../../features/auth/presentation/sessions_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/intelligence/domain/intelligence_models.dart';
import '../../features/intelligence/presentation/medication_intelligence_screens.dart';
import '../../features/learning/presentation/flashcard_session_screen.dart';
import '../../features/learning/presentation/learn_home_screen.dart';
import '../../features/learning/presentation/lesson_screens.dart';
import '../../features/learning/presentation/progress_screen.dart';
import '../../features/learning/presentation/quiz_screens.dart';
import '../../features/learning/presentation/term_of_day_screen.dart';
import '../../features/medications/presentation/medication_screens.dart';
import '../../features/onboarding/presentation/onboarding_screen.dart';
import '../../features/placeholders/presentation/placeholder_screen.dart';
import '../../features/prescription/domain/prescription_models.dart';
import '../../features/prescription/presentation/barcode_screens.dart';
import '../../features/prescription/presentation/camera_capture_screen.dart';
import '../../features/prescription/presentation/ocr_review_screen.dart';
import '../../features/prescription/presentation/prescription_confirmation_screens.dart';
import '../../features/prescription/presentation/prescription_history_screen.dart';
import '../../features/prescription/presentation/prescription_item_edit_screen.dart';
import '../../features/prescription/presentation/prescription_preview_screen.dart';
import '../../features/prescription/presentation/prescription_processing_screen.dart';
import '../../features/prescription/presentation/prescription_review_screen.dart';
import '../../features/prescription/presentation/prescription_scan_screen.dart';
import '../../features/prescription/presentation/scan_medical_term_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/settings/application/settings_controller.dart';
import '../../features/settings/domain/app_settings.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/saved/presentation/saved_library_screen.dart';
import '../../features/shell/presentation/app_shell.dart';
import '../../features/terminology/presentation/content_report_screen.dart';
import '../../features/terminology/presentation/morphology_screens.dart';
import '../../features/terminology/presentation/term_detail_screen.dart';
import '../../features/terminology/presentation/terminology_search_screen.dart';
import '../../features/terminology/presentation/word_decoder_screen.dart';
import 'app_routes.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final settings = ref.read(settingsControllerProvider).valueOrNull;

  final router = GoRouter(
    initialLocation: settings?.lastUsefulLocation ?? AppRoute.home.path,
    redirect: (context, state) => routeRedirect(
      settings: ref.read(settingsControllerProvider).valueOrNull,
      auth: ref.read(authControllerProvider).valueOrNull,
      matchedLocation: state.matchedLocation,
      requestedUri: state.uri,
    ),
    routes: [
      GoRoute(
        path: AppRoute.onboarding.path,
        name: AppRoute.onboarding.name,
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/terms/search',
        name: AppRoute.termSearch.name,
        builder: (context, state) => TerminologySearchScreen(
          initialQuery: state.uri.queryParameters['query'],
        ),
      ),
      GoRoute(
        path: '/terms/decoder',
        name: AppRoute.wordDecoder.name,
        builder: (context, state) => const WordDecoderScreen(),
      ),
      GoRoute(
        path: '/terms/abbreviations',
        name: AppRoute.abbreviations.name,
        builder: (context, state) => const AbbreviationExplorerScreen(),
      ),
      GoRoute(
        path: '/terms/morphology/prefixes',
        name: AppRoute.prefixes.name,
        builder: (context, state) => const MorphologyLibraryScreen.prefixes(),
      ),
      GoRoute(
        path: '/terms/morphology/roots',
        name: AppRoute.roots.name,
        builder: (context, state) => const MorphologyLibraryScreen.roots(),
      ),
      GoRoute(
        path: '/terms/morphology/suffixes',
        name: AppRoute.suffixes.name,
        builder: (context, state) => const MorphologyLibraryScreen.suffixes(),
      ),
      GoRoute(
        path: '/terms/categories',
        name: AppRoute.categories.name,
        builder: (context, state) => const CategoryBrowserScreen(),
      ),
      GoRoute(
        path: '/terms/:id',
        name: AppRoute.termDetail.name,
        builder: (context, state) =>
            TermDetailScreen(termId: state.pathParameters['id']!),
        routes: [
          GoRoute(
            path: 'report',
            name: AppRoute.contentReport.name,
            builder: (context, state) =>
                ContentReportScreen(termId: state.pathParameters['id']!),
          ),
        ],
      ),
      GoRoute(
        path: AppRoute.auth.path,
        name: AppRoute.auth.name,
        builder: (context, state) =>
            AuthScreen(returnLocation: state.uri.queryParameters['from']),
        routes: [
          GoRoute(
            path: 'register',
            name: AppRoute.register.name,
            builder: (context, state) => const AuthScreen(registering: true),
          ),
          GoRoute(
            path: 'forgot-password',
            name: AppRoute.forgotPassword.name,
            builder: (context, state) => const ForgotPasswordScreen(),
          ),
          GoRoute(
            path: 'reset-password',
            name: AppRoute.resetPassword.name,
            builder: (context, state) => const ResetPasswordScreen(),
          ),
        ],
      ),
      GoRoute(
        path: AppRoute.prescriptionCamera.path,
        name: AppRoute.prescriptionCamera.name,
        builder: (context, state) => const PrescriptionCameraScreen(),
      ),
      GoRoute(
        path: AppRoute.scanMedicalTerm.path,
        name: AppRoute.scanMedicalTerm.name,
        builder: (context, state) => const ScanMedicalTermScreen(),
      ),
      GoRoute(
        path: AppRoute.barcodeScanner.path,
        name: AppRoute.barcodeScanner.name,
        builder: (context, state) => const MedicineBarcodeScannerScreen(),
      ),
      GoRoute(
        path: AppRoute.barcodeResult.path,
        name: AppRoute.barcodeResult.name,
        builder: (context, state) {
          final capture = state.extra;
          return capture is BarcodeCapture
              ? BarcodeResultScreen(capture: capture)
              : const BarcodeResultMissingScreen();
        },
      ),
      GoRoute(
        path: AppRoute.prescriptionHistory.path,
        name: AppRoute.prescriptionHistory.name,
        builder: (context, state) => const PrescriptionHistoryScreen(),
      ),
      GoRoute(
        path: AppRoute.prescriptionPreview.path,
        name: AppRoute.prescriptionPreview.name,
        builder: (context, state) => PrescriptionPreviewScreen(
          prescriptionId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: AppRoute.prescriptionProcessing.path,
        name: AppRoute.prescriptionProcessing.name,
        builder: (context, state) => PrescriptionProcessingScreen(
          prescriptionId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: AppRoute.prescriptionOcrReview.path,
        name: AppRoute.prescriptionOcrReview.name,
        builder: (context, state) =>
            OcrRawTextReviewScreen(prescriptionId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: AppRoute.prescriptionReview.path,
        name: AppRoute.prescriptionReview.name,
        builder: (context, state) => PrescriptionStructuredReviewScreen(
          prescriptionId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: AppRoute.prescriptionItemEdit.path,
        name: AppRoute.prescriptionItemEdit.name,
        builder: (context, state) => PrescriptionItemEditScreen(
          prescriptionId: state.pathParameters['id']!,
          itemId: state.pathParameters['itemId']!,
        ),
      ),
      GoRoute(
        path: AppRoute.prescriptionManual.path,
        name: AppRoute.prescriptionManual.name,
        builder: (context, state) => ManualMedicationEntryScreen(
          prescriptionId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: AppRoute.prescriptionUnresolved.path,
        name: AppRoute.prescriptionUnresolved.name,
        builder: (context, state) => UnresolvedFieldsReviewScreen(
          prescriptionId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: AppRoute.prescriptionConfirm.path,
        name: AppRoute.prescriptionConfirm.name,
        builder: (context, state) => FinalPrescriptionConfirmationScreen(
          prescriptionId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: AppRoute.prescriptionSaved.path,
        name: AppRoute.prescriptionSaved.name,
        builder: (context, state) => PrescriptionSavedSummaryScreen(
          prescriptionId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: AppRoute.prescriptionDetail.path,
        name: AppRoute.prescriptionDetail.name,
        builder: (context, state) => PrescriptionDetailScreen(
          prescriptionId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: AppRoute.medications.path,
        name: AppRoute.medications.name,
        builder: (context, state) => const MyMedicationsScreen(),
      ),
      GoRoute(
        path: AppRoute.medicineSearch.path,
        name: AppRoute.medicineSearch.name,
        builder: (context, state) => MedicationSearchScreen(
          initialQuery: state.uri.queryParameters['query'],
          initialStrength: state.uri.queryParameters['strength'],
          initialForm: state.uri.queryParameters['dosageForm'],
          autoSearch: state.uri.queryParameters['autoSearch'] == 'true',
          prescriptionItemId: state.uri.queryParameters['prescriptionItemId'],
        ),
      ),
      GoRoute(
        path: AppRoute.savedMedicines.path,
        name: AppRoute.savedMedicines.name,
        builder: (context, state) => const SavedMedicineInformationScreen(),
      ),
      GoRoute(
        path: AppRoute.recentMedicines.path,
        name: AppRoute.recentMedicines.name,
        builder: (context, state) =>
            const SavedMedicineInformationScreen(recent: true),
      ),
      GoRoute(
        path: AppRoute.medicineSources.path,
        name: AppRoute.medicineSources.name,
        builder: (context, state) {
          final source = state.extra;
          return source is MedicationSource
              ? MedicationSourceScreen(source: source)
              : const BarcodeResultMissingScreen();
        },
      ),
      GoRoute(
        path: AppRoute.medicineDetail.path,
        name: AppRoute.medicineDetail.name,
        builder: (context, state) =>
            MedicationDetailScreen(medicationId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: AppRoute.medicineAssistant.path,
        name: AppRoute.medicineAssistant.name,
        builder: (context, state) => MedicationAssistantScreen(
          medicationId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: AppRoute.medicineReport.path,
        name: AppRoute.medicineReport.name,
        builder: (context, state) => MedicationReportScreen(
          medicationId: state.pathParameters['id']!,
          initialType: state.uri.queryParameters['type'],
        ),
      ),
      GoRoute(
        path: AppRoute.medicationCreate.path,
        name: AppRoute.medicationCreate.name,
        builder: (context, state) => CreateMedicationPlanScreen(
          prescriptionId: state.uri.queryParameters['prescriptionId'],
        ),
      ),
      GoRoute(
        path: AppRoute.medicationTimeline.path,
        name: AppRoute.medicationTimeline.name,
        builder: (context, state) => const TodayMedicationTimelineScreen(),
      ),
      GoRoute(
        path: AppRoute.medicationCalendar.path,
        name: AppRoute.medicationCalendar.name,
        builder: (context, state) => const MedicationCalendarScreen(),
      ),
      GoRoute(
        path: AppRoute.adherenceSummary.path,
        name: AppRoute.adherenceSummary.name,
        builder: (context, state) => const AdherenceSummaryScreen(),
      ),
      GoRoute(
        path: AppRoute.medicationArchive.path,
        name: AppRoute.medicationArchive.name,
        builder: (context, state) => const CompletedMedicationArchiveScreen(),
      ),
      GoRoute(
        path: AppRoute.medicationVoice.path,
        name: AppRoute.medicationVoice.name,
        builder: (context, state) => const MedicationVoiceAssistantScreen(),
      ),
      GoRoute(
        path: AppRoute.medicationAccessibility.path,
        name: AppRoute.medicationAccessibility.name,
        builder: (context, state) =>
            const MedicationAccessibilitySettingsScreen(),
      ),
      GoRoute(
        path: AppRoute.notificationPrivacy.path,
        name: AppRoute.notificationPrivacy.name,
        builder: (context, state) => const NotificationPrivacyScreen(),
      ),
      GoRoute(
        path: AppRoute.medicationShare.path,
        name: AppRoute.medicationShare.name,
        builder: (context, state) => const ShareMedicationSummaryScreen(),
      ),
      GoRoute(
        path: AppRoute.medicationPrivacy.path,
        name: AppRoute.medicationPrivacy.name,
        builder: (context, state) => const MedicationPrivacyScreen(),
      ),
      GoRoute(
        path: AppRoute.medicationActivity.path,
        name: AppRoute.medicationActivity.name,
        builder: (context, state) => const MedicationActivityScreen(),
      ),
      GoRoute(
        path: AppRoute.medicationDetail.path,
        name: AppRoute.medicationDetail.name,
        builder: (context, state) =>
            MedicationPlanDetailScreen(planId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: AppRoute.medicationEdit.path,
        name: AppRoute.medicationEdit.name,
        builder: (context, state) =>
            EditReminderScreen(planId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: AppRoute.medicationHistory.path,
        name: AppRoute.medicationHistory.name,
        builder: (context, state) =>
            DoseHistoryScreen(planId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: AppRoute.medicationRefill.path,
        name: AppRoute.medicationRefill.name,
        builder: (context, state) =>
            RefillReminderScreen(planId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: AppRoute.medicationNotes.path,
        name: AppRoute.medicationNotes.name,
        builder: (context, state) =>
            MedicationNotesScreen(planId: state.pathParameters['id']!),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(navigationShell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoute.home.path,
                name: AppRoute.home.name,
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoute.scan.path,
                name: AppRoute.scan.name,
                builder: (context, state) => const PrescriptionScanScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoute.learn.path,
                name: AppRoute.learn.name,
                builder: (context, state) => const LearnHomeScreen(),
                routes: [
                  GoRoute(
                    path: 'lessons',
                    name: AppRoute.learningLessons.name,
                    builder: (context, state) => const LessonListScreen(),
                    routes: [
                      GoRoute(
                        path: ':id',
                        name: AppRoute.lessonDetail.name,
                        builder: (context, state) => LessonDetailScreen(
                          lessonId: state.pathParameters['id']!,
                        ),
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'flashcards',
                    name: AppRoute.flashcards.name,
                    builder: (context, state) => const FlashcardSessionScreen(),
                  ),
                  GoRoute(
                    path: 'quiz',
                    name: AppRoute.quizSetup.name,
                    builder: (context, state) => const QuizSetupScreen(),
                  ),
                  GoRoute(
                    path: 'progress',
                    name: AppRoute.progress.name,
                    builder: (context, state) => const ProgressScreen(),
                  ),
                  GoRoute(
                    path: 'daily-term',
                    name: AppRoute.dailyTerm.name,
                    builder: (context, state) => const TermOfDayScreen(),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoute.saved.path,
                name: AppRoute.saved.name,
                builder: (context, state) => const SavedLibraryScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoute.profile.path,
                name: AppRoute.profile.name,
                builder: (context, state) => const ProfileScreen(),
                routes: [
                  GoRoute(
                    path: 'settings',
                    name: AppRoute.settings.name,
                    builder: (context, state) => const SettingsScreen(),
                  ),
                  GoRoute(
                    path: 'sessions',
                    name: AppRoute.sessions.name,
                    builder: (context, state) => const SessionsScreen(),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) =>
        const PlaceholderScreen(destination: PlaceholderDestination.unknown),
  );
  ref.listen(settingsControllerProvider, (_, _) => router.refresh());
  ref.listen(authControllerProvider, (_, _) => router.refresh());
  ref.onDispose(router.dispose);
  return router;
});

String? routeRedirect({
  required AppSettings? settings,
  required AuthState? auth,
  required String matchedLocation,
  required Uri requestedUri,
}) {
  if (settings == null || auth == null) return null;
  final isOnboarding = matchedLocation == AppRoute.onboarding.path;
  if (!settings.onboardingComplete) {
    return isOnboarding ? null : AppRoute.onboarding.path;
  }
  if (isOnboarding) return AppRoute.home.path;
  if (ProtectedRoutes.contains(matchedLocation) &&
      auth.status != AuthStatus.authenticated) {
    return '${AppRoute.auth.path}?from=${Uri.encodeComponent(requestedUri.toString())}';
  }
  return null;
}
