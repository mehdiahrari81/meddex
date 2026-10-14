import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_routes.dart';
import '../../../core/localization/localization_extension.dart';
import '../../../design_system/tokens.dart';
import '../../../design_system/widgets/cards.dart';
import '../../../design_system/widgets/states.dart';
import '../../medications/application/medication_providers.dart';
import '../../medications/application/schedule_engine.dart';
import '../../medications/domain/medication_models.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    body: CustomScrollView(
      slivers: [
        SliverAppBar.large(
          title: Text(context.l10n.appName),
          actions: [
            Padding(
              padding: const EdgeInsetsDirectional.only(end: AppSpacing.sm),
              child: IconButton(
                tooltip: context.l10n.settings,
                onPressed: () => context.push(AppRoute.settings.path),
                icon: const Icon(Icons.settings_outlined),
              ),
            ),
          ],
        ),
        SliverToBoxAdapter(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: AppDimensions.contentMaxWidth,
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.xs,
                  AppSpacing.lg,
                  AppSpacing.xxl,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.homeGreeting,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      context.l10n.homeSubtitle,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    if (ref
                            .watch(medicationTimezoneReviewProvider)
                            .valueOrNull ??
                        false) ...[
                      AppCard(
                        child: Row(
                          children: [
                            const Icon(Icons.schedule_outlined),
                            const SizedBox(width: AppSpacing.sm),
                            const Expanded(
                              child: Text(
                                'Your timezone changed. Please review medication reminder times. Prescription instructions were not changed.',
                              ),
                            ),
                            TextButton(
                              onPressed: () async {
                                await context.push(AppRoute.medications.path);
                                await acknowledgeMedicationTimezoneReview(ref);
                              },
                              child: const Text('Review'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                    ],
                    _UpcomingMedicationCard(
                      plans:
                          ref.watch(medicationPlansProvider).valueOrNull ??
                          const [],
                      hideDetails:
                          ref
                              .watch(medicationPrivacyProvider)
                              .valueOrNull
                              ?.hideMedicineDetails ??
                          false,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _ActionGrid(),
                    const SizedBox(height: AppSpacing.xl),
                    AppSectionHeading(title: context.l10n.yourSpace),
                    const SizedBox(height: AppSpacing.md),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final width = constraints.maxWidth;
                        final columns = width >= 850
                            ? 4
                            : width >= 520
                            ? 2
                            : 1;
                        final itemWidth =
                            (width - (AppSpacing.sm * (columns - 1))) / columns;
                        return Wrap(
                          spacing: AppSpacing.sm,
                          runSpacing: AppSpacing.sm,
                          children: [
                            for (final item in [
                              (
                                Icons.play_circle_outline_rounded,
                                context.l10n.continueLearning,
                                AppRoute.learn.path,
                              ),
                              (
                                Icons.history_rounded,
                                context.l10n.recentActivity,
                                AppRoute.recentMedicines.path,
                              ),
                              (
                                Icons.bookmark_outline_rounded,
                                context.l10n.savedContent,
                                AppRoute.saved.path,
                              ),
                              (
                                Icons.notifications_none_rounded,
                                context.l10n.medicationReminders,
                                AppRoute.medications.path,
                              ),
                            ])
                              SizedBox(
                                width: itemWidth,
                                child: _SpaceCard(
                                  icon: item.$1,
                                  label: item.$2,
                                  route: item.$3,
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    AppBanner(
                      message: context.l10n.medicalDisclaimerShort,
                      icon: AppIcons.shield,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _UpcomingMedicationCard extends StatelessWidget {
  const _UpcomingMedicationCard({
    required this.plans,
    required this.hideDetails,
  });
  final List<MedicationPlanDetails> plans;
  final bool hideDetails;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now().toUtc();
    const engine = ScheduleEngine();
    ({MedicationPlanDetails details, DateTime at})? next;
    for (final details in plans) {
      for (final schedule in details.schedules) {
        final times = engine.occurrences(
          plan: details.plan,
          schedule: schedule,
          from: now,
          to: now.add(const Duration(days: 2)),
        );
        if (times.isNotEmpty &&
            (next == null || times.first.isBefore(next.at))) {
          next = (details: details, at: times.first);
        }
      }
    }
    return AppCard(
      semanticLabel: next == null
          ? 'No upcoming fixed medication reminder'
          : 'Next medication reminder. ${next.details.medication.displayName}',
      onTap: () => context.push(AppRoute.medicationTimeline.path),
      child: Row(
        children: [
          const Icon(Icons.alarm_on_outlined, size: 32),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Next medication reminder',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  next == null
                      ? 'No upcoming fixed reminder'
                      : hideDetails
                      ? 'Upcoming reminder • ${next.at.toLocal()}'
                      : '${next.details.medication.displayName} • ${next.at.toLocal()}',
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded),
        ],
      ),
    );
  }
}

class _ActionGrid extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final actions = [
      _Action(
        icon: Icons.medication_outlined,
        title: 'Search medicine information',
        body: 'Resolve an exact identity and review trusted official sources.',
        route: AppRoute.medicineSearch.path,
      ),
      _Action(
        icon: Icons.today_outlined,
        title: "Today's reminders",
        body: 'Review upcoming medication times and record your actions.',
        route: AppRoute.medicationTimeline.path,
      ),
      _Action(
        icon: Icons.receipt_long_outlined,
        title: context.l10n.scanPrescription,
        body: context.l10n.scanPrescriptionBody,
        route: AppRoute.scan.path,
      ),
      _Action(
        icon: Icons.document_scanner_outlined,
        title: context.l10n.scanMedicalTerm,
        body: context.l10n.scanMedicalTermBody,
        route: AppRoute.scanMedicalTerm.path,
      ),
      _Action(
        icon: Icons.search_rounded,
        title: context.l10n.searchMedicalTerm,
        body: context.l10n.searchMedicalTermBody,
        route: AppRoute.termSearch.path,
      ),
      _Action(
        icon: Icons.school_outlined,
        title: context.l10n.learnMedicalTerms,
        body: context.l10n.learnMedicalTermsBody,
        route: AppRoute.learn.path,
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 720
            ? 3
            : constraints.maxWidth >= 460
            ? 2
            : 1;
        final itemWidth =
            (constraints.maxWidth - (AppSpacing.sm * (columns - 1))) / columns;
        return Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final action in actions)
              SizedBox(
                width: itemWidth,
                child: AppCard(
                  semanticLabel: '${action.title}. ${action.body}',
                  onTap: () => _openHomeDestination(context, action.route),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        action.icon,
                        size: 30,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        action.title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        action.body,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _SpaceCard extends StatelessWidget {
  const _SpaceCard({required this.icon, required this.label, this.route});
  final IconData icon;
  final String label;
  final String? route;

  @override
  Widget build(BuildContext context) => AppCard(
    onTap: route == null
        ? () => ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(context.l10n.notAvailableYet)))
        : () => _openHomeDestination(context, route!),
    semanticLabel: label,
    child: Row(
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(label, style: Theme.of(context).textTheme.titleSmall),
        ),
      ],
    ),
  );
}

void _openHomeDestination(BuildContext context, String route) {
  final tabRoutes = {
    AppRoute.home.path,
    AppRoute.scan.path,
    AppRoute.learn.path,
    AppRoute.saved.path,
    AppRoute.profile.path,
  };
  if (tabRoutes.contains(route)) {
    context.go(route);
  } else {
    context.push(route);
  }
}

class _Action {
  const _Action({
    required this.icon,
    required this.title,
    required this.body,
    required this.route,
  });
  final IconData icon;
  final String title;
  final String body;
  final String route;
}
