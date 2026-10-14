import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mediexplain/core/voice/voice_provider.dart';
import 'package:mediexplain/core/voice/voice_service.dart';
import 'package:mediexplain/features/medications/application/medication_providers.dart';
import 'package:mediexplain/features/medications/domain/medication_models.dart';
import 'package:mediexplain/features/medications/presentation/medication_screens.dart';

void main() {
  testWidgets('voice assistant is reachable from an empty medication library', (
    tester,
  ) async {
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => const MyMedicationsScreen()),
        GoRoute(
          path: '/medications/voice',
          builder: (_, _) => const MedicationVoiceAssistantScreen(),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          medicationPlansProvider.overrideWith((_) => Stream.value([])),
          medicationPrivacyProvider.overrideWith(
            (_) async => const MedicationPrivacyPreferences.defaults(),
          ),
          voiceInputProvider.overrideWithValue(
            const UnavailableVoiceInputService(),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('No medications saved'), findsOneWidget);
    await tester.tap(find.byTooltip('Voice assistant'));
    await tester.pumpAndSettle();
    expect(find.text('Voice Assistant'), findsOneWidget);
    expect(find.text('Review command'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final command in ['Search hypertension', 'تلاش کریں hypertension']) {
    testWidgets(
      'typed command "$command" opens the actual search with its query',
      (tester) async {
        final router = GoRouter(
          routes: [
            GoRoute(
              path: '/',
              builder: (_, _) => const MedicationVoiceAssistantScreen(),
            ),
            GoRoute(
              path: '/terms/search',
              builder: (_, state) => Scaffold(
                body: Text(
                  'Search result: ${state.uri.queryParameters['query']}',
                ),
              ),
            ),
          ],
        );
        addTearDown(router.dispose);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              voiceInputProvider.overrideWithValue(
                const UnavailableVoiceInputService(),
              ),
            ],
            child: MaterialApp.router(routerConfig: router),
          ),
        );
        await tester.enterText(find.byType(TextField), command);
        await tester.tap(find.text('Review command'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Search terminology'));
        await tester.pumpAndSettle();
        expect(find.text('Search result: hypertension'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'speech failure preserves typed commands and dose changes have no action',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            voiceInputProvider.overrideWithValue(
              const UnavailableVoiceInputService(),
            ),
          ],
          child: const MaterialApp(home: MedicationVoiceAssistantScreen()),
        ),
      );
      await tester.tap(find.text('Start voice input'));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Voice input is unavailable on this device. You can type a command instead.',
        ),
        findsOneWidget,
      );
      for (final command in ['Double my dose', 'میری خوراک دوگنی کر دیں']) {
        await tester.enterText(find.byType(TextField), command);
        await tester.tap(find.text('Review command'));
        await tester.pumpAndSettle();
        expect(
          find.textContaining('I cannot recommend an extra dose'),
          findsOneWidget,
        );
        expect(find.text('Review dose on timeline'), findsNothing);
      }
      await tester.enterText(find.byType(TextField), 'Mark dose taken');
      await tester.tap(find.text('Review command'));
      await tester.pumpAndSettle();
      expect(find.text('Review dose on timeline'), findsOneWidget);
      expect(
        find.textContaining('visually confirm the exact medicine'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
