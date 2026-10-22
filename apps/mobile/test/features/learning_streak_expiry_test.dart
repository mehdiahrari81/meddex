import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediexplain/core/database/app_database.dart';
import 'package:mediexplain/core/database/database_provider.dart';
import 'package:mediexplain/core/sync/sync_coordinator.dart';
import 'package:mediexplain/core/sync/sync_provider.dart';
import 'package:mediexplain/features/learning/application/daily_term.dart';
import 'package:mediexplain/features/learning/application/learning_providers.dart';
import 'package:mediexplain/features/learning/data/local_learning_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'streak expires after missed days, preserves longest, and restarts at one',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      final sync = SyncCoordinator(
        database: db,
        transport: const DisabledSyncTransport(),
      );
      var now = DateTime(2026, 10, 18, 10);
      final repo = LocalLearningRepository(db, sync, clock: () => now);
      try {
        await repo.recordMeaningfulActivity(now);
        now = DateTime(2026, 10, 19, 10);
        await repo.recordMeaningfulActivity(now);
        expect((await repo.streak()).current, 2);
        now = DateTime(2026, 10, 20, 23, 59, 59);
        expect((await repo.streak()).current, 2);
        now = DateTime(2026, 10, 21);
        expect((await repo.streak()).current, 0);
        expect((await repo.streak()).longest, 2);
        // Reading the expired streak must not overwrite persisted history.
        expect(
          (await db.select(db.learningStreaks).getSingle()).currentStreak,
          2,
        );
        await repo.recordMeaningfulActivity(now);
        expect((await repo.streak()).current, 1);
        expect((await repo.streak()).longest, 2);
        await repo.recordMeaningfulActivity(DateTime(2026, 10, 18));
        expect((await repo.streak()).current, 1);
        expect((await repo.streak()).lastLearningDate, DateTime(2026, 10, 21));
      } finally {
        sync.dispose();
        await db.close();
      }
    },
  );

  testWidgets(
    'dashboard expires streak at local midnight and refreshes after suspension',
    (tester) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final sync = SyncCoordinator(
        database: db,
        transport: const DisabledSyncTransport(),
      );
      var now = DateTime(2026, 10, 19, 23, 59, 59);
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          syncCoordinatorProvider.overrideWithValue(sync),
          learningClockProvider.overrideWithValue(() => now),
        ],
      );
      final subscription = container.listen(
        learningDashboardProvider,
        (_, _) {},
      );
      try {
        final repo = container.read(learningRepositoryProvider);
        await tester.runAsync(
          () => repo.recordMeaningfulActivity(DateTime(2026, 10, 18, 12)),
        );
        await tester.pumpAndSettle();
        expect(
          (await tester.runAsync(
            () => container.read(learningDashboardProvider.future),
          ))!.streak.current,
          1,
        );
        now = DateTime(2026, 10, 20);
        await tester.pump(const Duration(seconds: 1));
        expect(
          (await tester.runAsync(
            () => container.read(learningDashboardProvider.future),
          ))!.streak.current,
          0,
        );
        await tester.runAsync(() => repo.recordMeaningfulActivity(now));
        await tester.pumpAndSettle();
        expect(
          (await tester.runAsync(
            () => container.read(learningDashboardProvider.future),
          ))!.streak.current,
          1,
        );
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        now = DateTime(2026, 10, 24, 8);
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pump();
        expect(
          (await tester.runAsync(
            () => container.read(learningDashboardProvider.future),
          ))!.streak.current,
          0,
        );
      } finally {
        subscription.close();
        container.dispose();
        sync.dispose();
        await tester.pump(const Duration(milliseconds: 1));
      }
    },
  );
}
