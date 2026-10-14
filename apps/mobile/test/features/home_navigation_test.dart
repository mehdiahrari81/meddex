import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mediexplain/app/router/app_routes.dart';
import 'package:mediexplain/design_system/widgets/buttons.dart';
import 'package:mediexplain/features/home/presentation/home_screen.dart';
import 'package:mediexplain/features/medications/application/medication_providers.dart';
import 'package:mediexplain/features/medications/domain/medication_models.dart';
import 'package:mediexplain/l10n/app_localizations.dart';

void main() {
  for (final fallback in ['/home', '/medications', '/prescriptions/history']) {
    testWidgets('workflow root can return to $fallback without a page stack', (
      tester,
    ) async {
      final router = GoRouter(
        initialLocation: '/workflow',
        routes: [
          GoRoute(
            path: '/workflow',
            builder: (_, _) => Scaffold(
              appBar: AppBar(
                leading: AppBackButton(fallbackLocation: fallback),
              ),
            ),
          ),
          GoRoute(
            path: fallback,
            builder: (_, _) =>
                const Scaffold(body: Text('Returned to library')),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();
      expect(router.canPop(), isFalse);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('Returned to library'), findsOneWidget);
    });
  }

  final destinations = {
    'Search medicine information': AppRoute.medicineSearch.path,
    "Today's reminders": AppRoute.medicationTimeline.path,
    'Scan medical term': AppRoute.scanMedicalTerm.path,
    'Search medical term': AppRoute.termSearch.path,
    'Recent activity': AppRoute.recentMedicines.path,
    'Medication reminders': AppRoute.medications.path,
  };

  for (final destination in destinations.entries) {
    testWidgets('${destination.key} preserves a route back to Home', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final router = GoRouter(
        initialLocation: AppRoute.home.path,
        routes: [
          GoRoute(
            path: AppRoute.home.path,
            builder: (_, _) => const HomeScreen(),
          ),
          GoRoute(
            path: destination.value,
            builder: (_, _) => Scaffold(
              appBar: AppBar(title: Text(destination.key)),
              body: const Text('Destination opened'),
            ),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            medicationPlansProvider.overrideWith((_) => Stream.value(const [])),
            medicationPrivacyProvider.overrideWith(
              (_) async => const MedicationPrivacyPreferences.defaults(),
            ),
            medicationTimezoneReviewProvider.overrideWith((_) async => false),
          ],
          child: MaterialApp.router(
            routerConfig: router,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final card = find.text(destination.key);
      await tester.ensureVisible(card);
      await tester.tap(card);
      await tester.pumpAndSettle();
      expect(find.text('Destination opened'), findsOneWidget);
      expect(find.byType(BackButton), findsOneWidget);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
