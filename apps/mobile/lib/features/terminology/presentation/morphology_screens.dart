import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/localization_extension.dart';
import '../../../design_system/tokens.dart';
import '../../../design_system/widgets/badges.dart';
import '../../../design_system/widgets/cards.dart';
import '../../../design_system/widgets/states.dart';
import '../application/terminology_providers.dart';
import '../domain/medical_term.dart';

class MorphologyLibraryScreen extends ConsumerStatefulWidget {
  const MorphologyLibraryScreen.prefixes({super.key})
    : type = MorphologyType.prefix;
  const MorphologyLibraryScreen.roots({super.key}) : type = MorphologyType.root;
  const MorphologyLibraryScreen.suffixes({super.key})
    : type = MorphologyType.suffix;

  final MorphologyType type;

  @override
  ConsumerState<MorphologyLibraryScreen> createState() =>
      _MorphologyLibraryScreenState();
}

class _MorphologyLibraryScreenState
    extends ConsumerState<MorphologyLibraryScreen> {
  String? _category;

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(morphologyElementsProvider(widget.type));
    final title = switch (widget.type) {
      MorphologyType.prefix => context.l10n.prefixes,
      MorphologyType.root => context.l10n.roots,
      MorphologyType.suffix => context.l10n.suffixes,
    };
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: data.when(
        loading: () => AppLoadingState(label: context.l10n.startupMessage),
        error: (error, stackTrace) => AppFullScreenError(
          title: context.l10n.startupErrorTitle,
          message: context.l10n.startupErrorMessage,
          retryLabel: context.l10n.retry,
          onRetry: () =>
              ref.invalidate(morphologyElementsProvider(widget.type)),
        ),
        data: (all) {
          final categories = all.map((item) => item.category).toSet().toList()
            ..sort();
          final items = _category == null
              ? all
              : all.where((item) => item.category == _category).toList();
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    ChoiceChip(
                      label: Text(context.l10n.allCategories),
                      selected: _category == null,
                      onSelected: (_) => setState(() => _category = null),
                    ),
                    for (final category in categories) ...[
                      const SizedBox(width: AppSpacing.xs),
                      ChoiceChip(
                        label: Text(category),
                        selected: _category == category,
                        onSelected: (_) => setState(() => _category = category),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              for (final item in items) ...[
                _MorphologyItemCard(item: item),
                const SizedBox(height: AppSpacing.sm),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _MorphologyItemCard extends ConsumerWidget {
  const _MorphologyItemCard({required this.item});
  final MorphologyElement item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saved = ref.watch(savedItemsProvider).valueOrNull ?? const [];
    final type = switch (item.type) {
      MorphologyType.prefix => MedicalContentType.prefix,
      MorphologyType.root => MedicalContentType.root,
      MorphologyType.suffix => MedicalContentType.suffix,
    };
    final isSaved = saved.any(
      (entry) => entry.contentId == item.id && entry.contentType == type,
    );
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.value,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              IconButton(
                tooltip: isSaved ? context.l10n.unsave : context.l10n.save,
                onPressed: () async {
                  final repository = ref.read(savedContentRepositoryProvider);
                  if (isSaved) {
                    await repository.unsave(item.id, type);
                  } else {
                    await repository.save(item.id, type);
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
          Text(item.meaning, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: AppSpacing.xs),
          Text(item.explanation),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              AppTag(label: item.category),
              if (item.origin != null)
                AppTag(label: '${context.l10n.origin}: ${item.origin}'),
              for (final example in item.examples.take(3))
                AppTag(label: example),
            ],
          ),
        ],
      ),
    );
  }
}

class AbbreviationExplorerScreen extends ConsumerStatefulWidget {
  const AbbreviationExplorerScreen({super.key});

  @override
  ConsumerState<AbbreviationExplorerScreen> createState() =>
      _AbbreviationExplorerScreenState();
}

class _AbbreviationExplorerScreenState
    extends ConsumerState<AbbreviationExplorerScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(medicalAbbreviationsProvider);
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.abbreviationExplorer)),
      body: data.when(
        loading: () => AppLoadingState(label: context.l10n.startupMessage),
        error: (error, stackTrace) => AppFullScreenError(
          title: context.l10n.startupErrorTitle,
          message: context.l10n.startupErrorMessage,
          retryLabel: context.l10n.retry,
          onRetry: () => ref.invalidate(medicalAbbreviationsProvider),
        ),
        data: (all) {
          final needle = _query.trim().toLowerCase();
          final items = all
              .where(
                (item) =>
                    needle.isEmpty ||
                    item.abbreviation.toLowerCase().contains(needle) ||
                    item.expansion.toLowerCase().contains(needle),
              )
              .toList();
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              AppBanner(
                message: context.l10n.abbreviationSafety,
                icon: Icons.call_split_rounded,
              ),
              const SizedBox(height: AppSpacing.md),
              SearchBar(
                hintText: context.l10n.searchAbbreviations,
                leading: const Icon(Icons.search_rounded),
                onChanged: (value) => setState(() => _query = value),
              ),
              const SizedBox(height: AppSpacing.md),
              if (items.isEmpty)
                AppEmptyState(
                  title: context.l10n.noAbbreviations,
                  message: context.l10n.abbreviationSafety,
                ),
              for (final item in items) ...[
                _AbbreviationCard(item: item),
                const SizedBox(height: AppSpacing.sm),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _AbbreviationCard extends ConsumerWidget {
  const _AbbreviationCard({required this.item});
  final AbbreviationMeaning item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saved = ref.watch(savedItemsProvider).valueOrNull ?? const [];
    final isSaved = saved.any(
      (entry) =>
          entry.contentId == item.id &&
          entry.contentType == MedicalContentType.abbreviation,
    );
    return AppCard(
      onTap: () => context.push('/terms/${item.termId}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${item.abbreviation} — ${item.expansion}',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              IconButton(
                tooltip: isSaved ? context.l10n.unsave : context.l10n.save,
                onPressed: () async {
                  final repository = ref.read(savedContentRepositoryProvider);
                  if (isSaved) {
                    await repository.unsave(
                      item.id,
                      MedicalContentType.abbreviation,
                    );
                  } else {
                    await repository.save(
                      item.id,
                      MedicalContentType.abbreviation,
                    );
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
          Text('${context.l10n.contextLabel}: ${item.context}'),
          const SizedBox(height: AppSpacing.xs),
          AppTag(label: item.category),
          if (item.ambiguous || item.safetyWarning != null) ...[
            const SizedBox(height: AppSpacing.sm),
            AppBanner(
              message: item.safetyWarning ?? context.l10n.abbreviationSafety,
              icon: Icons.warning_amber_rounded,
            ),
          ],
          if (item.alternativeMeanings.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              '${context.l10n.alternativeMeanings}: ${item.alternativeMeanings.join(', ')}',
            ),
          ],
        ],
      ),
    );
  }
}

class CategoryBrowserScreen extends ConsumerStatefulWidget {
  const CategoryBrowserScreen({super.key});

  @override
  ConsumerState<CategoryBrowserScreen> createState() =>
      _CategoryBrowserScreenState();
}

class _CategoryBrowserScreenState extends ConsumerState<CategoryBrowserScreen> {
  String? _selected;

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(medicalCategoriesProvider);
    final terms = ref.watch(browseTermsProvider(_selected));
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.categories)),
      body: categories.when(
        loading: () => AppLoadingState(label: context.l10n.startupMessage),
        error: (error, stackTrace) => AppFullScreenError(
          title: context.l10n.startupErrorTitle,
          message: context.l10n.startupErrorMessage,
          retryLabel: context.l10n.retry,
          onRetry: () => ref.invalidate(medicalCategoriesProvider),
        ),
        data: (items) => ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ChoiceChip(
                    label: Text(context.l10n.allCategories),
                    selected: _selected == null,
                    onSelected: (_) => setState(() => _selected = null),
                  ),
                  for (final item in items) ...[
                    const SizedBox(width: AppSpacing.xs),
                    ChoiceChip(
                      label: Text(item.name),
                      selected: _selected == item.id,
                      onSelected: (_) => setState(() => _selected = item.id),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            AppSectionHeading(title: context.l10n.categoryTerms),
            const SizedBox(height: AppSpacing.sm),
            terms.when(
              loading: () => const AppSkeleton(height: 180),
              error: (error, stackTrace) =>
                  AppInlineError(message: context.l10n.startupErrorMessage),
              data: (values) => Column(
                children: [
                  for (final term in values)
                    ListTile(
                      title: Text(term.canonicalTerm),
                      subtitle: Text(
                        term
                                .definitionFor(
                                  Localizations.localeOf(context).languageCode,
                                )
                                ?.simple ??
                            context.l10n.unknownValue,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => context.push('/terms/${term.id}'),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
