import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_routes.dart';
import '../../../core/localization/localization_extension.dart';
import '../../../design_system/tokens.dart';
import '../../../design_system/widgets/buttons.dart';
import '../../../design_system/widgets/cards.dart';
import '../../../design_system/widgets/overlays.dart';
import '../../../design_system/widgets/settings_row.dart';
import '../../auth/application/auth_controller.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider).valueOrNull;
    final authenticated = auth?.status == AuthStatus.authenticated;
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.profile)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppCard(
                    child: Row(
                      children: [
                        ProfileAvatar(
                          label: authenticated
                              ? context.l10n.account
                              : context.l10n.guestMode,
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                authenticated
                                    ? context.l10n.account
                                    : context.l10n.guestMode,
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(height: AppSpacing.xxs),
                              Text(
                                authenticated
                                    ? context.l10n.signedIn
                                    : context.l10n.signedOut,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AppCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        SettingsRow(
                          title: context.l10n.settings,
                          leading: Icons.settings_outlined,
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () => context.push(AppRoute.settings.path),
                        ),
                        const Divider(height: 1),
                        SettingsRow(
                          title: 'My Medications',
                          leading: Icons.medication_outlined,
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () => context.push(AppRoute.medications.path),
                        ),
                        const Divider(height: 1),
                        SettingsRow(
                          title: 'Medication privacy',
                          leading: Icons.privacy_tip_outlined,
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () =>
                              context.push(AppRoute.medicationPrivacy.path),
                        ),
                        const Divider(height: 1),
                        SettingsRow(
                          title: 'Share medication summary',
                          leading: Icons.share_outlined,
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () =>
                              context.push(AppRoute.medicationShare.path),
                        ),
                        if (authenticated) ...[
                          const Divider(height: 1),
                          SettingsRow(
                            title: context.l10n.manageSessions,
                            leading: Icons.devices_outlined,
                            trailing: const Icon(Icons.chevron_right_rounded),
                            onTap: () => context.push(AppRoute.sessions.path),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  if (authenticated)
                    AppSecondaryButton(
                      expand: true,
                      icon: Icons.logout_rounded,
                      label: context.l10n.signOut,
                      onPressed: () => _signOut(context, ref),
                    )
                  else
                    AppPrimaryButton(
                      expand: true,
                      label: context.l10n.signIn,
                      onPressed: () => context.push(AppRoute.auth.path),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    final confirmed = await AppOverlays.confirm(
      context,
      title: context.l10n.signOut,
      message: context.l10n.confirmSignOut,
      confirmLabel: context.l10n.signOut,
      cancelLabel: context.l10n.cancel,
    );
    if (confirmed) await ref.read(authControllerProvider.notifier).signOut();
  }
}
