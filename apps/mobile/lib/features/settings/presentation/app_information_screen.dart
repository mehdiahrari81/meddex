import 'package:flutter/material.dart';

import '../../../core/localization/localization_extension.dart';
import '../../../design_system/tokens.dart';
import '../../../design_system/widgets/cards.dart';

enum AppInformationPage { privacy, terms, sources }

class AppInformationScreen extends StatelessWidget {
  const AppInformationScreen({required this.page, super.key});
  final AppInformationPage page;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final (title, body) = switch (page) {
      AppInformationPage.privacy => (
        l10n.privacyPolicy,
        l10n.privacyPolicyBody,
      ),
      AppInformationPage.terms => (l10n.terms, l10n.termsBody),
      AppInformationPage.sources => (l10n.dataSources, l10n.dataSourcesBody),
    };
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: AppDimensions.contentMaxWidth,
          ),
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              for (final section in body.split('\n\n')) ...[
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        section.split('\n').first,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      SelectableText(section.split('\n').skip(1).join('\n')),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
              ],
              if (page == AppInformationPage.sources)
                for (final source in const [
                  (
                    'NLM RxNorm',
                    'https://www.nlm.nih.gov/research/umls/rxnorm/',
                  ),
                  (
                    'MedlinePlus',
                    'https://medlineplus.gov/druginformation.html',
                  ),
                  ('DailyMed', 'https://dailymed.nlm.nih.gov/dailymed/'),
                ]) ...[
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          source.$1,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        SelectableText(
                          source.$2,
                          semanticsLabel:
                              '${l10n.sourceWebsite}: ${source.$1}. ${source.$2}',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
            ],
          ),
        ),
      ),
    );
  }
}
