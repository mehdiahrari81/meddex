import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mediexplain/app/router/app_routes.dart';
import 'package:mediexplain/design_system/app_theme.dart';
import 'package:mediexplain/features/learning/application/learning_providers.dart';
import 'package:mediexplain/features/learning/domain/learning_models.dart';
import 'package:mediexplain/features/learning/presentation/learn_home_screen.dart';
import 'package:mediexplain/l10n/app_localizations.dart';

LearningDashboard dashboard(int days) => LearningDashboard(
  termsLearned: 4,
  lessonsCompleted: 2,
  totalLessons: 30,
  flashcardsReviewed: 5,
  quizAccuracy: 0.8,
  dueReviews: 0,
  streak: LearningStreak(current: days, longest: days),
);

GoRouter router() => GoRouter(
  initialLocation: AppRoute.learn.path,
  routes: [
    GoRoute(
      path: AppRoute.learn.path,
      builder: (_, _) => const LearnHomeScreen(),
    ),
    GoRoute(
      path: AppRoute.progress.path,
      builder: (_, _) => const Scaffold(body: Text('Learning progress')),
    ),
  ],
);

Widget app(ProviderContainer container, GoRouter routes, {bool urdu = false}) =>
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        theme: urdu ? AppTheme.dark() : AppTheme.light(),
        locale: Locale(urdu ? 'ur' : 'en'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: routes,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(urdu ? 2 : 1)),
          child: child!,
        ),
      ),
    );

void main() {
  testWidgets('flame count updates with learning activity and opens progress', (
    tester,
  ) async {
    var days = 3;
    final container = ProviderContainer(
      overrides: [
        learningDashboardProvider.overrideWith((ref) async => dashboard(days)),
      ],
    );
    final routes = router();
    addTearDown(container.dispose);
    addTearDown(routes.dispose);
    await tester.pumpWidget(app(container, routes));
    await tester.pumpAndSettle();

    final flame = find.byIcon(Icons.local_fire_department_rounded);
    expect(
      find.descendant(of: find.byType(AppBar), matching: flame),
      findsOneWidget,
    );
    expect(find.text('3'), findsOneWidget);
    expect(find.textContaining('Current streak'), findsNothing);
    expect(find.byTooltip('Current streak: 3 days'), findsOneWidget);

    days = 4;
    container.invalidate(learningDashboardProvider);
    await tester.pumpAndSettle();
    expect(find.text('4'), findsOneWidget);
    expect(find.byTooltip('Current streak: 4 days'), findsOneWidget);
    await tester.tap(flame);
    await tester.pumpAndSettle();
    expect(find.text('Learning progress'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('unavailable streak does not pretend the user has zero days', (
    tester,
  ) async {
    final pending = Completer<LearningDashboard>();
    final container = ProviderContainer(
      overrides: [
        learningDashboardProvider.overrideWith((ref) => pending.future),
      ],
    );
    final routes = router();
    addTearDown(container.dispose);
    addTearDown(routes.dispose);
    await tester.pumpWidget(app(container, routes));
    await tester.pump();
    expect(find.text('–'), findsOneWidget);
    expect(find.text('0'), findsNothing);
    pending.completeError(StateError('Dashboard unavailable'));
    await tester.pumpAndSettle();
    expect(find.text('–'), findsOneWidget);
    expect(find.text('0'), findsNothing);
    await tester.tap(find.byIcon(Icons.local_fire_department_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Learning progress'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('streak remains accessible in Urdu at large text size', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final container = ProviderContainer(
      overrides: [
        learningDashboardProvider.overrideWith((ref) async => dashboard(12)),
      ],
    );
    final routes = router();
    addTearDown(container.dispose);
    addTearDown(routes.dispose);
    await tester.pumpWidget(app(container, routes, urdu: true));
    await tester.pumpAndSettle();
    final flame = find.byIcon(Icons.local_fire_department_rounded);
    expect(Directionality.of(tester.element(flame)), TextDirection.rtl);
    final l10n = AppLocalizations.of(tester.element(flame));
    final badge = find.byTooltip('${l10n.currentStreak}: ${l10n.dayCount(12)}');
    expect(badge, findsOneWidget);
    final button = find.descendant(
      of: badge,
      matching: find.byType(TextButton),
    );
    expect(tester.getSize(button).height, greaterThanOrEqualTo(48));
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(find.text('Learning progress'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
