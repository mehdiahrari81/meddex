import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediexplain/core/database/app_database.dart';
import 'package:mediexplain/features/terminology/application/resolve_medical_term.dart';
import 'package:mediexplain/features/terminology/application/word_decoder.dart';
import 'package:mediexplain/features/terminology/data/local_terminology_repository.dart';
import 'package:mediexplain/features/terminology/data/terminology_seed_importer.dart';
import 'package:mediexplain/features/terminology/domain/decoder.dart';
import 'package:mediexplain/features/terminology/domain/search.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase database;
  late LocalTerminologyRepository repository;
  late ResolveMedicalTerm resolve;

  setUp(() async {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    final raw = File(
      'assets/terminology/starter_dataset_v1.json',
    ).readAsStringSync();
    await TerminologySeedImporter(database).importJson(raw);
    repository = LocalTerminologyRepository(database);
    resolve = ResolveMedicalTerm(repository);
  });

  tearDown(() => database.close());

  group('terminology resolution', () {
    final cases = <(String, ResolutionType, String)>[
      ('hypertension', ResolutionType.exact, 'Hypertension'),
      ('HYPERTENSION', ResolutionType.exact, 'Hypertension'),
      ('  hypertension!! ', ResolutionType.exact, 'Hypertension'),
      ('rapid heart rate', ResolutionType.synonym, 'Tachycardia'),
      ('high blood pressure', ResolutionType.layEquivalent, 'Hypertension'),
      ('HTN', ResolutionType.abbreviation, 'Hypertension'),
      ('tachy', ResolutionType.partial, 'Tachycardia'),
      ('cardiomyopaty', ResolutionType.fuzzy, 'Cardiomyopathy'),
    ];

    for (final value in cases) {
      test('${value.$2.name}: ${value.$1}', () async {
        final result = await resolve(value.$1);
        expect(result.type, value.$2);
        expect(result.results.first.term.canonicalTerm, value.$3);
      });
    }

    test('exact match ranks above partial and fuzzy candidates', () async {
      final result = await resolve('heart rate');
      expect(result.results.first.term.canonicalTerm, 'Heart rate');
      expect(result.results.first.matchType, ResolutionType.exact);
      expect(
        result.results.first.relevance,
        greaterThan(result.results.skip(1).firstOrNull?.relevance ?? 0),
      );
    });

    test('unknown text returns no match without guessing', () async {
      final result = await resolve('zzzzunknown');
      expect(result.type, ResolutionType.noMatch);
      expect(result.results, isEmpty);
    });

    test('ambiguous abbreviation returns all plausible choices', () async {
      final result = await resolve('MS');
      expect(result.type, ResolutionType.ambiguous);
      expect(result.ambiguous, isTrue);
      expect(
        result.results.map((value) => value.term.canonicalTerm),
        containsAll(['Multiple sclerosis', 'Mitral stenosis']),
      );
    });
  });

  group('medical word decoder', () {
    test(
      'exact known term returns curated multi-component breakdown',
      () async {
        final result = await MedicalWordDecoder(
          repository,
        ).decode('gastroenteritis');
        expect(result.exactTerm?.canonicalTerm, 'Gastroenteritis');
        expect(result.confidence, DecodeConfidence.complete);
        expect(
          result.components.map((value) => value.meaning),
          containsAll(['stomach', 'intestine', 'inflammation']),
        );
        expect(result.unknownFragments, isEmpty);
      },
    );

    test('known prefix root and suffix are parsed deterministically', () async {
      final result = await MedicalWordDecoder(repository).decode('tachycardia');
      expect(result.components.map((value) => value.surfaceText), [
        'tachy',
        'cardi',
        'ia',
      ]);
    });

    test('incomplete decomposition reports unknown segment', () async {
      final result = await MedicalWordDecoder(repository).decode('cardixyz');
      expect(result.confidence, DecodeConfidence.partial);
      expect(result.components.single.meaning, 'heart');
      expect(result.unknownFragments.single.text, 'xyz');
    });

    test('unrecognized word is not forced into a decomposition', () async {
      final result = await MedicalWordDecoder(repository).decode('xyzabc');
      expect(result.confidence, DecodeConfidence.none);
      expect(result.components, isEmpty);
      expect(result.unknownFragments.single.text, 'xyzabc');
    });
  });
}
