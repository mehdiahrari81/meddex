import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/localization/localization_extension.dart';
import '../core/connectivity/connectivity_service.dart';
import '../core/sync/sync_provider.dart';
import '../core/security/biometric_lock_gate.dart';
import '../design_system/app_theme.dart';
import '../design_system/widgets/states.dart';
import '../domain/models/user.dart';
import '../features/settings/application/settings_controller.dart';
import '../features/auth/application/auth_controller.dart';
import '../features/medications/application/medication_providers.dart';
import '../features/terminology/application/terminology_providers.dart';
import '../l10n/app_localizations.dart';
import 'bootstrap/bootstrap_provider.dart';
import 'router/app_router.dart';

class MediExplainApp extends ConsumerStatefulWidget {
  const MediExplainApp({super.key});

  @override
  ConsumerState<MediExplainApp> createState() => _MediExplainAppState();
}

class _MediExplainAppState extends ConsumerState<MediExplainApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        ref.read(bootstrapProvider).hasValue) {
      ref.invalidate(referenceContentRefreshProvider);
      ref.read(referenceContentRefreshProvider.future);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(
      settingsControllerProvider.select(
        (value) => value.valueOrNull?.notificationsEnabled,
      ),
      (previous, next) {
        if (previous != null &&
            next != null &&
            previous != next &&
            ref.read(bootstrapProvider).hasValue) {
          ref.read(accountReminderCoordinatorProvider).refresh();
        }
      },
    );
    ref.listen(authControllerProvider, (previous, next) {
      if (!ref.read(bootstrapProvider).hasValue || !next.hasValue) return;
      if (previous?.valueOrNull?.session?.userId !=
          next.valueOrNull?.session?.userId) {
        ref.read(accountReminderCoordinatorProvider).refresh();
        ref.invalidate(referenceContentRefreshProvider);
        ref.read(referenceContentRefreshProvider.future);
      }
      if (next.valueOrNull?.status == AuthStatus.authenticated) {
        synchronizeSafely(ref.read(syncCoordinatorProvider));
      }
    });
    ref.listen(connectivityProvider, (previous, next) {
      if (next.valueOrNull == ConnectivityState.online &&
          ref.read(bootstrapProvider).hasValue) {
        ref.invalidate(referenceContentRefreshProvider);
        ref.read(referenceContentRefreshProvider.future);
      }
      if (next.valueOrNull == ConnectivityState.online &&
          ref.read(authControllerProvider).valueOrNull?.status ==
              AuthStatus.authenticated) {
        synchronizeSafely(ref.read(syncCoordinatorProvider));
      }
    });
    ref.listen(bootstrapProvider, (previous, next) {
      if (next.hasValue && previous?.hasValue != true) {
        ref.read(referenceContentRefreshProvider.future);
      }
    });
    final bootstrap = ref.watch(bootstrapProvider);
    final settings = ref.watch(settingsControllerProvider);
    final locale = settings.valueOrNull?.languageCode ?? 'en';
    final highReadability = settings.valueOrNull?.highReadability ?? false;
    final themePreference =
        settings.valueOrNull?.theme ?? AppThemePreference.system;
    final themeMode = switch (themePreference) {
      AppThemePreference.system => ThemeMode.system,
      AppThemePreference.light => ThemeMode.light,
      AppThemePreference.dark => ThemeMode.dark,
    };

    if (!bootstrap.hasValue) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        locale: Locale(locale),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        theme: AppTheme.light(highReadability: highReadability),
        darkTheme: AppTheme.dark(highReadability: highReadability),
        themeMode: themeMode,
        home: Builder(
          builder: (context) => bootstrap.hasError
              ? _StartupError(onRetry: () => ref.invalidate(bootstrapProvider))
              : Scaffold(
                  body: AppLoadingState(label: context.l10n.startupTitle),
                ),
        ),
      );
    }

    return MaterialApp.router(
      onGenerateTitle: (context) => context.l10n.appName,
      debugShowCheckedModeBanner: false,
      locale: Locale(locale),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      theme: AppTheme.light(highReadability: highReadability),
      darkTheme: AppTheme.dark(highReadability: highReadability),
      themeMode: themeMode,
      routerConfig: ref.watch(appRouterProvider),
      builder: (context, child) {
        final configuredScale = settings.valueOrNull?.textScale ?? 1;
        final systemScale = MediaQuery.textScalerOf(context).scale(1);
        final effectiveScale = (systemScale * configuredScale).clamp(0.85, 2.4);
        final app = BiometricLockGate(
          child: MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(effectiveScale),
              disableAnimations:
                  MediaQuery.disableAnimationsOf(context) ||
                  (settings.valueOrNull?.reducedMotion ?? false),
            ),
            child: child ?? const SizedBox.shrink(),
          ),
        );
        return bootstrap.when(
          data: (_) => app,
          loading: () => _StartupOverlay(child: app),
          error: (error, stackTrace) =>
              _StartupError(onRetry: () => ref.invalidate(bootstrapProvider)),
        );
      },
    );
  }
}

class _StartupOverlay extends StatelessWidget {
  const _StartupOverlay({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      ExcludeSemantics(child: Opacity(opacity: 0, child: child)),
      ColoredBox(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: AppLoadingState(label: context.l10n.startupTitle),
      ),
    ],
  );
}

class _StartupError extends StatelessWidget {
  const _StartupError({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: AppFullScreenError(
      title: context.l10n.startupErrorTitle,
      message: context.l10n.startupErrorMessage,
      retryLabel: context.l10n.retry,
      onRetry: onRetry,
    ),
  );
}
