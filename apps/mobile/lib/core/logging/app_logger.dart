import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/widgets.dart';

enum LogLevel { debug, info, warning, error }

class AppLogger {
  AppLogger({this.minimumLevel = LogLevel.info});

  final LogLevel minimumLevel;

  static final RegExp _sensitiveKey = RegExp(
    r'(password|token|authorization|cookie|prescription|medication)',
    caseSensitive: false,
  );

  void log(
    LogLevel level,
    String event, {
    Map<String, Object?> fields = const {},
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (level.index < minimumLevel.index) return;
    final safeFields = <String, Object?>{
      for (final entry in fields.entries)
        entry.key: _sensitiveKey.hasMatch(entry.key)
            ? '[REDACTED]'
            : entry.value,
    };
    developer.log(
      '$event ${safeFields.isEmpty ? '' : safeFields}',
      name: 'mediexplain',
      level: switch (level) {
        LogLevel.debug => 500,
        LogLevel.info => 800,
        LogLevel.warning => 900,
        LogLevel.error => 1000,
      },
      error: error,
      stackTrace: stackTrace,
    );
  }
}

Future<void> runZonedGuardedApp({
  required AppLogger logger,
  required Widget app,
}) async {
  FlutterError.onError = (details) {
    logger.log(
      LogLevel.error,
      'flutter_error',
      error: details.exception,
      stackTrace: details.stack,
    );
  };
  runZonedGuarded(
    () => runApp(app),
    (error, stackTrace) => logger.log(
      LogLevel.error,
      'uncaught_error',
      error: error,
      stackTrace: stackTrace,
    ),
  );
}
