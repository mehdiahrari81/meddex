import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_provider.dart';
import '../../../core/localization/localization_extension.dart';
import '../../../core/security/biometric_lock.dart';
import '../../../app/router/app_routes.dart';
import 'package:go_router/go_router.dart';
import '../../../design_system/tokens.dart';
import '../../../design_system/widgets/cards.dart';
import '../../../design_system/widgets/overlays.dart';
import '../../../design_system/widgets/settings_row.dart';
import '../../../design_system/widgets/states.dart';
import '../../../domain/models/user.dart';
import '../application/settings_controller.dart';
import '../domain/app_settings.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsControllerProvider);
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.settings)),
      body: settings.when(
        loading: () => AppLoadingState(label: context.l10n.startupMessage),
        error: (error, stackTrace) => AppFullScreenError(
          title: context.l10n.startupErrorTitle,
          message: context.l10n.startupErrorMessage,
          retryLabel: context.l10n.retry,
          onRetry: () => ref.invalidate(settingsControllerProvider),
        ),
        data: (value) => _SettingsList(settings: value),
      ),
    );
  }
}

class _SettingsList extends ConsumerWidget {
  const _SettingsList({required this.settings});
  final AppSettings settings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(settingsControllerProvider.notifier);
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.xxl,
      ),
      children: [
        _SettingsSection(
          title: context.l10n.appearance,
          children: [
            SettingsRow(
              title: context.l10n.theme,
              leading: Icons.brightness_6_outlined,
              trailing: DropdownButton<AppThemePreference>(
                value: settings.theme,
                onChanged: (value) {
                  if (value != null) controller.setTheme(value);
                },
                items: [
                  DropdownMenuItem(
                    value: AppThemePreference.system,
                    child: Text(context.l10n.systemTheme),
                  ),
                  DropdownMenuItem(
                    value: AppThemePreference.light,
                    child: Text(context.l10n.lightTheme),
                  ),
                  DropdownMenuItem(
                    value: AppThemePreference.dark,
                    child: Text(context.l10n.darkTheme),
                  ),
                ],
              ),
            ),
            SettingsRow(
              title: context.l10n.textSize,
              leading: Icons.text_fields_rounded,
              trailing: SizedBox(
                width: 160,
                child: Slider(
                  value: settings.textScale,
                  min: 0.9,
                  max: 1.5,
                  divisions: 6,
                  label: '${(settings.textScale * 100).round()}%',
                  onChanged: (value) => controller.persist(
                    (current) => current.copyWith(textScale: value),
                  ),
                ),
              ),
            ),
            _SwitchSetting(
              title: context.l10n.reduceMotion,
              icon: Icons.animation_outlined,
              value: settings.reducedMotion,
              onChanged: (value) => controller.persist(
                (current) => current.copyWith(reducedMotion: value),
              ),
            ),
          ],
        ),
        _SettingsSection(
          title: context.l10n.language,
          children: [
            SettingsRow(
              title: context.l10n.language,
              leading: Icons.language_rounded,
              trailing: DropdownButton<String>(
                value: settings.languageCode,
                onChanged: (value) {
                  if (value != null) controller.setLanguage(value);
                },
                items: [
                  DropdownMenuItem(
                    value: 'en',
                    child: Text(context.l10n.english),
                  ),
                  DropdownMenuItem(value: 'ur', child: Text(context.l10n.urdu)),
                ],
              ),
            ),
          ],
        ),
        _SettingsSection(
          title: context.l10n.accessibility,
          children: [
            _SwitchSetting(
              title: context.l10n.largerControls,
              icon: Icons.touch_app_outlined,
              value: settings.largeControls,
              onChanged: (value) => controller.persist(
                (current) => current.copyWith(largeControls: value),
              ),
            ),
            _SwitchSetting(
              title: context.l10n.highReadability,
              icon: Icons.visibility_outlined,
              value: settings.highReadability,
              onChanged: (value) => controller.persist(
                (current) => current.copyWith(highReadability: value),
              ),
            ),
            _SwitchSetting(
              title: context.l10n.hapticFeedback,
              icon: Icons.vibration_rounded,
              value: settings.hapticsEnabled,
              onChanged: (value) => controller.persist(
                (current) => current.copyWith(hapticsEnabled: value),
              ),
            ),
            _SwitchSetting(
              title: context.l10n.textToSpeech,
              icon: Icons.volume_up_outlined,
              value: settings.ttsEnabled,
              onChanged: (value) => controller.persist(
                (current) => current.copyWith(ttsEnabled: value),
              ),
            ),
          ],
        ),
        _SettingsSection(
          title: context.l10n.medicalExplanation,
          children: [
            SettingsRow(
              title: context.l10n.userMode,
              leading: Icons.person_outline_rounded,
              trailing: DropdownButton<UserMode>(
                value: settings.userMode,
                onChanged: (value) {
                  if (value != null) controller.setMode(value);
                },
                items: [
                  DropdownMenuItem(
                    value: UserMode.patient,
                    child: Text(context.l10n.patientMode),
                  ),
                  DropdownMenuItem(
                    value: UserMode.student,
                    child: Text(context.l10n.studentMode),
                  ),
                  DropdownMenuItem(
                    value: UserMode.guest,
                    child: Text(context.l10n.guestMode),
                  ),
                ],
              ),
            ),
            SettingsRow(
              title: context.l10n.explanationLevel,
              leading: Icons.tune_rounded,
              trailing: DropdownButton<ExplanationLevel>(
                value: settings.explanationLevel,
                onChanged: (value) {
                  if (value != null) controller.setExplanationLevel(value);
                },
                items: [
                  DropdownMenuItem(
                    value: ExplanationLevel.simple,
                    child: Text(context.l10n.simple),
                  ),
                  DropdownMenuItem(
                    value: ExplanationLevel.standard,
                    child: Text(context.l10n.standard),
                  ),
                  DropdownMenuItem(
                    value: ExplanationLevel.technical,
                    child: Text(context.l10n.technical),
                  ),
                ],
              ),
            ),
          ],
        ),
        _SettingsSection(
          title: context.l10n.notifications,
          children: [
            _SwitchSetting(
              title: context.l10n.notificationsMaster,
              icon: Icons.notifications_outlined,
              value: settings.notificationsEnabled,
              onChanged: (value) => controller.persist(
                (current) => current.copyWith(notificationsEnabled: value),
              ),
            ),
            SettingsRow(
              title: context.l10n.remindersPlaceholder,
              subtitle: 'Manage user-confirmed medication reminder privacy.',
              leading: Icons.alarm_outlined,
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => context.push(AppRoute.notificationPrivacy.path),
            ),
          ],
        ),
        _SettingsSection(
          title: context.l10n.privacy,
          children: [
            _SwitchSetting(
              title: 'Delete prescription image after confirmation',
              subtitle:
                  'Keeps structured fields but removes the private image, so OCR cannot be rechecked later.',
              icon: Icons.image_not_supported_outlined,
              value: settings.deletePrescriptionImagesAfterConfirmation,
              onChanged: (value) => controller.persist(
                (current) => current.copyWith(
                  deletePrescriptionImagesAfterConfirmation: value,
                ),
              ),
            ),
            _SwitchSetting(
              title: context.l10n.syncPreference,
              icon: Icons.sync_rounded,
              value: settings.syncEnabled,
              onChanged: (value) => controller.persist(
                (current) => current.copyWith(syncEnabled: value),
              ),
            ),
            _SwitchSetting(
              title: context.l10n.analyticsPreference,
              icon: Icons.analytics_outlined,
              value: settings.analyticsEnabled,
              onChanged: (value) => controller.persist(
                (current) => current.copyWith(analyticsEnabled: value),
              ),
            ),
            SettingsRow(
              title: context.l10n.manageSavedData,
              leading: Icons.storage_outlined,
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => _deleteLocalData(context, ref),
            ),
            SettingsRow(
              title: 'Medication data management',
              leading: Icons.medication_outlined,
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => context.push(AppRoute.medicationPrivacy.path),
            ),
            SettingsRow(
              title: context.l10n.deleteAccount,
              subtitle: context.l10n.accountDeletionInfo,
              leading: Icons.person_remove_outlined,
              onTap: () => AppOverlays.showMessage(
                context,
                context.l10n.accountDeletionInfo,
              ),
            ),
          ],
        ),
        _SettingsSection(
          title: context.l10n.security,
          children: [
            SettingsRow(
              title: context.l10n.manageSessions,
              leading: Icons.devices_outlined,
              onTap: () => AppOverlays.showMessage(
                context,
                context.l10n.notAvailableYet,
              ),
            ),
            _SwitchSetting(
              title: context.l10n.biometricLock,
              icon: Icons.fingerprint_rounded,
              value: settings.biometricLockEnabled,
              onChanged: (value) async {
                if (value) {
                  final service = ref.read(biometricLockProvider);
                  if (!await service.isAvailable() ||
                      !await service.authenticate()) {
                    if (context.mounted) {
                      AppOverlays.showMessage(
                        context,
                        'Device authentication is unavailable or was not completed.',
                      );
                    }
                    return;
                  }
                }
                await controller.persist(
                  (current) => current.copyWith(biometricLockEnabled: value),
                );
              },
              subtitle:
                  'Uses device biometrics or device credential; no biometric data is stored by MediExplain.',
            ),
          ],
        ),
        _SettingsSection(
          title: context.l10n.about,
          children: [
            SettingsRow(
              title: context.l10n.appVersion,
              subtitle: '1.0.0 (1)',
              leading: Icons.info_outline_rounded,
            ),
            SettingsRow(
              title: context.l10n.medicalDisclaimer,
              leading: Icons.health_and_safety_outlined,
              onTap: () =>
                  AppOverlays.showMessage(context, context.l10n.safetyBody),
            ),
            for (final item in [
              (context.l10n.privacyPolicy, Icons.privacy_tip_outlined),
              (context.l10n.terms, Icons.description_outlined),
              (context.l10n.dataSources, Icons.source_outlined),
            ])
              SettingsRow(
                title: item.$1,
                leading: item.$2,
                onTap: () => AppOverlays.showMessage(
                  context,
                  context.l10n.notAvailableYet,
                ),
              ),
            SettingsRow(
              title: context.l10n.openSourceLicenses,
              leading: Icons.code_rounded,
              onTap: () => showLicensePage(
                context: context,
                applicationName: context.l10n.appName,
                applicationVersion: '1.0.0 (1)',
              ),
            ),
            SettingsRow(
              title: context.l10n.resetOnboarding,
              leading: Icons.replay_rounded,
              onTap: () async {
                await ref.read(settingsRepositoryProvider).resetOnboarding();
                ref.invalidate(settingsControllerProvider);
              },
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _deleteLocalData(BuildContext context, WidgetRef ref) async {
    final confirmed = await AppOverlays.confirm(
      context,
      title: context.l10n.deleteLocalData,
      message: context.l10n.confirmDeleteLocalData,
      confirmLabel: context.l10n.deleteLocalData,
      cancelLabel: context.l10n.cancel,
      destructive: true,
    );
    if (!confirmed) return;
    final database = ref.read(databaseProvider);
    await database.transaction(() async {
      await database.delete(database.syncOperations).go();
      await database.delete(database.appMetadata).go();
    });
    await ref.read(settingsRepositoryProvider).clearLocalPreferences();
    ref.invalidate(settingsControllerProvider);
    if (context.mounted) {
      AppOverlays.showMessage(context, context.l10n.dataDeleted);
    }
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.lg),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
            AppSpacing.sm,
            AppSpacing.sm,
            AppSpacing.sm,
            AppSpacing.xs,
          ),
          child: Text(title, style: Theme.of(context).textTheme.titleMedium),
        ),
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (var index = 0; index < children.length; index++) ...[
                children[index],
                if (index < children.length - 1) const Divider(height: 1),
              ],
            ],
          ),
        ),
      ],
    ),
  );
}

class _SwitchSetting extends StatelessWidget {
  const _SwitchSetting({
    required this.title,
    required this.icon,
    required this.value,
    required this.onChanged,
    this.subtitle,
  });
  final String title;
  final String? subtitle;
  final IconData icon;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) => SettingsRow(
    title: title,
    subtitle: subtitle,
    leading: icon,
    trailing: Switch(value: value, onChanged: onChanged),
    onTap: onChanged == null ? null : () => onChanged!(!value),
  );
}
