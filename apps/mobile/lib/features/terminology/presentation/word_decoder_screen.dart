import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/localization_extension.dart';
import '../../../design_system/tokens.dart';
import '../../../design_system/widgets/badges.dart';
import '../../../design_system/widgets/cards.dart';
import '../../../design_system/widgets/states.dart';
import '../application/terminology_providers.dart';
import '../domain/decoder.dart';

class WordDecoderScreen extends ConsumerStatefulWidget {
  const WordDecoderScreen({super.key});

  @override
  ConsumerState<WordDecoderScreen> createState() => _WordDecoderScreenState();
}

class _WordDecoderScreenState extends ConsumerState<WordDecoderScreen> {
  final _controller = TextEditingController();
  Future<WordDecodeResult>? _result;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.l10n.wordDecoder)),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            TextField(
              controller: _controller,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                labelText: context.l10n.decoderHint,
                prefixIcon: const Icon(Icons.account_tree_outlined),
                border: const OutlineInputBorder(),
              ),
              onSubmitted: (_) => _decode(),
            ),
            const SizedBox(height: AppSpacing.sm),
            FilledButton.icon(
              onPressed: _decode,
              icon: const Icon(Icons.schema_outlined),
              label: Text(context.l10n.decode),
            ),
            const SizedBox(height: AppSpacing.lg),
            if (_result != null)
              FutureBuilder<WordDecodeResult>(
                future: _result,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const AppSkeleton(height: 180);
                  }
                  if (snapshot.hasError) {
                    return AppInlineError(
                      message: context.l10n.startupErrorMessage,
                    );
                  }
                  return _DecodeResultView(result: snapshot.requireData);
                },
              ),
            const SizedBox(height: AppSpacing.lg),
            AppBanner(
              message: context.l10n.medicalDisclaimerShort,
              icon: Icons.health_and_safety_outlined,
            ),
          ],
        ),
      ),
    ),
  );

  void _decode() {
    final value = _controller.text.trim();
    if (value.isEmpty) return;
    setState(() {
      _result = ref.read(wordDecoderProvider).decode(value);
    });
  }
}

class _DecodeResultView extends StatelessWidget {
  const _DecodeResultView({required this.result});
  final WordDecodeResult result;

  @override
  Widget build(BuildContext context) {
    if (!result.hasDefensibleBreakdown) {
      return AppEmptyState(
        title: context.l10n.noBreakdown,
        message: context.l10n.noBreakdownBody,
        icon: Icons.help_outline_rounded,
      );
    }
    final definition = result.exactTerm?.definitionFor(
      Localizations.localeOf(context).languageCode,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (result.confidence == DecodeConfidence.partial)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: AppBanner(
              message: context.l10n.partialBreakdown,
              icon: Icons.rule_rounded,
            ),
          ),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final component in result.components)
              ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 150, maxWidth: 220),
                child: AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        component.surfaceText,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(component.meaning),
                      const SizedBox(height: AppSpacing.xs),
                      AppTag(label: component.type.name),
                    ],
                  ),
                ),
              ),
          ],
        ),
        for (final fragment in result.unknownFragments)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: AppBanner(
              message: context.l10n.unknownFragment(fragment.text),
              icon: Icons.help_outline_rounded,
            ),
          ),
        if (definition != null) ...[
          const SizedBox(height: AppSpacing.lg),
          MedicalInformationCard(
            title: result.exactTerm!.canonicalTerm,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(definition.simple),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  context.l10n.decoderDefinitionNote,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: AppSpacing.sm),
                TextButton(
                  onPressed: () =>
                      context.push('/terms/${result.exactTerm!.id}'),
                  child: Text(context.l10n.openTerm),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
