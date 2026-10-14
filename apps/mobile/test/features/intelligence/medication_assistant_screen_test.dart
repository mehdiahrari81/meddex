import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:mediexplain/core/errors/app_error.dart';
import 'package:mediexplain/core/tts/tts_provider.dart';
import 'package:mediexplain/core/tts/tts_service.dart';
import 'package:mediexplain/core/voice/voice_provider.dart';
import 'package:mediexplain/core/voice/voice_service.dart';
import 'package:mediexplain/domain/models/user.dart';
import 'package:mediexplain/features/intelligence/application/intelligence_providers.dart';
import 'package:mediexplain/features/intelligence/domain/intelligence_models.dart';
import 'package:mediexplain/features/intelligence/domain/medication_intelligence_repository.dart';
import 'package:mediexplain/features/intelligence/presentation/medication_intelligence_screens.dart';
import 'package:mediexplain/features/settings/application/settings_controller.dart';
import 'package:mediexplain/features/settings/domain/app_settings.dart';

class _Repository extends Mock implements MedicationIntelligenceRepository {}

class _Settings extends SettingsController {
  _Settings(this.settings);
  final AppSettings settings;
  @override
  Future<AppSettings> build() async => settings;
}

GroundedAnswer _answer(String text, {bool generated = true}) => GroundedAnswer(
  answer: text,
  answerType: generated ? 'source_explanation' : 'source_extract',
  groundingStatus: 'grounded',
  sources: const [],
  safetyClassification: 'safe_general_information',
  limitations: const ['General information only.'],
  suggestions: const [],
  language: 'en',
  aiProviderUsed: generated,
);

Future<void> _mount(
  WidgetTester tester,
  _Repository repository, {
  AppSettings settings = const AppSettings.defaults(),
}) async {
  final container = ProviderContainer(
    overrides: [
      medicationIntelligenceRepositoryProvider.overrideWithValue(repository),
      settingsControllerProvider.overrideWith(() => _Settings(settings)),
      textToSpeechProvider.overrideWithValue(
        const UnavailableTextToSpeechService(),
      ),
      voiceInputProvider.overrideWithValue(
        const UnavailableVoiceInputService(),
      ),
    ],
  );
  addTearDown(container.dispose);
  await container.read(settingsControllerProvider.future);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        home: MedicationAssistantScreen(medicationId: 'source-medication'),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _send(WidgetTester tester, String question) async {
  await tester.enterText(find.byType(TextField), question);
  await tester.tap(find.byTooltip('Send question'));
  await tester.pump();
}

void main() {
  testWidgets(
    'cancelled replies cannot overwrite a newer question or stop its spinner',
    (tester) async {
      final repository = _Repository();
      final first = Completer<GroundedAnswer>();
      final second = Completer<GroundedAnswer>();
      final requests = [first, second];
      when(
        () => repository.ask(
          question: any(named: 'question'),
          medicationId: any(named: 'medicationId'),
          mode: any(named: 'mode'),
          language: any(named: 'language'),
        ),
      ).thenAnswer((_) => requests.removeAt(0).future);
      await _mount(tester, repository);
      await _send(tester, 'First question');
      await tester.tap(find.byTooltip('Stop waiting'));
      await tester.pump();
      verify(() => repository.cancelActiveAnswer()).called(1);
      await _send(tester, 'Second question');
      first.complete(_answer('Stale reply must never appear'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Stale reply must never appear'), findsNothing);
      expect(find.byTooltip('Stop waiting'), findsOneWidget);
      second.complete(_answer('Reply for the second question'));
      await tester.pumpAndSettle();
      expect(find.text('Reply for the second question'), findsOneWidget);
      expect(find.text('AI explanation'), findsOneWidget);
      expect(find.byTooltip('Send question'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'network error has a retry that can return a labeled source extract',
    (tester) async {
      final repository = _Repository();
      var calls = 0;
      when(
        () => repository.ask(
          question: any(named: 'question'),
          medicationId: any(named: 'medicationId'),
          mode: any(named: 'mode'),
          language: any(named: 'language'),
        ),
      ).thenAnswer((_) async {
        if (++calls == 1) throw const NetworkUnavailableError();
        return _answer('Original source passage', generated: false);
      });
      await _mount(tester, repository);
      await _send(tester, 'Explain the warnings');
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Could not connect. Check your connection and retry this question.',
        ),
        findsOneWidget,
      );
      await tester.tap(find.byTooltip('Retry from trusted sources'));
      await tester.pumpAndSettle();
      expect(find.text('Original source'), findsOneWidget);
      expect(find.text('Original source passage'), findsOneWidget);
      expect(find.text('AI explanation'), findsNothing);
      expect(calls, 2);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('student mode and Urdu are passed through to the assistant', (
    tester,
  ) async {
    final repository = _Repository();
    when(
      () => repository.ask(
        question: any(named: 'question'),
        medicationId: 'source-medication',
        mode: 'student',
        language: 'ur',
      ),
    ).thenAnswer((_) async => _answer('معتبر ماخذ کی وضاحت'));
    await _mount(
      tester,
      repository,
      settings: const AppSettings.defaults().copyWith(
        userMode: UserMode.student,
        languageCode: 'ur',
      ),
    );
    await _send(tester, 'احتیاط کی وضاحت کریں');
    await tester.pumpAndSettle();
    verify(
      () => repository.ask(
        question: 'احتیاط کی وضاحت کریں',
        medicationId: 'source-medication',
        mode: 'student',
        language: 'ur',
      ),
    ).called(1);
    expect(find.text('معتبر ماخذ کی وضاحت'), findsOneWidget);
  });

  testWidgets(
    'unavailable voice input reports the problem and preserves typed entry',
    (tester) async {
      await _mount(tester, _Repository());
      await tester.enterText(find.byType(TextField), 'My typed question');
      await tester.tap(find.byTooltip('Voice input'));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Voice input is unavailable on this device. Type your question instead.',
        ),
        findsOneWidget,
      );
      expect(find.text('My typed question'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('leaving cancels generation and ignores its late completion', (
    tester,
  ) async {
    final repository = _Repository();
    final pending = Completer<GroundedAnswer>();
    when(
      () => repository.ask(
        question: any(named: 'question'),
        medicationId: any(named: 'medicationId'),
        mode: any(named: 'mode'),
        language: any(named: 'language'),
      ),
    ).thenAnswer((_) => pending.future);
    await _mount(tester, repository);
    await _send(tester, 'Pending question');
    await tester.pumpWidget(const SizedBox());
    verify(() => repository.cancelActiveAnswer()).called(1);
    pending.complete(_answer('Late response'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
