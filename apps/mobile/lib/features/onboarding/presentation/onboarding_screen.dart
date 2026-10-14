import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_routes.dart';
import '../../../core/localization/localization_extension.dart';
import '../../../core/safety/medical_safety_policy.dart';
import '../../../design_system/tokens.dart';
import '../../../design_system/widgets/buttons.dart';
import '../../../design_system/widgets/cards.dart';
import '../../../design_system/widgets/states.dart';
import '../../../domain/models/user.dart';
import '../../settings/application/settings_controller.dart';
import '../../settings/domain/app_settings.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  static const _pageCount = 7;
  final _controller = PageController();
  var _page = 0;
  var _consentAccepted = false;
  var _showConsentError = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsControllerProvider).valueOrNull;
    if (settings == null) return const SizedBox.shrink();
    final reducedMotion = settings.reducedMotion;

    return Scaffold(
      appBar: AppBar(
        leading: _page == 0
            ? null
            : IconButton(
                tooltip: context.l10n.back,
                onPressed: _previous,
                icon: const Icon(Icons.arrow_back_rounded),
              ),
        actions: [
          Padding(
            padding: const EdgeInsetsDirectional.only(end: AppSpacing.md),
            child: Center(child: Text('${_page + 1} / $_pageCount')),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Semantics(
              label: '${_page + 1} / $_pageCount',
              child: LinearProgressIndicator(value: (_page + 1) / _pageCount),
            ),
            Expanded(
              child: PageView(
                controller: _controller,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (page) => setState(() => _page = page),
                children: [
                  _IntroPage(
                    icon: Icons.medical_information_outlined,
                    title: context.l10n.welcomeTitle,
                    body: context.l10n.welcomeBody,
                  ),
                  _PillarsPage(),
                  _PrivacySafetyPage(),
                  _LanguagePage(selected: settings.languageCode),
                  _AccessibilityPage(settings: settings),
                  _UsageModePage(mode: settings.userMode),
                  _ConsentPage(
                    accepted: _consentAccepted,
                    showError: _showConsentError,
                    onChanged: (value) => setState(() {
                      _consentAccepted = value;
                      _showConsentError = false;
                    }),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.sm,
                AppSpacing.lg,
                AppSpacing.lg,
              ),
              child: AppPrimaryButton(
                expand: true,
                label: _page == _pageCount - 1
                    ? context.l10n.getStarted
                    : context.l10n.continueLabel,
                onPressed: () => _next(reducedMotion),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _next(bool reducedMotion) async {
    if (_page < _pageCount - 1) {
      if (reducedMotion) {
        _controller.jumpToPage(_page + 1);
      } else {
        await _controller.nextPage(
          duration: AppDurations.normal,
          curve: Curves.easeOutCubic,
        );
      }
      return;
    }
    if (!_consentAccepted) {
      setState(() => _showConsentError = true);
      return;
    }
    await ref
        .read(settingsControllerProvider.notifier)
        .completeOnboarding(
          consentVersion:
              const DefaultMedicalSafetyPolicy().currentConsentVersion,
        );
    if (mounted) context.go(AppRoute.home.path);
  }

  void _previous() => _controller.previousPage(
    duration: AppDurations.normal,
    curve: Curves.easeOutCubic,
  );
}

class _OnboardingLayout extends StatelessWidget {
  const _OnboardingLayout({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(AppSpacing.lg),
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppDimensions.formMaxWidth),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ),
    ),
  );
}

class _IntroPage extends StatelessWidget {
  const _IntroPage({
    required this.icon,
    required this.title,
    required this.body,
  });
  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => _OnboardingLayout(
    children: [
      const SizedBox(height: AppSpacing.xl),
      Align(
        alignment: AlignmentDirectional.centerStart,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(AppRadii.large),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Icon(
              icon,
              size: 56,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
          ),
        ),
      ),
      const SizedBox(height: AppSpacing.xl),
      Text(title, style: Theme.of(context).textTheme.displaySmall),
      const SizedBox(height: AppSpacing.md),
      Text(body, style: Theme.of(context).textTheme.bodyLarge),
    ],
  );
}

class _PillarsPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) => _OnboardingLayout(
    children: [
      Text(
        context.l10n.understandTitle,
        style: Theme.of(context).textTheme.headlineMedium,
      ),
      const SizedBox(height: AppSpacing.lg),
      _PillarCard(
        icon: Icons.menu_book_outlined,
        title: context.l10n.understandTitle,
        body: context.l10n.understandBody,
      ),
      const SizedBox(height: AppSpacing.sm),
      _PillarCard(
        icon: Icons.receipt_long_outlined,
        title: context.l10n.prescriptionTitle,
        body: context.l10n.prescriptionBody,
      ),
      const SizedBox(height: AppSpacing.sm),
      _PillarCard(
        icon: Icons.school_outlined,
        title: context.l10n.learnTitle,
        body: context.l10n.learnBody,
      ),
    ],
  );
}

class _PillarCard extends StatelessWidget {
  const _PillarCard({
    required this.icon,
    required this.title,
    required this.body,
  });
  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => AppCard(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: AppSpacing.xxs),
              Text(body),
            ],
          ),
        ),
      ],
    ),
  );
}

