import 'package:flutter_test/flutter_test.dart';
import 'package:mediexplain/app/bootstrap/startup_coordinator.dart';

void main() {
  test(
    'startup coordinator executes every step in deterministic order',
    () async {
      final calls = <StartupStep>[];
      final coordinator = StartupCoordinator(
        tasks: [
          for (final step in StartupStep.values)
            StartupTask(step, () async => calls.add(step)),
        ],
      );

      final result = await coordinator.initialize();

      expect(calls, StartupStep.values);
      expect(result.completedSteps, StartupStep.values);
    },
  );

  test(
    'startup coordinator reports the failing step and never hangs',
    () async {
      final tasks = [
        for (final step in StartupStep.values)
          StartupTask(step, () async {
            if (step == StartupStep.localDatabase) {
              throw StateError('unavailable');
            }
          }),
      ];

      await expectLater(
        StartupCoordinator(tasks: tasks).initialize(),
        throwsA(
          isA<StartupFailure>().having(
            (failure) => failure.step,
            'step',
            StartupStep.localDatabase,
          ),
        ),
      );
    },
  );
}
