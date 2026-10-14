import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_routes.dart';
import '../../../core/localization/localization_extension.dart';
import '../../../design_system/tokens.dart';
import '../../../design_system/widgets/buttons.dart';
import '../../../design_system/widgets/badges.dart';
import '../../../design_system/widgets/cards.dart';
import '../../../design_system/widgets/states.dart';
import '../application/terminology_providers.dart';
import '../domain/search.dart';

class TerminologySearchScreen extends ConsumerStatefulWidget {
  const TerminologySearchScreen({this.initialQuery, super.key});

  final String? initialQuery;

  @override
  ConsumerState<TerminologySearchScreen> createState() =>
      _TerminologySearchScreenState();
}

class _TerminologySearchScreenState
    extends ConsumerState<TerminologySearchScreen> {
  final _controller = TextEditingController();
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final initial = widget.initialQuery?.trim() ?? '';
      if (initial.isNotEmpty) {
        _controller.text = initial;
        ref
            .read(terminologySearchControllerProvider.notifier)
            .searchImmediately(initial);
      } else {
        _focus.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final search = ref.watch(terminologySearchControllerProvider);
    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(),
        title: Text(context.l10n.terminologySearch),
        actions: [
          IconButton(
            tooltip: context.l10n.wordDecoder,
            onPressed: () => context.push(AppRoute.wordDecoder.path),
            icon: const Icon(Icons.account_tree_outlined),
          ),
          IconButton(
            tooltip: context.l10n.abbreviationExplorer,
            onPressed: () => context.push(AppRoute.abbreviations.path),
            icon: const Icon(Icons.short_text_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: SearchBar(
                controller: _controller,
                focusNode: _focus,
                hintText: context.l10n.searchHint,
                leading: const Icon(Icons.search_rounded),
                trailing: [
                  if (_controller.text.isNotEmpty)
                    IconButton(
                      tooltip: context.l10n.clearAll,
                      onPressed: () {
                        _controller.clear();
                        ref
                            .read(terminologySearchControllerProvider.notifier)
                            .queryChanged('');
                        setState(() {});
                      },
                      icon: const Icon(Icons.close_rounded),
                    ),
                ],
                onChanged: (query) {
                  setState(() {});
                  ref
                      .read(terminologySearchControllerProvider.notifier)
                      .queryChanged(query);
                },
                onSubmitted: (query) => ref
                    .read(terminologySearchControllerProvider.notifier)
                    .searchImmediately(query),
              ),
            ),
            Expanded(
              child: _SearchContent(search: search, onQuery: _useQuery),
            ),
          ],
        ),
      ),
    );
  }

  void _useQuery(String query) {
    _controller.text = query;
    _controller.selection = TextSelection.collapsed(offset: query.length);
    ref
        .read(terminologySearchControllerProvider.notifier)
        .searchImmediately(query);
  }
}

