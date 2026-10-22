import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_routes.dart';
import '../../../core/localization/localization_extension.dart';
import '../../../design_system/tokens.dart';
import '../../../design_system/widgets/cards.dart';
import '../../../design_system/widgets/states.dart';
import '../application/learning_providers.dart';

class LearnHomeScreen extends ConsumerWidget {
  const LearnHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboard = ref.watch(learningDashboardProvider);
    final destinations = [
      (
        Icons.play_lesson_outlined,
        context.l10n.lessons,
        AppRoute.learningLessons.path,
      ),
      (Icons.style_outlined, context.l10n.flashcards, AppRoute.flashcards.path),
      (Icons.quiz_outlined, context.l10n.quizzes, AppRoute.quizSetup.path),
      (Icons.insights_outlined, context.l10n.progress, AppRoute.progress.path),
      (Icons.today_outlined, context.l10n.todayTerm, AppRoute.dailyTerm.path),
      (Icons.first_page_rounded, context.l10n.prefixes, AppRoute.prefixes.path),
      (Icons.account_tree_outlined, context.l10n.roots, AppRoute.roots.path),
      (Icons.last_page_rounded, context.l10n.suffixes, AppRoute.suffixes.path),
      (
        Icons.category_outlined,
        context.l10n.categories,
        AppRoute.categories.path,
      ),
    ];
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.learningHome),
        actions: [
          Padding(
            padding: const EdgeInsetsDirectional.only(end: AppSpacing.md),
            child: _StreakBadge(days: dashboard.valueOrNull?.streak.current),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          dashboard.when(
            loading: () => const AppSkeleton(height: 100),
            error: (error, stackTrace) =>
                AppInlineError(message: context.l10n.startupErrorMessage),
            data: (value) => AppCard(
              onTap: () => context.push(AppRoute.learningLessons.path),
              semanticLabel: context.l10n.continueLearning,
              child: Row(
                children: [
                  const Icon(Icons.play_circle_fill_rounded, size: 44),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.l10n.continueLearning,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        Text(
                          value.dueReviews > 0
                              ? context.l10n.dueReviewCount(value.dueReviews)
                              : context.l10n.continueUnfinishedLesson,
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 820
                  ? 3
                  : constraints.maxWidth >= 480
                  ? 2
                  : 1;
              final width =
                  (constraints.maxWidth - AppSpacing.sm * (columns - 1)) /
                  columns;
              return Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  for (final destination in destinations)
                    SizedBox(
                      width: width,
                      child: AppCard(
                        onTap: () => context.push(destination.$3),
                        semanticLabel: destination.$2,
                        child: Row(
                          children: [
                            Icon(destination.$1),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Text(
                                destination.$2,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                            const Icon(Icons.chevron_right_rounded),
                          ],
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _StreakBadge extends StatelessWidget {
  const _StreakBadge({required this.days});
  final int? days;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final label = days == null
        ? context.l10n.currentStreak
        : '${context.l10n.currentStreak}: ${context.l10n.dayCount(days!)}';
    return Tooltip(
      message: label,
      excludeFromSemantics: true,
      child: TextButton(
        onPressed: () => context.push(AppRoute.progress.path),
        style: TextButton.styleFrom(
          minimumSize: const Size(64, AppDimensions.minTouchTarget),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          backgroundColor: colors.primary.withValues(alpha: 0.07),
          foregroundColor: colors.primary,
          shape: const StadiumBorder(),
        ),
        child: Semantics(
          label: label,
          excludeSemantics: true,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.local_fire_department_rounded,
                size: 28,
                color: colors.primary,
              ),
              const SizedBox(width: AppSpacing.xxs),
              Text(
                days == null
                    ? '–'
                    : MaterialLocalizations.of(context).formatDecimal(days!),
                style: theme.textTheme.titleMedium?.copyWith(
                  color: colors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
