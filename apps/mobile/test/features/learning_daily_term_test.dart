import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediexplain/core/database/app_database.dart';
import 'package:mediexplain/features/learning/application/daily_term.dart';
import 'package:mediexplain/features/terminology/data/local_terminology_repository.dart';
import 'package:mediexplain/features/terminology/data/terminology_seed_importer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'daily term is stable within a date and changes each calendar day',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      await TerminologySeedImporter(db).importJson(
        File('assets/terminology/starter_dataset_v1.json').readAsStringSync(),
      );
      final terms = await LocalTerminologyRepository(
        db,
      ).browseTerms(limit: 100);
      const selector = DailyTermSelector();
      final seen = <String>{};
      for (var i = 0; i < terms.length; i++) {
        final morning = DateTime(2026, 10, 19 + i, 1);
        final evening = DateTime(2026, 10, 19 + i, 23);
        final selected = selector.select(terms, morning)!;
        expect(
          selector.select(terms.reversed.toList(), evening)!.id,
          selected.id,
        );
        expect(seen.add(selected.id), isTrue);
      }
      expect(selector.select([], DateTime.now()), isNull);
      expect(
        selector.select(terms, DateTime(2023, 12, 31))!.id,
        isNot(selector.select(terms, DateTime(2024, 1, 1))!.id),
      );
    },
  );

  testWidgets('calendar day refreshes at midnight and on resume', (
    tester,
  ) async {
    var now = DateTime(2026, 10, 19, 23, 59, 59);
    final container = ProviderContainer(
      overrides: [learningClockProvider.overrideWithValue(() => now)],
    );
    final subscription = container.listen(localLearningDayProvider, (_, _) {});
    expect(container.read(localLearningDayProvider), DateTime(2026, 10, 19));
    now = DateTime(2026, 10, 20);
    await tester.pump(const Duration(seconds: 1));
    expect(container.read(localLearningDayProvider), DateTime(2026, 10, 20));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    now = DateTime(2026, 10, 22, 9);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(const Duration(milliseconds: 1));
    expect(container.read(localLearningDayProvider), DateTime(2026, 10, 22));
    subscription.close();
    container.dispose();
    await tester.pump(const Duration(milliseconds: 1));
  });
}
