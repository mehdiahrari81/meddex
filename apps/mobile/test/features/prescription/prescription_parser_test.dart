import 'package:flutter_test/flutter_test.dart';
import 'package:mediexplain/features/prescription/application/prescription_parsers.dart';
import 'package:mediexplain/features/prescription/domain/prescription_models.dart';

void main() {
  const normalizer = ConservativeOcrNormalizer();
  const strength = StrengthParser();
  const form = DosageFormParser();
  const dose = DoseParser();
  const duration = DurationParser();
  const instructions = InstructionParser();
  const date = DateParser();
  const suggestions = NoMedicationCandidateSuggestionService();
  const medication = MedicationCandidateParser(suggestions);
  const abbreviations = _FakeAbbreviationResolver();
  const route = RouteParser(abbreviations);
  const frequency = FrequencyParser(abbreviations);
  const parser = PrescriptionParser(
    normalizer: normalizer,
    segmenter: PrescriptionLineSegmenter(medication, strength),
    medicationParser: medication,
    strengthParser: strength,
    formParser: form,
    doseParser: dose,
    routeParser: route,
    frequencyParser: frequency,
    durationParser: duration,
    instructionParser: instructions,
    dateParser: date,
  );

  group('conservative OCR normalization', () {
    test('normalizes whitespace and compatibility punctuation only', () {
      expect(
        normalizer.normalize('  Amoxicillin\t 500 mg \r\n\r\n  TID  '),
        'Amoxicillin 500 mg\nTID',
      );
      expect(normalizer.normalize('Ａｍｏｘ ５O mg'), 'Amox 5O mg');
    });

    test('does not mutate ambiguous medical numbers', () {
      for (final value in ['5O mg', 'I0 mg', '.5 mg', '50 mg', '500 mg']) {
        expect(normalizer.normalize(value), value);
      }
    });
  });

  group('strength parser and numeric safety', () {
    test('parses supported literals without calculating dose', () {
      expect(strength.parse('Amoxicillin 500 mg')!.value, '500 mg');
      expect(strength.parse('Medicine 5 mg')!.value, '5 mg');
      expect(strength.parse('Medicine 0.5 mg')!.value, '0.5 mg');
      expect(strength.parse('Syrup 250 mg / 5 mL')!.value, '250 mg/5 mL');
      expect(strength.parse('Medicine strength unknown'), isNull);
      expect(strength.parse('Medicine 5O mg'), isNull);
      expect(strength.parse('Amoxici1lin'), isNull);
      expect(strength.parse('Amoxici1lin 500 mg')!.value, '500 mg');
      expect(strength.parse('Vitamin 100 IU')!.ambiguous, isFalse);
      expect(dose.parse('take 2 capsules')!.value, 'take 2 capsules');
    });

    test('preserves leading decimal and flags it for review', () {
      final result = strength.parse('.5 mg')!;
      expect(result.value, '.5 mg');
      expect(result.ambiguous, isTrue);
    });
  });

  test('dosage forms normalize only explicit written forms', () {
    expect(form.parse('1 tab')!.value, 'tablet');
    expect(form.parse('one tablet')!.value, 'tablet');
    expect(form.parse('1 cap')!.value, 'capsule');
    expect(form.parse('one capsule')!.value, 'capsule');
    expect(form.parse('syrup')!.value, 'syrup');
    expect(form.parse('injection')!.value, 'injection');
    expect(form.parse('Amoxicillin'), isNull);
  });

  group('frequency, duration and route parsing', () {
    test('parses structured frequency patterns', () async {
      expect((await frequency.parse('BID'))!.value.timesPerDay, 2);
      expect((await frequency.parse('TID'))!.value.timesPerDay, 3);
      expect((await frequency.parse('QID'))!.value.timesPerDay, 4);
      expect((await frequency.parse('every 8 hours'))!.value.intervalHours, 8);
      expect((await frequency.parse('PRN'))!.value.asNeeded, isTrue);
    });

    test('preserves ambiguous abbreviation choices', () async {
      final result = await frequency.parse('OD at night');
      expect(result!.ambiguous, isTrue);
      expect(result.possibleMeanings, containsAll(['once daily', 'right eye']));
    });

    test('parses written duration and leaves missing absent', () {
      expect(duration.parse('x 5 days')!.value.value, 5);
      expect(duration.parse('x7d')!.value.value, 7);
      expect(duration.parse('for 2 weeks')!.value.unit, 'week');
      expect(duration.parse('take regularly'), isNull);
    });

    test('parses explicit routes through abbreviation resolver', () async {
      expect((await route.parse('PO'))!.value, 'by mouth');
      expect((await route.parse('IV'))!.value, 'intravenous');
      expect((await route.parse('IM'))!.value, 'intramuscular');
      expect((await route.parse('apply topical'))!.value, 'topical');
    });
  });

  test('medication name is never auto-corrected from OCR', () {
    final result = medication.parse('Amoxici1lin 500mg')!;
    expect(result.rawText, 'Amoxici1lin');
    expect(result.value, 'Amoxici1lin');
    expect(result.ambiguous, isFalse);
    expect(medication.parse('take 1 tablet'), isNull);
  });

  test(
    'orchestrator segments multiple medicines and independent fields',
    () async {
      final result = await parser.parse(
        prescriptionId: 'prescription-1',
        pageNumber: 1,
        rawText: '''
Amoxicillin 500mg
take 2 capsules PO TID x 7 days with food

Paracetamol 500 mg
1 tab PRN pain
''',
      );
      expect(result.items, hasLength(2));
      final first = result.items.first;
      expect(
        first.field(PrescriptionFieldType.medicationName).currentValue,
        'Amoxicillin',
      );
      expect(first.field(PrescriptionFieldType.strength).currentValue, '500mg');
      expect(
        first.field(PrescriptionFieldType.dose).currentValue,
        'take 2 capsules',
      );
      expect(first.frequency!.timesPerDay, 3);
      expect(first.duration!.value, 7);
      expect(
        first.field(PrescriptionFieldType.instructions).currentValue,
        'with food',
      );
      expect(first.state, PrescriptionItemState.needsReview);
      expect(
        first.field(PrescriptionFieldType.medicationName).userConfirmed,
        isFalse,
      );
    },
  );

  test('prescription date parser never invents absent date', () {
    expect(date.parse('Date 13/08/2026')!.value, DateTime.utc(2026, 8, 13));
    expect(date.parse('No date written'), isNull);
    expect(date.parse('99/99/2026'), isNull);
  });

  test(
    'local fallback does not turn headings, patient names, or vitals into medicines',
    () async {
      final result = await parser.parse(
        prescriptionId: 'rx',
        pageNumber: 1,
        rawText:
            'Example Clinic\nDr. Synthetic\nPatient: Synthetic\nDate: 01/10/2026\nBP 120/80\nRx\nAmoxicillin 500mg\ntake 1 capsule\nFollow up next week',
      );
      expect(result.items, hasLength(1));
      expect(result.items.single.rawMedicationText, 'Amoxicillin');
      expect(result.items.single.sourceText, isNot(contains('Follow up')));
    },
  );
}

class _FakeAbbreviationResolver implements PrescriptionAbbreviationResolver {
  const _FakeAbbreviationResolver();

  @override
  Future<AbbreviationResolution> resolve(String abbreviation) async {
    final values = switch (abbreviation.toUpperCase()) {
      'PO' => const ['by mouth'],
      'IV' => const ['intravenous'],
      'IM' => const ['intramuscular'],
      'SC' => const ['subcutaneous'],
      'SL' => const ['sublingual'],
      'BID' || 'BD' => const ['twice daily'],
      'TID' => const ['three times daily'],
      'QID' => const ['four times daily'],
      'PRN' => const ['as needed'],
      'OD' => const ['once daily', 'right eye'],
      _ => const ['test meaning'],
    };
    return AbbreviationResolution(
      detected: abbreviation,
      possibleMeanings: values,
      ambiguous: values.length > 1,
    );
  }
}
