import 'dart:async';

import '../../core/logging/app_logger.dart';

enum StartupStep {
  environment,
  secureStorage,
  authentication,
  localDatabase,
  privateFileCleanup,
  settings,
  connectivity,
  localization,
  synchronization,
  router,
}

class StartupTask {
  const StartupTask(this.step, this.initialize);

  final StartupStep step;
  final Future<void> Function() initialize;
}

class StartupResult {
  const StartupResult({required this.completedSteps, required this.elapsed});

  final List<StartupStep> completedSteps;
  final Duration elapsed;
}

class StartupFailure implements Exception {
  const StartupFailure({required this.step, required this.cause});

  final StartupStep step;
  final Object cause;
}

class StartupCoordinator {
  StartupCoordinator({
    required List<StartupTask> tasks,
    this.taskTimeout = const Duration(seconds: 12),
  }) : assert(
         _isDeterministicOrder(tasks),
         'Startup tasks must follow the required deterministic order.',
       ),
       _tasks = List.unmodifiable(tasks);

  final List<StartupTask> _tasks;
  final Duration taskTimeout;

  static bool _isDeterministicOrder(List<StartupTask> tasks) {
    if (tasks.length != StartupStep.values.length) return false;
    for (var index = 0; index < tasks.length; index++) {
      if (tasks[index].step != StartupStep.values[index]) return false;
    }
    return true;
  }

  Future<StartupResult> initialize() async {
    final stopwatch = Stopwatch()..start();
    final completed = <StartupStep>[];
    for (final task in _tasks) {
      try {
        await task.initialize().timeout(taskTimeout);
        completed.add(task.step);
      } on Object catch (error, stackTrace) {
        AppLogger().log(
          LogLevel.error,
          'startup_failed',
          fields: {
            'step': task.step.name,
            'error_type': error.runtimeType.toString(),
          },
          stackTrace: stackTrace,
        );
        throw StartupFailure(step: task.step, cause: error);
      }
    }
    stopwatch.stop();
    return StartupResult(completedSteps: completed, elapsed: stopwatch.elapsed);
  }
}