class _PrivacySafetyPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) => _OnboardingLayout(
    children: [
      _IntroPageContent(
        icon: Icons.lock_outline_rounded,
        title: context.l10n.privacyTitle,
        body: context.l10n.privacyBody,
      ),
      const SizedBox(height: AppSpacing.xl),
      _IntroPageContent(
        icon: AppIcons.shield,
        title: context.l10n.safetyTitle,
        body: context.l10n.safetyBody,
      ),
    ],
  );
}

class _IntroPageContent extends StatelessWidget {
  const _IntroPageContent({
    required this.icon,
    required this.title,
    required this.body,
  });
  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 40, color: Theme.of(context).colorScheme.primary),
      const SizedBox(height: AppSpacing.md),
      Text(title, style: Theme.of(context).textTheme.headlineMedium),
      const SizedBox(height: AppSpacing.sm),
      Text(body, style: Theme.of(context).textTheme.bodyLarge),
    ],
  );
}

class _LanguagePage extends ConsumerWidget {
  const _LanguagePage({required this.selected});
  final String selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) => _OnboardingLayout(
    children: [
      Text(
        context.l10n.languageTitle,
        style: Theme.of(context).textTheme.headlineMedium,
      ),
      const SizedBox(height: AppSpacing.lg),
      RadioGroup<String>(
        groupValue: selected,
        onChanged: (value) {
          if (value != null) {
            ref.read(settingsControllerProvider.notifier).setLanguage(value);
          }
        },
        child: Column(
          children: [
            RadioListTile(value: 'en', title: Text(context.l10n.english)),
            RadioListTile(value: 'ur', title: Text(context.l10n.urdu)),
          ],
        ),
      ),
    ],
  );
}

class _AccessibilityPage extends ConsumerWidget {
  const _AccessibilityPage({required this.settings});
  final AppSettings settings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(settingsControllerProvider.notifier);
    return _OnboardingLayout(
      children: [
        Text(
          context.l10n.accessibilityTitle,
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: AppSpacing.lg),
        SwitchListTile(
          title: Text(context.l10n.largerText),
          value: settings.textScale > 1,
          onChanged: (value) => controller.persist(
            (current) => current.copyWith(textScale: value ? 1.25 : 1),
          ),
        ),
        SwitchListTile(
          title: Text(context.l10n.largerControls),
          value: settings.largeControls,
          onChanged: (value) => controller.persist(
            (current) => current.copyWith(largeControls: value),
          ),
        ),
        SwitchListTile(
          title: Text(context.l10n.highReadability),
          value: settings.highReadability,
          onChanged: (value) => controller.persist(
            (current) => current.copyWith(highReadability: value),
          ),
        ),
        SwitchListTile(
          title: Text(context.l10n.reduceMotion),
          value: settings.reducedMotion,
          onChanged: (value) => controller.persist(
            (current) => current.copyWith(reducedMotion: value),
          ),
        ),
      ],
    );
  }
}

class _UsageModePage extends ConsumerWidget {
  const _UsageModePage({required this.mode});
  final UserMode mode;

  @override
  Widget build(BuildContext context, WidgetRef ref) => _OnboardingLayout(
    children: [
      Text(
        context.l10n.usageModeTitle,
        style: Theme.of(context).textTheme.headlineMedium,
      ),
      const SizedBox(height: AppSpacing.lg),
      RadioGroup<UserMode>(
        groupValue: mode,
        onChanged: (value) {
          if (value != null) {
            ref.read(settingsControllerProvider.notifier).setMode(value);
          }
        },
        child: Column(
          children: [
            RadioListTile(
              value: UserMode.patient,
              title: Text(context.l10n.patientMode),
              subtitle: Text(context.l10n.patientModeBody),
            ),
            RadioListTile(
              value: UserMode.student,
              title: Text(context.l10n.studentMode),
              subtitle: Text(context.l10n.studentModeBody),
            ),
            RadioListTile(
              value: UserMode.guest,
              title: Text(context.l10n.guestMode),
              subtitle: Text(context.l10n.guestModeBody),
            ),
          ],
        ),
      ),
    ],
  );
}

class _ConsentPage extends StatelessWidget {
  const _ConsentPage({
    required this.accepted,
    required this.showError,
    required this.onChanged,
  });
  final bool accepted;
  final bool showError;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => _OnboardingLayout(
    children: [
      Text(
        context.l10n.consentTitle,
        style: Theme.of(context).textTheme.headlineMedium,
      ),
      const SizedBox(height: AppSpacing.md),
      AppBanner(message: context.l10n.safetyBody, icon: AppIcons.shield),
      const SizedBox(height: AppSpacing.lg),
      CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        controlAffinity: ListTileControlAffinity.leading,
        value: accepted,
        onChanged: (value) => onChanged(value ?? false),
        title: Text(context.l10n.consentBody),
      ),
      if (showError) ...[
        const SizedBox(height: AppSpacing.sm),
        AppInlineError(message: context.l10n.consentRequired),
      ],
    ],
  );
}
