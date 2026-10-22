import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediexplain/core/tts/tts_provider.dart';
import 'package:mediexplain/core/tts/tts_service.dart';
import 'package:mediexplain/features/settings/application/settings_controller.dart';
import 'package:mediexplain/features/settings/domain/app_settings.dart';
import 'package:mediexplain/features/terminology/application/terminology_providers.dart';
import 'package:mediexplain/features/terminology/domain/medical_term.dart';
import 'package:mediexplain/features/terminology/presentation/term_detail_screen.dart';
import 'package:mediexplain/l10n/app_localizations.dart';

class _Speech implements TextToSpeechService {
  int stops = 0;
  int plays = 0;
  bool fail = false;
  bool failStop = false;
  @override
  Future<void> speak(String text, {required String locale}) async {
    plays++;
    if (fail) throw StateError('Synthetic unavailable voice');
  }

  @override
  Future<void> stop() async {
    stops++;
    if (failStop) throw StateError('Synthetic stop failure');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Settings extends SettingsController {
  @override
  Future<AppSettings> build() async => const AppSettings.defaults();
}

final _term = MedicalTerm(
  id: 'fixture',
  canonicalTerm: 'Fixture term',
  normalizedTerm: 'fixture term',
  definitions: const [],
  categoryId: 'general',
  synonyms: const [],
  alternativeSpellings: const [],
  layTerms: const [],
  abbreviations: const [],
  relatedTermIds: const [],
  morphology: const [],
  examples: const [],
  sources: const [],
  language: 'en',
  reviewStatus: ContentReviewStatus.reviewed,
  version: 1,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);
Future<void> _mount(WidgetTester tester, _Speech speech) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        textToSpeechProvider.overrideWithValue(speech),
        medicalTermProvider.overrideWith((ref, id) async => _term),
        relatedTermsProvider.overrideWith((ref, id) async => []),
        savedItemsProvider.overrideWith((ref) => Stream.value([])),
        settingsControllerProvider.overrideWith(_Settings.new),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const TermDetailScreen(termId: 'fixture'),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('audio cleanup failure does not break leaving the term screen', (
    tester,
  ) async {
    final speech = _Speech()..failStop = true;
    await _mount(tester, speech);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    expect(speech.stops, 1);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'leaving term details stops audio without reading a disposed ref',
    (tester) async {
      final speech = _Speech();
      await _mount(tester, speech);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      expect(speech.stops, 1);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'unavailable term voice reports an error and permits another attempt',
    (tester) async {
      final speech = _Speech()..fail = true;
      await _mount(tester, speech);
      await tester.tap(find.text('Hear pronunciation'));
      await tester.pumpAndSettle();
      expect(
        find.text('Audio could not be played on this device. Try again.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      speech.fail = false;
      await tester.tap(find.text('Hear pronunciation'));
      await tester.pumpAndSettle();
      expect(speech.plays, 2);
      expect(tester.takeException(), isNull);
    },
  );
}
