import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/localization_extension.dart';
import '../../../design_system/tokens.dart';
import '../../../design_system/widgets/states.dart';
import '../../terminology/application/terminology_providers.dart';
import '../../terminology/domain/medical_term.dart';

enum _SavedSort { recent, alphabetical }

class SavedTerminologyScreen extends ConsumerStatefulWidget {
  const SavedTerminologyScreen({super.key, this.embedded = false});
  final bool embedded;

  @override
  ConsumerState<SavedTerminologyScreen> createState() =>
      _SavedTerminologyScreenState();
}

class _SavedTerminologyScreenState
    extends ConsumerState<SavedTerminologyScreen> {
  String _query = '';
  MedicalContentType? _type;
  _SavedSort _sort = _SavedSort.recent;

  @override
  Widget build(BuildContext context) {
    final saved = ref.watch(savedContentDetailsProvider);
    final body = saved.when(
      loading: () => AppLoadingState(label: context.l10n.startupMessage),
      error: (error, stackTrace) => AppFullScreenError(
        title: context.l10n.startupErrorTitle,
        message: context.l10n.startupErrorMessage,
        retryLabel: context.l10n.retry,
        onRetry: () => ref.invalidate(savedContentDetailsProvider),
      ),
      data: (all) {
        final query = _query.toLowerCase().trim();
        final filtered = all
            .where(
              (value) =>
                  (_type == null || value.item.contentType == _type) &&
                  (query.isEmpty ||
                      value.title.toLowerCase().contains(query) ||
                      value.subtitle.toLowerCase().contains(query)),
            )
            .toList();
        if (_sort == _SavedSort.alphabetical) {
          filtered.sort((a, b) => a.title.compareTo(b.title));
        } else {
          filtered.sort((a, b) => b.item.savedAt.compareTo(a.item.savedAt));
        }
        return ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            SearchBar(
              hintText: context.l10n.searchSaved,
              leading: const Icon(Icons.search_rounded),
              onChanged: (value) => setState(() => _query = value),
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                DropdownButton<MedicalContentType?>(
                  value: _type,
                  onChanged: (value) => setState(() => _type = value),
                  items: [
                    DropdownMenuItem(
                      value: null,
                      child: Text(context.l10n.allCategories),
                    ),
                    for (final type in MedicalContentType.values)
                      DropdownMenuItem(value: type, child: Text(type.name)),
                  ],
                ),
                SegmentedButton<_SavedSort>(
                  segments: [
                    ButtonSegment(
                      value: _SavedSort.recent,
                      label: Text(context.l10n.sortRecentlySaved),
                      icon: const Icon(Icons.schedule_rounded),
                    ),
                    ButtonSegment(
                      value: _SavedSort.alphabetical,
                      label: Text(context.l10n.sortAlphabetically),
                      icon: const Icon(Icons.sort_by_alpha_rounded),
                    ),
                  ],
                  selected: {_sort},
                  onSelectionChanged: (value) =>
                      setState(() => _sort = value.first),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            if (filtered.isEmpty)
              AppEmptyState(
                title: context.l10n.noSavedItems,
                message: context.l10n.noSavedItemsBody,
                icon: Icons.bookmark_border_rounded,
              ),
            for (final value in filtered)
              ListTile(
                leading: Icon(_icon(value.item.contentType)),
                title: Text(value.title),
                subtitle: Text(value.subtitle),
                trailing: IconButton(
                  tooltip: context.l10n.remove,
                  icon: const Icon(Icons.bookmark_remove_outlined),
                  onPressed: () => ref
                      .read(savedContentRepositoryProvider)
                      .unsave(value.item.contentId, value.item.contentType),
                ),
                onTap: value.item.contentType == MedicalContentType.term
                    ? () => context.push('/terms/${value.item.contentId}')
                    : null,
              ),
            const SizedBox(height: AppSpacing.md),
            AppBanner(
              message: context.l10n.offlineAvailable,
              icon: Icons.offline_bolt_outlined,
            ),
          ],
        );
      },
    );
    if (widget.embedded) return body;
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.savedTerminology)),
      body: body,
    );
  }

  IconData _icon(MedicalContentType type) => switch (type) {
    MedicalContentType.term => Icons.menu_book_outlined,
    MedicalContentType.abbreviation => Icons.short_text_rounded,
    MedicalContentType.prefix => Icons.first_page_rounded,
    MedicalContentType.root => Icons.account_tree_outlined,
    MedicalContentType.suffix => Icons.last_page_rounded,
  };
}
