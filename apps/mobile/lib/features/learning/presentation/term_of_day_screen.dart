import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/localization_extension.dart';
import '../../../design_system/tokens.dart';
import '../../../design_system/widgets/cards.dart';
import '../../../design_system/widgets/states.dart';
import '../../terminology/application/terminology_providers.dart';
import '../../terminology/domain/medical_term.dart';
import '../application/daily_term.dart';

final _dailyTermProvider = FutureProvider<MedicalTerm?>((ref) async {
  final terms = await ref
      .watch(terminologyRepositoryProvider)
      .browseTerms(limit: 100);
  return const DailyTermSelector().select(terms, DateTime.now());
});

class TermOfDayScreen extends ConsumerWidget {
  const TermOfDayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final daily = ref.watch(_dailyTermProvider);
    final saved = ref.watch(savedItemsProvider).valueOrNull ?? const [];
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.termOfTheDay)),
      body: daily.when(
        loading: () => AppLoadingState(label: context.l10n.startupMessage),
        error: (error, stackTrace) => AppFullScreenError(
          title: context.l10n.startupErrorTitle,
          message: context.l10n.startupErrorMessage,
          retryLabel: context.l10n.retry,
          onRetry: () => ref.invalidate(_dailyTermProvider),
        ),
        data: (term) {
          if (term == null) {
            return AppEmptyState(
              title: context.l10n.dailyTermUnavailable,
              message: context.l10n.offlineAvailable,
            );
          }
          final definition = term.definitionFor(
            Localizations.localeOf(context).languageCode,
          );
          final isSaved = saved.any(
            (item) =>
                item.contentId == term.id &&
                item.contentType == MedicalContentType.term,
          );
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              MedicalInformationCard(
                title: term.canonicalTerm,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (definition != null) Text(definition.simple),
                    if (term.morphology.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.md),
                      Wrap(
                        spacing: AppSpacing.xs,
                        children: [
                          for (final part in term.morphology)
                            Chip(
                              label: Text(
                                '${part.surfaceText}: ${part.meaning}',
                              ),
                            ),
                        ],
                      ),
                    ],
                    const SizedBox(height: AppSpacing.md),
                    Wrap(
                      spacing: AppSpacing.sm,
                      children: [
                        FilledButton.icon(
                          onPressed: () => context.push('/terms/${term.id}'),
                          icon: const Icon(Icons.open_in_new_rounded),
                          label: Text(context.l10n.openTerm),
                        ),
                        OutlinedButton.icon(
                          onPressed: () async {
                            final repository = ref.read(
                              savedContentRepositoryProvider,
                            );
                            if (isSaved) {
                              await repository.unsave(
                                term.id,
                                MedicalContentType.term,
                              );
                            } else {
                              await repository.save(
                                term.id,
                                MedicalContentType.term,
                              );
                            }
                          },
                          icon: Icon(
                            isSaved
                                ? Icons.bookmark_rounded
                                : Icons.bookmark_outline_rounded,
                          ),
                          label: Text(
                            isSaved ? context.l10n.unsave : context.l10n.save,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              AppBanner(message: context.l10n.medicalDisclaimerShort),
            ],
          );
        },
      ),
    );
  }
}
