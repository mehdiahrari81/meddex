import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/localization_extension.dart';
import '../../../design_system/tokens.dart';
import '../../../design_system/widgets/cards.dart';
import '../../../design_system/widgets/states.dart';
import '../application/learning_providers.dart';

class ProgressScreen extends ConsumerWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboard = ref.watch(learningDashboardProvider);
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.progress)),
      body: dashboard.when(
        loading: () => AppLoadingState(label: context.l10n.startupMessage),
        error: (error, stackTrace) => AppFullScreenError(
          title: context.l10n.startupErrorTitle,
          message: context.l10n.startupErrorMessage,
          retryLabel: context.l10n.retry,
          onRetry: () => ref.invalidate(learningDashboardProvider),
        ),
        data: (value) {
          final metrics = [
            (
              context.l10n.termsLearned,
              '${value.termsLearned}',
              Icons.menu_book_outlined,
            ),
            (
              context.l10n.lessonsCompleted,
              '${value.lessonsCompleted}',
              Icons.task_alt_outlined,
            ),
            (
              context.l10n.flashcardsReviewed,
              '${value.flashcardsReviewed}',
              Icons.style_outlined,
            ),
            (
              context.l10n.quizAccuracy,
              context.l10n.accuracyPercent((value.quizAccuracy * 100).round()),
              Icons.quiz_outlined,
            ),
            (
              context.l10n.dueReviews,
              '${value.dueReviews}',
              Icons.schedule_outlined,
            ),
            (
              context.l10n.currentStreak,
              context.l10n.dayCount(value.streak.current),
              Icons.local_fire_department_outlined,
            ),
            (
              context.l10n.longestStreak,
              context.l10n.dayCount(value.streak.longest),
              Icons.emoji_events_outlined,
            ),
          ];
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final columns = constraints.maxWidth >= 720 ? 3 : 2;
                  final width =
                      (constraints.maxWidth - AppSpacing.sm * (columns - 1)) /
                      columns;
                  return Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      for (final metric in metrics)
                        SizedBox(
                          width: width,
                          child: AppCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(metric.$3),
                                const SizedBox(height: AppSpacing.md),
                                Text(
                                  metric.$2,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.headlineSmall,
                                ),
                                Text(metric.$1),
                              ],
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
              const SizedBox(height: AppSpacing.lg),
              AppBanner(
                message: value.dueReviews > 0
                    ? context.l10n.dueReviewCount(value.dueReviews)
                    : context.l10n.continueUnfinishedLesson,
                icon: Icons.lightbulb_outline_rounded,
              ),
            ],
          );
        },
      ),
    );
  }
}
