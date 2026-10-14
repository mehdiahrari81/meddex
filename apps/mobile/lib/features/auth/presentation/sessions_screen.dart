import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/router/app_routes.dart';
import '../../../core/localization/localization_extension.dart';
import '../../../design_system/tokens.dart';
import '../../../design_system/widgets/overlays.dart';
import '../../../design_system/widgets/states.dart';
import '../application/auth_controller.dart';

final accountSessionsProvider =
    FutureProvider.autoDispose<List<Map<String, Object?>>>((ref) {
      final auth = ref.watch(authControllerProvider).valueOrNull;
      if (auth?.status != AuthStatus.authenticated) return const [];
      return ref.watch(apiClientProvider).getJsonList('auth/sessions');
    });

class SessionsScreen extends ConsumerStatefulWidget {
  const SessionsScreen({super.key});

  @override
  ConsumerState<SessionsScreen> createState() => _SessionsScreenState();
}

class _SessionsScreenState extends ConsumerState<SessionsScreen> {
  String? _revoking;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.l10n.manageSessions)),
    body: ref
        .watch(accountSessionsProvider)
        .when(
          loading: () => AppLoadingState(label: context.l10n.loadingSessions),
          error: (_, _) => AppFullScreenError(
            title: context.l10n.manageSessions,
            message: context.l10n.sessionsLoadFailed,
            retryLabel: context.l10n.retry,
            onRetry: () => ref.invalidate(accountSessionsProvider),
          ),
          data: (sessions) => RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(accountSessionsProvider);
              await ref.read(accountSessionsProvider.future);
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                AppBanner(message: context.l10n.sessionsDescription),
                const SizedBox(height: AppSpacing.md),
                for (final session in sessions)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            session['is_current'] == true
                                ? context.l10n.currentSession
                                : context.l10n.otherSession,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            context.l10n.sessionCreated(
                              _date(session['created_at']),
                            ),
                          ),
                          Text(
                            context.l10n.sessionExpires(
                              _date(session['expires_at']),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          OutlinedButton.icon(
                            onPressed: _revoking != null
                                ? null
                                : () => _revoke(session),
                            icon: const Icon(Icons.logout_rounded),
                            label: Text(context.l10n.revokeSession),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
  );

  String _date(Object? value) {
    final date = DateTime.tryParse(value?.toString() ?? '');
    return date == null
        ? '—'
        : DateFormat.yMMMd(
            context.l10n.localeName,
          ).add_jm().format(date.toLocal());
  }

  Future<void> _revoke(Map<String, Object?> session) async {
    final confirmed = await AppOverlays.confirm(
      context,
      title: context.l10n.revokeSession,
      message: context.l10n.revokeSessionConfirmation,
      confirmLabel: context.l10n.revokeSession,
      cancelLabel: context.l10n.cancel,
    );
    if (!confirmed || !mounted) return;
    final id = session['id']! as String;
    setState(() => _revoking = id);
    try {
      await ref
          .read(apiClientProvider)
          .delete('auth/sessions/${Uri.encodeComponent(id)}');
      if (session['is_current'] == true) {
        await ref.read(authControllerProvider.notifier).signOut();
        if (mounted) context.go(AppRoute.profile.path);
        return;
      }
      ref.invalidate(accountSessionsProvider);
    } on Object {
      if (mounted) {
        AppOverlays.showMessage(context, context.l10n.sessionRevokeFailed);
      }
    } finally {
      if (mounted) setState(() => _revoking = null);
    }
  }
}
