import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediexplain/domain/models/source_provenance.dart';
import 'package:mediexplain/domain/models/user.dart';
import 'package:mediexplain/features/terminology/application/term_presentation.dart';
import 'package:mediexplain/features/terminology/domain/medical_term.dart';
import 'package:mediexplain/l10n/app_localizations.dart';

void main() {
  final term = MedicalTerm(
    id: 'term-test',
    canonicalTerm: 'Test term',
    normalizedTerm: 'test term',
    definitions: const [
      TermDefinition(
        language: 'en',
        simple: 'Simple explanation',
        standard: 'Standard explanation',
        technical: 'Technical explanation',
        reviewStatus: ContentReviewStatus.reviewed,
        version: 1,
      ),
    ],
    categoryId: 'general',
    synonyms: const [],
    alternativeSpellings: const [],
    layTerms: const [],
    abbreviations: const [],
    relatedTermIds: const [],
    morphology: const [],
    examples: const [],
    sources: const <SourceProvenance>[],
    language: 'en',
    reviewStatus: ContentReviewStatus.reviewed,
    version: 1,
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
  );

  test('patient simple mode hides standard and technical depth', () {
    final presentation = const BuildTermPresentation()(
      term: term,
      locale: 'en',
      userMode: UserMode.patient,
      explanationLevel: ExplanationLevel.simple,
    );
    expect(presentation.primaryDefinition, 'Simple explanation');
    expect(presentation.showStandard, isFalse);
    expect(presentation.showTechnical, isFalse);
    expect(presentation.prioritizeMorphology, isFalse);
  });

  test('student mode keeps simple meaning and exposes technical depth', () {
    final presentation = const BuildTermPresentation()(
      term: term,
      locale: 'ur',
      userMode: UserMode.student,
      explanationLevel: ExplanationLevel.standard,
    );
    expect(presentation.primaryDefinition, 'Simple explanation');
    expect(presentation.showStandard, isTrue);
    expect(presentation.showTechnical, isTrue);
    expect(presentation.prioritizeMorphology, isTrue);
  });

  testWidgets('long Urdu Module 2 translation is RTL and remains renderable', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ur'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        home: Builder(
          builder: (context) => Scaffold(
            body: SingleChildScrollView(
              child: Text(
                AppLocalizations.of(context).noBreakdownBody,
                textScaler: const TextScaler.linear(2),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final text = find.byType(Text).first;
    expect(Directionality.of(tester.element(text)), TextDirection.rtl);
    expect(tester.takeException(), isNull);
  });
}
