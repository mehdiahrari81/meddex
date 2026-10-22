import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/localization_extension.dart';
import '../../../design_system/tokens.dart';
import '../../../design_system/widgets/badges.dart';
import '../../../design_system/widgets/cards.dart';
import '../../../design_system/widgets/states.dart';
import '../application/learning_providers.dart';
import '../application/spaced_repetition.dart';
import '../domain/learning_models.dart';

class FlashcardSessionScreen extends ConsumerStatefulWidget {
  const FlashcardSessionScreen({super.key});

  @override
  ConsumerState<FlashcardSessionScreen> createState() =>
      _FlashcardSessionScreenState();
}

class _FlashcardSessionScreenState
    extends ConsumerState<FlashcardSessionScreen> {
  var _index = 0;
  var _revealed = false;
  var _completed = false;
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final cards = ref.watch(dueFlashcardsProvider);
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.flashcards)),
      body: cards.when(
        loading: () => AppLoadingState(label: context.l10n.startupMessage),
        error: (error, stackTrace) => AppFullScreenError(
          title: context.l10n.startupErrorTitle,
          message: context.l10n.startupErrorMessage,
          retryLabel: context.l10n.retry,
          onRetry: () => ref.invalidate(dueFlashcardsProvider),
        ),
        data: (items) {
          if (items.isEmpty) {
            return AppEmptyState(
              title: context.l10n.noFlashcardsDue,
              message: context.l10n.noFlashcardsDueBody,
              icon: Icons.task_alt_rounded,
            );
          }
          if (_completed) {
            return AppEmptyState(
              title: context.l10n.flashcardComplete,
              message: context.l10n.sessionProgress(items.length, items.length),
              icon: Icons.celebration_outlined,
            );
          }
          final card = items[_index.clamp(0, items.length - 1)];
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: [
                  Text(
                    context.l10n.sessionProgress(_index + 1, items.length),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  LinearProgressIndicator(value: (_index + 1) / items.length),
                  const SizedBox(height: AppSpacing.lg),
                  Semantics(
                    label: _revealed
                        ? '${card.front}. ${card.back}'
                        : card.front,
                    child: AppCard(
                      onTap: _revealed
                          ? null
                          : () => setState(() => _revealed = true),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 260),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            AppTag(label: card.type.name),
                            const SizedBox(height: AppSpacing.lg),
                            Text(
                              card.front,
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.headlineMedium,
                            ),
                            if (_revealed) ...[
                              const Divider(height: AppSpacing.xxl),
                              Text(
                                card.back,
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  if (!_revealed)
                    FilledButton(
                      onPressed: () => setState(() => _revealed = true),
                      child: Text(context.l10n.revealAnswer),
                    )
                  else
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: [
                        OutlinedButton(
                          onPressed: _saving
                              ? null
                              : () => _review(card, ReviewPerformance.again),
                          child: Text(context.l10n.again),
                        ),
                        OutlinedButton(
                          onPressed: _saving
                              ? null
                              : () => _review(card, ReviewPerformance.hard),
                          child: Text(context.l10n.unsure),
                        ),
                        FilledButton.tonal(
                          onPressed: _saving
                              ? null
                              : () => _review(card, ReviewPerformance.good),
                          child: Text(context.l10n.knewIt),
                        ),
                        FilledButton(
                          onPressed: _saving
                              ? null
                              : () => _review(card, ReviewPerformance.easy),
                          child: Text(context.l10n.easy),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _review(Flashcard card, ReviewPerformance performance) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final repository = ref.read(learningRepositoryProvider);
      final now = DateTime.now().toUtc();
      final current =
          await repository.flashcardSchedule(card.id) ??
          SpacedRepetitionScheduler().initial(card.id, now);
      final next = const SpacedRepetitionScheduler().review(
        current: current,
        performance: performance,
        reviewedAt: now,
      );
      await repository.saveFlashcardReview(next);
      if (!mounted) return;
      final cards = ref.read(dueFlashcardsProvider).valueOrNull ?? const [];
      setState(() {
        if (_index >= cards.length - 1) {
          _completed = true;
        } else {
          _index += 1;
          _revealed = false;
        }
      });
      ref.invalidate(learningDashboardProvider);
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
