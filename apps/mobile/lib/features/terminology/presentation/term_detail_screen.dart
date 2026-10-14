import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/localization_extension.dart';
import '../../../core/tts/tts_provider.dart';
import '../../../design_system/tokens.dart';
import '../../../design_system/widgets/badges.dart';
import '../../../design_system/widgets/cards.dart';
import '../../../design_system/widgets/states.dart';
import '../../../domain/models/user.dart';
import '../../settings/application/settings_controller.dart';
import '../application/terminology_providers.dart';
import '../application/term_presentation.dart';
import '../domain/medical_term.dart';

class TermDetailScreen extends ConsumerStatefulWidget {
  const TermDetailScreen({required this.termId, super.key});
  final String termId;

  @override
  ConsumerState<TermDetailScreen> createState() => _TermDetailScreenState();
}

class _TermDetailScreenState extends ConsumerState<TermDetailScreen> {
  var _speaking = false;

  @override
  void dispose() {
    ref.read(textToSpeechProvider).stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final term = ref.watch(medicalTermProvider(widget.termId));
    return Scaffold(
      body: term.when(
        loading: () => AppLoadingState(label: context.l10n.startupMessage),
        error: (error, stackTrace) => AppFullScreenError(
          title: context.l10n.startupErrorTitle,
          message: context.l10n.startupErrorMessage,
          retryLabel: context.l10n.retry,
          onRetry: () => ref.invalidate(medicalTermProvider(widget.termId)),
        ),
        data: (value) => value == null
            ? AppEmptyState(
                title: context.l10n.unknownPageTitle,
                message: context.l10n.unknownPageBody,
              )
            : _TermContent(
                term: value,
                speaking: _speaking,
                onSpeak: () => _toggleSpeak(value),
              ),
      ),
    );
  }

  Future<void> _toggleSpeak(MedicalTerm term) async {
    final service = ref.read(textToSpeechProvider);
    if (_speaking) {
      await service.stop();
      if (mounted) setState(() => _speaking = false);
      return;
    }
    setState(() => _speaking = true);
    try {
      await service.speak(
        term.canonicalTerm,
        locale: Localizations.localeOf(context).languageCode,
      );
    } finally {
      if (mounted) setState(() => _speaking = false);
    }
  }
}

