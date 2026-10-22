import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/localization_extension.dart';
import '../../../design_system/tokens.dart';
import '../../../design_system/widgets/badges.dart';
import '../../../design_system/widgets/cards.dart';
import '../../../design_system/widgets/states.dart';
import '../application/learning_providers.dart';
import '../domain/learning_models.dart';

class LessonListScreen extends ConsumerStatefulWidget {
  const LessonListScreen({super.key});

  @override
  ConsumerState<LessonListScreen> createState() => _LessonListScreenState();
}

class _LessonListScreenState extends ConsumerState<LessonListScreen> {
  LearningDifficulty? _difficulty;

  @override
  Widget build(BuildContext context) {
    final lessons = ref.watch(lessonsProvider);
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.lessonList)),
      body: lessons.when(
        loading: () => AppLoadingState(label: context.l10n.startupMessage),
        error: (error, stackTrace) => AppFullScreenError(
          title: context.l10n.startupErrorTitle,
          message: context.l10n.startupErrorMessage,
          retryLabel: context.l10n.retry,
          onRetry: () => ref.invalidate(lessonsProvider),
        ),
        data: (all) {
          final visible = _difficulty == null
              ? all
              : all
                    .where((lesson) => lesson.difficulty == _difficulty)
                    .toList();
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              Wrap(
                spacing: AppSpacing.xs,
                children: [
                  ChoiceChip(
                    label: Text(context.l10n.allCategories),
                    selected: _difficulty == null,
                    onSelected: (_) => setState(() => _difficulty = null),
                  ),
                  for (final difficulty in LearningDifficulty.values)
                    ChoiceChip(
                      label: Text(_difficultyLabel(context, difficulty)),
                      selected: _difficulty == difficulty,
                      onSelected: (_) =>
                          setState(() => _difficulty = difficulty),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              if (visible.isEmpty)
                AppEmptyState(
                  title: context.l10n.noLessons,
                  message: context.l10n.continueUnfinishedLesson,
                ),
              for (final lesson in visible) ...[
                AppCard(
                  onTap: () => context.push('/learn/lessons/${lesson.id}'),
                  semanticLabel: lesson.title,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        lesson.title,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(lesson.description),
                      const SizedBox(height: AppSpacing.sm),
                      Wrap(
                        spacing: AppSpacing.xs,
                        children: [
                          AppTag(
                            label: _difficultyLabel(context, lesson.difficulty),
                          ),
                          AppTag(
                            label: context.l10n.minutes(
                              lesson.estimatedMinutes,
                            ),
                          ),
                          AppTag(label: lesson.categoryId),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
            ],
          );
        },
      ),
    );
  }
}

class LessonDetailScreen extends ConsumerStatefulWidget {
  const LessonDetailScreen({required this.lessonId, super.key});
  final String lessonId;

  @override
  ConsumerState<LessonDetailScreen> createState() => _LessonDetailScreenState();
}

class _LessonDetailScreenState extends ConsumerState<LessonDetailScreen> {
  late Future<(LearningLesson?, LessonProgress?)> _load;
  int? _index;
  DateTime? _startedAt;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load = _loadLesson();
  }

  Future<(LearningLesson?, LessonProgress?)> _loadLesson() async {
    final repository = ref.read(learningRepositoryProvider);
    final lesson = await repository.lessonById(widget.lessonId);
    final progress = await repository.lessonProgress(widget.lessonId);
    final lastIndex = (lesson?.sections.length ?? 0) - 1;
    _index = lastIndex < 0
        ? 0
        : (progress?.lastSectionIndex ?? 0).clamp(0, lastIndex);
    _startedAt = progress?.startedAt ?? DateTime.now().toUtc();
    return (lesson, progress);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.l10n.lessonSection)),
    body: FutureBuilder<(LearningLesson?, LessonProgress?)>(
      future: _load,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return AppFullScreenError(
            title: context.l10n.startupErrorTitle,
            message: context.l10n.learningLoadFailed,
            retryLabel: context.l10n.retry,
            onRetry: () => setState(() {
              _load = _loadLesson();
            }),
          );
        }
        if (!snapshot.hasData) {
          return AppLoadingState(label: context.l10n.startupMessage);
        }
        final lesson = snapshot.requireData.$1;
        if (lesson == null || lesson.sections.isEmpty) {
          return AppEmptyState(
            title: context.l10n.unknownPageTitle,
            message: context.l10n.unknownPageBody,
          );
        }
        final index = _index!.clamp(0, lesson.sections.length - 1);
        final section = lesson.sections[index];
        final percent = ((index + 1) / lesson.sections.length * 100).round();
        return ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            Text(
              lesson.title,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: AppSpacing.sm),
            LinearProgressIndicator(
              value: (index + 1) / lesson.sections.length,
              semanticsLabel: context.l10n.lessonProgressLabel(percent),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(context.l10n.lessonProgressLabel(percent)),
            const SizedBox(height: AppSpacing.lg),
            MedicalInformationCard(
              title: section.title,
              child: Text(section.content),
            ),
            if (section.linkedTermIds.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.xs,
                children: [
                  for (final id in section.linkedTermIds)
                    ActionChip(
                      label: Text(context.l10n.openTerm),
                      onPressed: () => context.push('/terms/$id'),
                    ),
                ],
              ),
            ],
            const SizedBox(height: AppSpacing.xl),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _saving || index == 0
                        ? null
                        : () => setState(() => _index = index - 1),
                    icon: const Icon(Icons.arrow_back_rounded),
                    label: Text(context.l10n.previous),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _saving ? null : () => _advance(lesson, index),
                    icon: Icon(
                      index == lesson.sections.length - 1
                          ? Icons.check_rounded
                          : Icons.arrow_forward_rounded,
                    ),
                    label: Text(
                      index == lesson.sections.length - 1
                          ? context.l10n.completeLesson
                          : context.l10n.nextSection,
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    ),
  );

  Future<void> _advance(LearningLesson lesson, int index) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final complete = index == lesson.sections.length - 1;
      final now = DateTime.now().toUtc();
      await ref
          .read(learningRepositoryProvider)
          .saveLessonProgress(
            LessonProgress(
              lessonId: lesson.id,
              lastSectionIndex: complete ? index : index + 1,
              completionPercentage: (index + 1) / lesson.sections.length,
              startedAt: _startedAt!,
              updatedAt: now,
              completedAt: complete ? now : null,
              reviewRequired: complete,
            ),
          );
      ref.invalidate(learningDashboardProvider);
      if (!mounted) return;
      if (complete) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.l10n.lessonCompleted)));
        Navigator.of(context).pop();
      } else {
        setState(() => _index = index + 1);
      }
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.learningSaveFailed)),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

String _difficultyLabel(BuildContext context, LearningDifficulty value) =>
    switch (value) {
      LearningDifficulty.beginner => context.l10n.beginner,
      LearningDifficulty.intermediate => context.l10n.intermediate,
      LearningDifficulty.advanced => context.l10n.advanced,
    };