class _SearchContent extends ConsumerWidget {
  const _SearchContent({required this.search, required this.onQuery});
  final TerminologySearchState search;
  final ValueChanged<String> onQuery;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (search.query.trim().isEmpty) return _InitialSearch(onQuery: onQuery);
    if (search.searching) {
      return ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: const [
          AppSkeleton(height: 92),
          SizedBox(height: AppSpacing.sm),
          AppSkeleton(height: 92),
          SizedBox(height: AppSpacing.sm),
          AppSkeleton(height: 92),
        ],
      );
    }
    if (search.error != null) {
      return AppFullScreenError(
        title: context.l10n.startupErrorTitle,
        message: context.l10n.startupErrorMessage,
        retryLabel: context.l10n.retry,
        onRetry: () => ref
            .read(terminologySearchControllerProvider.notifier)
            .searchImmediately(search.query),
      );
    }
    final resolution = search.resolution;
    if (resolution == null || resolution.results.isEmpty) {
      return AppEmptyState(
        title: context.l10n.noSearchResults,
        message: context.l10n.noSearchResultsBody,
        icon: Icons.search_off_rounded,
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.xs,
        AppSpacing.md,
        AppSpacing.xxl,
      ),
      children: [
        if (resolution.ambiguous) ...[
          AppBanner(
            message:
                '${context.l10n.multipleMeanings}. ${context.l10n.multipleMeaningsBody}',
            icon: Icons.call_split_rounded,
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        if (resolution.suggestedQuery != null) ...[
          AppBanner(
            message: context.l10n.didYouMean(resolution.suggestedQuery!),
            icon: Icons.spellcheck_rounded,
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        for (final result in resolution.results) ...[
          _ResultCard(
            result: result,
            onOpen: () async {
              await ref
                  .read(searchHistoryRepositoryProvider)
                  .record(
                    resolution.originalQuery,
                    selectedTermId: result.term.id,
                  );
              if (context.mounted) {
                context.push('/terms/${result.term.id}');
              }
            },
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        const SizedBox(height: AppSpacing.md),
        AppBanner(
          message: context.l10n.offlineAvailable,
          icon: Icons.offline_bolt_outlined,
        ),
      ],
    );
  }
}

class _InitialSearch extends ConsumerWidget {
  const _InitialSearch({required this.onQuery});
  final ValueChanged<String> onQuery;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(recentSearchesProvider);
    final common = ref.watch(browseTermsProvider(null));
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        AppEmptyState(
          title: context.l10n.searchStartTitle,
          message: context.l10n.searchStartBody,
          icon: Icons.manage_search_rounded,
        ),
        history.when(
          loading: () => const AppSkeleton(height: 64),
          error: (error, stackTrace) => const SizedBox.shrink(),
          data: (items) => items.isEmpty
              ? const SizedBox.shrink()
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppSectionHeading(
                      title: context.l10n.recentSearches,
                      trailing: TextButton(
                        onPressed: () async {
                          await ref
                              .read(searchHistoryRepositoryProvider)
                              .clear();
                          ref.invalidate(recentSearchesProvider);
                        },
                        child: Text(context.l10n.clearAll),
                      ),
                    ),
                    for (final item in items)
                      ListTile(
                        leading: const Icon(Icons.history_rounded),
                        title: Text(item.query),
                        onTap: () => onQuery(item.query),
                        trailing: IconButton(
                          tooltip: context.l10n.cancel,
                          onPressed: () async {
                            await ref
                                .read(searchHistoryRepositoryProvider)
                                .remove(item.id);
                            ref.invalidate(recentSearchesProvider);
                          },
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ),
                  ],
                ),
        ),
        const SizedBox(height: AppSpacing.lg),
        AppSectionHeading(title: context.l10n.commonTerms),
        const SizedBox(height: AppSpacing.sm),
        common.when(
          loading: () => const AppSkeleton(height: 64),
          error: (error, stackTrace) => const SizedBox.shrink(),
          data: (items) => Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              for (final term in items.take(8))
                ActionChip(
                  label: Text(term.canonicalTerm),
                  onPressed: () => onQuery(term.canonicalTerm),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.result, required this.onOpen});
  final TermSearchResult result;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final definition = result.term.definitionFor(
      Localizations.localeOf(context).languageCode,
    );
    return AppCard(
      semanticLabel: result.term.canonicalTerm,
      onTap: onOpen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  result.term.canonicalTerm,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          if (definition != null) Text(definition.simple),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              AppTag(
                label: result.term.categoryId,
                icon: Icons.category_outlined,
              ),
              AppTag(
                label: context.l10n.matchedAs(result.matchType.name),
                icon: Icons.link_rounded,
              ),
              if (result.matchType == ResolutionType.abbreviation)
                ConfidenceBadge(
                  label: context.l10n.verificationRequired,
                  requiresVerification: true,
                ),
            ],
          ),
        ],
      ),
    );
  }
}
