import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/localization_extension.dart';
import '../../../design_system/tokens.dart';
import '../../../design_system/widgets/states.dart';
import '../application/terminology_providers.dart';
import '../domain/content_report.dart';

class ContentReportScreen extends ConsumerStatefulWidget {
  const ContentReportScreen({required this.termId, super.key});
  final String termId;

  @override
  ConsumerState<ContentReportScreen> createState() =>
      _ContentReportScreenState();
}

class _ContentReportScreenState extends ConsumerState<ContentReportScreen> {
  final _note = TextEditingController();
  ContentReportReason _reason = ContentReportReason.incorrectDefinition;
  bool _submitting = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.l10n.reportContent)),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            Text(
              context.l10n.reportReason,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.sm),
            RadioGroup<ContentReportReason>(
              groupValue: _reason,
              onChanged: (value) {
                if (!_submitting && value != null) {
                  setState(() => _reason = value);
                }
              },
              child: Column(
                children: [
                  for (final reason in ContentReportReason.values)
                    RadioListTile<ContentReportReason>(
                      value: reason,
                      title: Text(_label(context, reason)),
                      enabled: !_submitting,
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _note,
              enabled: !_submitting,
              maxLength: 1000,
              maxLines: 5,
              decoration: InputDecoration(
                labelText: context.l10n.optionalNote,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            AppBanner(
              message: context.l10n.reportPrivacy,
              icon: Icons.privacy_tip_outlined,
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton.icon(
              onPressed: _submitting ? null : _submit,
              icon: const Icon(Icons.send_outlined),
              label: Text(context.l10n.submitReport),
            ),
          ],
        ),
      ),
    ),
  );

  Future<void> _submit() async {
    setState(() => _submitting = true);
    await ref
        .read(contentReportRepositoryProvider)
        .submit(
          recordId: widget.termId,
          reason: _reason,
          locale: Localizations.localeOf(context).toLanguageTag(),
          appVersion: '1.0.0+1',
          note: _note.text,
        );
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(context.l10n.reportQueued)));
    Navigator.of(context).pop();
  }

  String _label(
    BuildContext context,
    ContentReportReason reason,
  ) => switch (reason) {
    ContentReportReason.incorrectDefinition => context.l10n.incorrectDefinition,
    ContentReportReason.confusingExplanation =>
      context.l10n.confusingExplanation,
    ContentReportReason.pronunciationIssue => context.l10n.pronunciationIssue,
    ContentReportReason.translationIssue => context.l10n.translationIssue,
    ContentReportReason.incorrectRelatedTerm =>
      context.l10n.incorrectRelatedTerm,
    ContentReportReason.other => context.l10n.other,
  };
}