class _TermContent extends ConsumerWidget {
  const _TermContent({
    required this.term,
    required this.speaking,
    required this.onSpeak,
  });
  final MedicalTerm term;
  final bool speaking;
  final VoidCallback onSpeak;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsControllerProvider).valueOrNull;
    final definition = term.definitionFor(
      Localizations.localeOf(context).languageCode,
    );
    final presentation = const BuildTermPresentation()(
      term: term,
      locale: Localizations.localeOf(context).languageCode,
      userMode: settings?.userMode ?? UserMode.patient,
      explanationLevel: settings?.explanationLevel ?? ExplanationLevel.standard,
    );
    final related = ref.watch(relatedTermsProvider(term.id));
    final saved = ref.watch(savedItemsProvider).valueOrNull ?? const [];
    final isSaved = saved.any(
      (item) =>
          item.contentId == term.id &&
          item.contentType == MedicalContentType.term,
    );
    final showTechnical = presentation.showTechnical;
    final showStandard = presentation.showStandard;

    return CustomScrollView(
      slivers: [
        SliverAppBar.large(
          title: Text(term.canonicalTerm),
          actions: [
            IconButton(
              tooltip: isSaved ? context.l10n.unsave : context.l10n.save,
              onPressed: () async {
                final repository = ref.read(savedContentRepositoryProvider);
                if (isSaved) {
                  await repository.unsave(term.id, MedicalContentType.term);
                } else {
                  await repository.save(term.id, MedicalContentType.term);
                }
              },
              icon: Icon(
                isSaved
                    ? Icons.bookmark_rounded
                    : Icons.bookmark_outline_rounded,
              ),
            ),
          ],
        ),
        SliverToBoxAdapter(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 840),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  0,
                  AppSpacing.lg,
                  AppSpacing.xxl,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Wrap(
                      spacing: AppSpacing.xs,
                      runSpacing: AppSpacing.xs,
                      children: [
                        AppTag(
                          label: term.categoryId,
                          icon: Icons.category_outlined,
                        ),
                        AppTag(
                          label: term.pronunciationText ?? term.canonicalTerm,
                          icon: Icons.record_voice_over_outlined,
                        ),
                        AppTag(
                          label: term.reviewStatus.name,
                          icon: Icons.fact_check_outlined,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Semantics(
                      button: true,
                      label: speaking
                          ? context.l10n.stopSpeaking
                          : context.l10n.speak,
                      child: OutlinedButton.icon(
                        onPressed: onSpeak,
                        icon: Icon(
                          speaking
                              ? Icons.stop_rounded
                              : Icons.volume_up_outlined,
                        ),
                        label: Text(
                          speaking
                              ? context.l10n.stopSpeaking
                              : context.l10n.speak,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    if (presentation.prioritizeMorphology &&
                        term.morphology.isNotEmpty) ...[
                      AppSectionHeading(title: context.l10n.wordBreakdown),
                      const SizedBox(height: AppSpacing.sm),
                      Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        children: [
                          for (final component in term.morphology)
                            _MorphologyCard(component: component),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.lg),
                    ],
                    if (definition != null) ...[
                      MedicalInformationCard(
                        title: context.l10n.simpleMeaning,
                        child: Text(
                          definition.simple,
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      ),
                      if (showStandard) ...[
                        const SizedBox(height: AppSpacing.md),
                        MedicalInformationCard(
                          title: context.l10n.standardMeaning,
                          child: Text(definition.standard),
                        ),
                      ],
                      if (showTechnical) ...[
                        const SizedBox(height: AppSpacing.md),
                        MedicalInformationCard(
                          title: context.l10n.technicalDefinition,
                          child: Text(definition.technical),
                        ),
                      ],
                    ],
                    if (!presentation.prioritizeMorphology &&
                        term.morphology.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.lg),
                      AppSectionHeading(title: context.l10n.wordBreakdown),
                      const SizedBox(height: AppSpacing.sm),
                      Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        children: [
                          for (final component in term.morphology)
                            _MorphologyCard(component: component),
                        ],
                      ),
                    ],
                    if (term.layTerms.isNotEmpty)
                      _ListSection(
                        title: context.l10n.commonLanguage,
                        values: term.layTerms,
                      ),
                    if (term.synonyms.isNotEmpty)
                      _ListSection(
                        title: context.l10n.synonyms,
                        values: term.synonyms,
                      ),
                    if (term.examples.isNotEmpty)
                      _ListSection(
                        title: context.l10n.examples,
                        values: term.examples,
                      ),
                    const SizedBox(height: AppSpacing.lg),
                    AppSectionHeading(title: context.l10n.relatedTerms),
                    const SizedBox(height: AppSpacing.sm),
                    related.when(
                      loading: () => const AppSkeleton(height: 56),
                      error: (error, stackTrace) => AppInlineError(
                        message: context.l10n.startupErrorMessage,
                      ),
                      data: (items) => items.isEmpty
                          ? Text(context.l10n.nothingHereYet)
                          : Wrap(
                              spacing: AppSpacing.xs,
                              children: [
                                for (final relatedTerm in items)
                                  ActionChip(
                                    label: Text(relatedTerm.canonicalTerm),
                                    onPressed: () => context.push(
                                      '/terms/${relatedTerm.id}',
                                    ),
                                  ),
                              ],
                            ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    MedicalInformationCard(
                      title: context.l10n.sourceInformation,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final source in term.sources) ...[
                            Text(source.sourceTitle),
                            Text(
                              source.provider,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                          const SizedBox(height: AppSpacing.sm),
                          AppBanner(
                            message: context.l10n.developmentContentNotice,
                            icon: Icons.science_outlined,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextButton.icon(
                      onPressed: () => context.push('/terms/${term.id}/report'),
                      icon: const Icon(Icons.flag_outlined),
                      label: Text(context.l10n.reportContent),
                    ),
                    const SizedBox(height: AppSpacing.md),
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
    );
  }
}

class _MorphologyCard extends StatelessWidget {
  const _MorphologyCard({required this.component});
  final TermMorphologyComponent component;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(minWidth: 150, maxWidth: 240),
    child: AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            component.surfaceText,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(component.meaning),
          const SizedBox(height: AppSpacing.xs),
          AppTag(label: component.type.name),
        ],
      ),
    ),
  );
}

class _ListSection extends StatelessWidget {
  const _ListSection({required this.title, required this.values});
  final String title;
  final List<String> values;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: AppSpacing.lg),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSectionHeading(title: title),
        const SizedBox(height: AppSpacing.sm),
        for (final value in values)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 7),
                  child: Icon(Icons.circle, size: 6),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(child: Text(value)),
              ],
            ),
          ),
      ],
    ),
  );
}
