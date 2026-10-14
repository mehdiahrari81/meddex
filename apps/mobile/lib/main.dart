import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'core/logging/app_logger.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final logger = AppLogger();

  await runZonedGuardedApp(
    logger: logger,
    app: const ProviderScope(child: MediExplainApp()),
  );
}
