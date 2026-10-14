import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/tts/tts_provider.dart';
import '../../../core/tts/tts_service.dart';
import '../../../core/voice/voice_provider.dart';
import '../../../core/voice/voice_service.dart';
import '../../../core/errors/app_error.dart';
import '../../../design_system/tokens.dart';
import '../../../design_system/widgets/buttons.dart';
import '../../../design_system/widgets/cards.dart';
import '../../../design_system/widgets/states.dart';
import '../../../domain/models/user.dart';
import '../../settings/application/settings_controller.dart';
import '../application/intelligence_providers.dart';
import '../domain/intelligence_models.dart';
import '../domain/medication_intelligence_repository.dart';

class MedicationSearchScreen extends ConsumerStatefulWidget {
  const MedicationSearchScreen({
    this.initialQuery,
    this.initialStrength,
    this.initialForm,
    this.autoSearch = false,
    this.prescriptionItemId,
    super.key,
  });
  final String? initialQuery;
  final String? initialStrength;
  final String? initialForm;
  final bool autoSearch;
  final String? prescriptionItemId;

  @override
  ConsumerState<MedicationSearchScreen> createState() =>
      _MedicationSearchScreenState();
}

class _MedicationSearchScreenState
    extends ConsumerState<MedicationSearchScreen> {
  final _query = TextEditingController();
  final _strength = TextEditingController();
  final _form = TextEditingController();
  MedicationResolution? _resolution;
  Object? _error;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _query.text = widget.initialQuery ?? '';
    _strength.text = widget.initialStrength ?? '';
    _form.text = widget.initialForm ?? '';
    if (widget.autoSearch) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _search());
    }
  }

  @override
  void dispose() {
    _query.dispose();
    _strength.dispose();
    _form.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _query.text.trim();
    if (query.isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final value = await ref
          .read(medicationIntelligenceRepositoryProvider)
          .search(
            query: query,
            strength: _strength.text.trim().isEmpty
                ? null
                : _strength.text.trim(),
            dosageForm: _form.text.trim().isEmpty ? null : _form.text.trim(),
            country: 'PK',
            prescriptionItemId: widget.prescriptionItemId,
            inputOrigin: widget.prescriptionItemId != null
                ? 'prescription'
                : 'search',
          );
      if (mounted) setState(() => _resolution = value);
    } on Object catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Medicine information')),
    body: ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Text(
          'Search trusted medicine sources',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: AppSpacing.xs),
        const Text(
          'Search by brand, generic name, or active ingredient. Strength and form help distinguish similar products.',
        ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: _query,
          textInputAction: TextInputAction.search,
          decoration: const InputDecoration(
            labelText: 'Medicine name or ingredient',
            prefixIcon: Icon(Icons.medication_outlined),
          ),
          onSubmitted: (_) => _search(),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _strength,
                decoration: const InputDecoration(
                  labelText: 'Strength (optional)',
                  hintText: '500 mg',
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: TextField(
                controller: _form,
                decoration: const InputDecoration(
                  labelText: 'Form (optional)',
                  hintText: 'tablet',
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        AppPrimaryButton(
          label: 'Search medicines',
          icon: Icons.search_rounded,
          loading: _loading,
          expand: true,
          onPressed: _loading ? null : _search,
        ),
        const SizedBox(height: AppSpacing.lg),
        if (_error != null)
          const AppInlineError(
            message:
                'Trusted medicine search is unavailable. No identity was inferred.',
          ),
        if (_resolution != null) _ResolutionResults(resolution: _resolution!),
      ],
    ),
  );
}

class _ResolutionResults extends ConsumerStatefulWidget {
  const _ResolutionResults({required this.resolution});
  final MedicationResolution resolution;

  @override
  ConsumerState<_ResolutionResults> createState() => _ResolutionResultsState();
}

class _ResolutionResultsState extends ConsumerState<_ResolutionResults> {
  String? _confirming;

  @override
  Widget build(BuildContext context) {
    final resolution = widget.resolution;
    if (resolution.state == MedicationResolutionState.noTrustedMatch) {
      return const AppEmptyState(
        title: 'No trusted match',
        message:
            'No trusted medication identity matched. Check the spelling, strength, and form. Nothing was guessed.',
        icon: Icons.manage_search_rounded,
      );
    }
    if (resolution.state == MedicationResolutionState.providerUnavailable &&
        resolution.candidates.isEmpty) {
      return const AppEmptyState(
        title: 'Sources unavailable',
        message:
            'Trusted providers could not be reached. Try again later; no unsupported result is shown.',
        icon: Icons.cloud_off_rounded,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          resolution.candidates.length == 1
              ? 'Confirm this identity'
              : 'Select the exact medicine',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: AppSpacing.xs),
        if (resolution.state == MedicationResolutionState.ambiguous ||
            resolution.state == MedicationResolutionState.userSelectionRequired)
          const AppBanner(
            message:
                'More than one trusted candidate may fit. Compare name, ingredients, strength, form, and country before confirming.',
            icon: Icons.rule_rounded,
          ),
        const SizedBox(height: AppSpacing.sm),
        for (final candidate in resolution.candidates)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: AppCard(
              semanticLabel: 'Medication candidate ${candidate.canonicalName}',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    candidate.canonicalName,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  if (candidate.genericName != null)
                    Text('Generic: ${candidate.genericName}'),
                  if (candidate.strength != null)
                    Text('Strength: ${candidate.strength}'),
                  if (candidate.dosageForm != null)
                    Text('Form: ${candidate.dosageForm}'),
                  Text(
                    'Source: ${_providerLabel(candidate.provider)} ${candidate.providerVersion}'
                    '${candidate.country == null ? '' : ' • ${candidate.country}'}',
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    children: [
                      for (final evidence in candidate.evidence)
                        Chip(
                          avatar: Icon(
                            evidence.matched
                                ? Icons.check_rounded
                                : Icons.info_outline_rounded,
                            size: 16,
                          ),
                          label: Text(
                            '${evidence.signal.replaceAll('_', ' ')}: ${evidence.matched ? 'match' : 'check'}',
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  AppPrimaryButton(
                    label: 'Confirm this medicine',
                    loading: _confirming == candidate.id,
                    onPressed: _confirming != null
                        ? null
                        : () async {
                            setState(() => _confirming = candidate.id);
                            try {
                              final value = await ref
                                  .read(
                                    medicationIntelligenceRepositoryProvider,
                                  )
                                  .confirm(resolution.id, candidate.id);
                              if (context.mounted) {
                                context.push(
                                  '/medicine-information/${value.id}',
                                );
                              }
                            } on Object {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Could not load this medicine’s sources. Check your connection and retry.',
                                    ),
                                  ),
                                );
                              }
                            } finally {
                              if (mounted) setState(() => _confirming = null);
                            }
                          },
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class MedicationDetailScreen extends ConsumerWidget {
  const MedicationDetailScreen({required this.medicationId, super.key});
  final String medicationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(medicationIdentityProvider(medicationId));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Medicine details'),
        actions: [
          IconButton(
            tooltip: 'Ask source-grounded assistant',
            icon: const Icon(Icons.chat_bubble_outline_rounded),
            onPressed: () =>
                context.push('/medicine-information/$medicationId/assistant'),
          ),
        ],
      ),
      body: value.when(
        loading: () => const AppLoadingState(
          label: 'Loading trusted medicine information…',
        ),
        error: (_, _) => AppFullScreenError(
          title: 'Medicine information unavailable',
          message:
              'No current or previously cached trusted information is available.',
          retryLabel: 'Retry',
          onRetry: () =>
              ref.invalidate(medicationIdentityProvider(medicationId)),
        ),
        data: (medicine) => _MedicationDetailBody(medicine: medicine),
      ),
    );
  }
}

class _MedicationDetailBody extends ConsumerWidget {
  const _MedicationDetailBody({required this.medicine});
  final MedicationIdentity medicine;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsControllerProvider).valueOrNull;
    final student = settings?.userMode == UserMode.student;
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        if (medicine.offline || medicine.cacheState != 'current') ...[
          AppBanner(
            message: medicine.offline
                ? 'Offline copy. Source-backed content is shown from the last successful retrieval.'
                : 'Some information is ${medicine.cacheState}. Check each source retrieval date.',
            icon: Icons.cloud_off_outlined,
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        Text(
          medicine.canonicalName,
          style: Theme.of(context).textTheme.headlineSmall,
          textDirection: TextDirection.ltr,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          medicine.verificationState == 'local_registry_match'
              ? 'Pakistan registry identity match'
              : 'Externally verified identity',
        ),
        const SizedBox(height: AppSpacing.md),
        MedicalInformationCard(
          title: 'Medication identity',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (medicine.genericName != null)
                Text('Generic: ${medicine.genericName}'),
              if (medicine.brandNames.isNotEmpty)
                Text('Brand(s): ${medicine.brandNames.join(', ')}'),
              for (final ingredient in medicine.ingredients)
                Text(
                  'Ingredient: ${ingredient.name}'
                  '${ingredient.displayStrength.isEmpty ? '' : ' — ${ingredient.displayStrength}'}',
                ),
              if (medicine.dosageForm != null)
                Text('Form: ${medicine.dosageForm}'),
              if (medicine.country != null)
                Text('Jurisdiction: ${medicine.country}'),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        const AppBanner(
          message:
              'General medicine information is separate from your confirmed prescription and from personal notes.',
          icon: Icons.call_split_rounded,
        ),
        const SizedBox(height: AppSpacing.sm),
        for (final section in _sections(student))
          _FactSection(
            title: section.$1,
            facts: section.$2
                .expand((type) => medicine.factsOf(type))
                .toList(growable: false),
          ),
        if (medicine.facts.isEmpty)
          const AppEmptyState(
            title: 'Identity confirmed; details unavailable',
            message:
                'A trusted identity exists, but no patient or regulatory information was retrieved. No medical facts were generated.',
            icon: Icons.source_outlined,
          ),
        MedicalInformationCard(
          title: 'Interaction checking',
          child: Text(
            medicine.interactionProviderState == 'configured'
                ? 'A validated interaction provider is configured.'
                : 'Interaction checking is not configured. The AI assistant will not invent interactions.',
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: AppSecondaryButton(
                label: 'Save medicine',
                icon: Icons.bookmark_add_outlined,
                onPressed: () async {
                  await ref
                      .read(medicationIntelligenceRepositoryProvider)
                      .setSaved(medicine.id, saved: true);
                  ref.invalidate(savedMedicationIdentitiesProvider);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Medicine saved.')),
                    );
                  }
                },
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: AppSecondaryButton(
                label: 'Report information',
                icon: Icons.flag_outlined,
                onPressed: () =>
                    context.push('/medicine-information/${medicine.id}/report'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  List<(String, List<String>)> _sections(bool student) => [
    ('What this medicine is', ['patient_information']),
    ('Common uses', ['indications']),
    ('Warnings', ['warnings', 'warnings_precautions']),
    ('Contraindications / precautions', ['contraindications']),
    ('Side effects', ['adverse_reactions']),
    ('Storage', ['storage']),
    if (student)
      ('Dosage and administration (official label)', ['dosage_administration']),
  ];
}

class _FactSection extends StatelessWidget {
  const _FactSection({required this.title, required this.facts});
  final String title;
  final List<MedicalFact> facts;

  @override
  Widget build(BuildContext context) {
    if (facts.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: MedicalInformationCard(
        title: title,
        sources: [
          for (final fact in facts)
            ActionChip(
              avatar: const Icon(Icons.verified_outlined, size: 17),
              label: Text(_providerLabel(fact.source.provider)),
              onPressed: () =>
                  context.push('/medicine-sources', extra: fact.source),
            ),
        ],
        child: ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: const Text('Read source-backed information'),
          children: [
            for (final fact in facts)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: SelectableText(fact.content),
              ),
          ],
        ),
      ),
    );
  }
}

class MedicationSourceScreen extends StatelessWidget {
  const MedicationSourceScreen({required this.source, super.key});
  final MedicationSource source;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Official source')),
    body: ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Text(source.title, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: AppSpacing.md),
        _detail('Provider', _providerLabel(source.provider)),
        _detail('Section', source.section),
        _detail('Jurisdiction', source.jurisdiction ?? 'Not specified'),
        _detail('Language', source.language),
        _detail('Content version', source.contentVersion),
        _detail('Retrieved', source.retrievedAt.toLocal().toString()),
        if (source.sourceUpdatedAt != null)
          _detail(
            'Source updated',
            source.sourceUpdatedAt!.toLocal().toString(),
          ),
        const SizedBox(height: AppSpacing.md),
        const Text(
          'Citation URL',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        SelectableText(source.url.toString()),
        const SizedBox(height: AppSpacing.md),
        const AppBanner(
          message:
              'This provenance is supplied by the application from retrieved metadata. It is not an AI-generated citation.',
          icon: Icons.fact_check_outlined,
        ),
      ],
    ),
  );

  Widget _detail(String label, String value) => ListTile(
    contentPadding: EdgeInsets.zero,
    title: Text(label),
    subtitle: Text(value),
  );
}

class MedicationAssistantScreen extends ConsumerStatefulWidget {
  const MedicationAssistantScreen({required this.medicationId, super.key});
  final String medicationId;

  @override
  ConsumerState<MedicationAssistantScreen> createState() =>
      _MedicationAssistantScreenState();
}

class _MedicationAssistantScreenState
    extends ConsumerState<MedicationAssistantScreen> {
  final _question = TextEditingController();
  final _scroll = ScrollController();
  final List<(String, GroundedAnswer?)> _messages = [];
  late final MedicationIntelligenceRepository _repository;
  late final TextToSpeechService _speech;
  late final VoiceInputService _voice;
  bool _loading = false;
  int _requestSequence = 0;
  int? _pendingMessage;

  @override
  void initState() {
    super.initState();
    _repository = ref.read(medicationIntelligenceRepositoryProvider);
    _speech = ref.read(textToSpeechProvider);
    _voice = ref.read(voiceInputProvider);
  }

  @override
  void dispose() {
    _requestSequence++;
    _repository.cancelActiveAnswer();
    _question.dispose();
    _scroll.dispose();
    unawaited(_speech.stop());
    unawaited(_voice.cancel());
    super.dispose();
  }

  void _scrollToLatest() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _scroll.hasClients) {
        unawaited(
          _scroll.animateTo(
            _scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
          ),
        );
      }
    });
  }

  void _stop() {
    _repository.cancelActiveAnswer();
    _requestSequence++;
    final index = _pendingMessage;
    setState(() {
      if (index != null) {
        _messages[index] = (
          _messages[index].$1,
          const GroundedAnswer(
            answer: 'Stopped. You can retry this question or ask another one.',
            answerType: 'safe_fallback',
            groundingStatus: 'cancelled',
            sources: [],
            safetyClassification: 'limited',
            limitations: [],
            suggestions: [],
            language: 'en',
            aiProviderUsed: false,
          ),
        );
      }
      _loading = false;
      _pendingMessage = null;
    });
  }

  Future<void> _listen() async {
    try {
      if (!await _voice.initialize()) {
        throw UnsupportedError('Voice input unavailable');
      }
      if (!mounted) return;
      await _voice.listen(
        locale:
            ref.read(settingsControllerProvider).valueOrNull?.languageCode ??
            'en',
        onResult: (words, finalResult) {
          if (!mounted) return;
          _question.text = words;
          if (finalResult) unawaited(_voice.stop());
        },
      );
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Voice input is unavailable on this device. Type your question instead.',
            ),
          ),
        );
      }
    }
  }

  Future<void> _ask([String? prompt]) async {
    final question = (prompt ?? _question.text).trim();
    if (question.isEmpty || _loading) return;
    final requestSequence = ++_requestSequence;
    final messageIndex = _messages.length;
    setState(() {
      _loading = true;
      _pendingMessage = messageIndex;
      _messages.add((question, null));
      _question.clear();
    });
    _scrollToLatest();
    final settings = ref.read(settingsControllerProvider).valueOrNull;
    try {
      final answer = await _repository.ask(
        question: question,
        medicationId: widget.medicationId,
        mode: settings?.userMode == UserMode.student ? 'student' : 'patient',
        language: settings?.languageCode ?? 'en',
      );
      if (mounted && requestSequence == _requestSequence) {
        setState(() => _messages[messageIndex] = (question, answer));
        _scrollToLatest();
      }
    } on Object catch (error) {
      if (mounted && requestSequence == _requestSequence) {
        final message = switch (error) {
          AuthenticationExpiredError() =>
            'Sign in again to use the source-grounded assistant.',
          NetworkUnavailableError() =>
            'Could not connect. Check your connection and retry this question.',
          RequestTimeoutError() =>
            'The answer took too long. Retry this question in a moment.',
          RateLimitedError() =>
            'Too many requests. Wait a moment, then retry this question.',
          _ =>
            'The source-grounded assistant is unavailable. Retry when the service is available.',
        };
        setState(
          () => _messages[messageIndex] = (
            question,
            GroundedAnswer(
              answer: message,
              answerType: 'safe_fallback',
              groundingStatus: 'provider_unavailable',
              sources: [],
              safetyClassification: 'limited',
              limitations: const [
                'No unsupported medical answer was generated.',
              ],
              suggestions: [],
              language: 'en',
              aiProviderUsed: false,
            ),
          ),
        );
        _scrollToLatest();
      }
    } finally {
      if (mounted && requestSequence == _requestSequence) {
        setState(() {
          _loading = false;
          _pendingMessage = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Source-grounded assistant')),
    body: Column(
      children: [
        const AppBanner(
          message:
              'Answers use referenced sources. AI explanations and original source extracts are labeled separately. This assistant cannot diagnose, prescribe, or change doses.',
          icon: Icons.shield_outlined,
        ),
        Expanded(
          child: ListView(
            controller: _scroll,
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: [
                  for (final prompt in const [
                    'What does this medicine do?',
                    'Explain the warnings simply.',
                    'What side effects are listed?',
                  ])
                    ActionChip(
                      label: Text(prompt),
                      onPressed: _loading ? null : () => _ask(prompt),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              for (final message in _messages) ...[
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      child: Text(message.$1),
                    ),
                  ),
                ),
                if (message.$2 == null)
                  const AppLoadingState(label: 'Checking trusted sources…')
                else
                  _AnswerCard(
                    answer: message.$2!,
                    medicationId: widget.medicationId,
                    onRetry: () => _ask(message.$1),
                    onAsk: _loading ? null : _ask,
                  ),
              ],
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    controller: _question,
                    minLines: 1,
                    maxLines: 4,
                    maxLength: 1000,
                    decoration: const InputDecoration(
                      labelText: 'Ask about sourced information',
                    ),
                    onSubmitted: (_) => _ask(),
                  ),
                ),
                IconButton(
                  tooltip: 'Voice input',
                  onPressed: _listen,
                  icon: const Icon(Icons.mic_none_rounded),
                ),
                IconButton(
                  tooltip: _loading ? 'Stop waiting' : 'Send question',
                  onPressed: _loading ? _stop : _ask,
                  icon: Icon(
                    _loading ? Icons.stop_rounded : Icons.send_rounded,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

class _AnswerCard extends ConsumerWidget {
  const _AnswerCard({
    required this.answer,
    required this.medicationId,
    required this.onRetry,
    required this.onAsk,
  });
  final GroundedAnswer answer;
  final String medicationId;
  final VoidCallback onRetry;
  final void Function(String)? onAsk;

  @override
  Widget build(BuildContext context, WidgetRef ref) => AppCard(
    semanticLabel: 'Assistant response ${answer.groundingStatus}',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: AppSpacing.xs,
          children: [
            Chip(
              label: Text(
                answer.aiProviderUsed
                    ? 'AI explanation'
                    : answer.answerType == 'source_extract'
                    ? 'Original source'
                    : 'No AI answer generated',
              ),
            ),
            Chip(label: Text(answer.groundingStatus.replaceAll('_', ' '))),
          ],
        ),
        SelectableText(answer.answer),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.xs,
          children: [
            for (final source in answer.sources)
              ActionChip(
                label: Text(_providerLabel(source.provider)),
                onPressed: () =>
                    context.push('/medicine-sources', extra: source),
              ),
          ],
        ),
        if (answer.limitations.isNotEmpty)
          ExpansionTile(
            title: const Text('Limits and context'),
            tilePadding: EdgeInsets.zero,
            children: [
              for (final limitation in answer.limitations)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                  child: Text(limitation),
                ),
            ],
          ),
        if (answer.groundingStatus == 'grounded')
          Wrap(
            spacing: AppSpacing.xs,
            children: [
              for (final suggestion in answer.suggestions)
                ActionChip(
                  label: Text(suggestion),
                  onPressed: onAsk == null ? null : () => onAsk!(suggestion),
                ),
            ],
          ),
        Row(
          children: [
            IconButton(
              tooltip: 'Copy answer',
              onPressed: () =>
                  Clipboard.setData(ClipboardData(text: answer.answer)),
              icon: const Icon(Icons.copy_rounded),
            ),
            IconButton(
              tooltip: 'Read answer aloud',
              onPressed: () async {
                try {
                  await ref
                      .read(textToSpeechProvider)
                      .speak(answer.answer, locale: answer.language);
                } on Object {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Read-aloud is unavailable for this language on this device.',
                        ),
                      ),
                    );
                  }
                }
              },
              icon: const Icon(Icons.volume_up_outlined),
            ),
            IconButton(
              tooltip: 'Retry from trusted sources',
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
            ),
            IconButton(
              tooltip: 'Report answer',
              onPressed: () => context.push(
                '/medicine-information/$medicationId/report?type=unsafe_ai',
              ),
              icon: const Icon(Icons.flag_outlined),
            ),
          ],
        ),
      ],
    ),
  );
}

class MedicationReportScreen extends ConsumerStatefulWidget {
  const MedicationReportScreen({
    required this.medicationId,
    this.initialType,
    super.key,
  });
  final String medicationId;
  final String? initialType;

  @override
  ConsumerState<MedicationReportScreen> createState() =>
      _MedicationReportScreenState();
}

class _MedicationReportScreenState
    extends ConsumerState<MedicationReportScreen> {
  final _note = TextEditingController();
  late String _type = widget.initialType ?? 'outdated_information';
  bool _sending = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Report information')),
    body: ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        DropdownButtonFormField<String>(
          initialValue: _type,
          decoration: const InputDecoration(labelText: 'Issue type'),
          items: const [
            DropdownMenuItem(
              value: 'incorrect_medication_match',
              child: Text('Incorrect medication match'),
            ),
            DropdownMenuItem(
              value: 'outdated_information',
              child: Text('Outdated information'),
            ),
            DropdownMenuItem(
              value: 'confusing_explanation',
              child: Text('Confusing explanation'),
            ),
            DropdownMenuItem(
              value: 'unsafe_ai',
              child: Text('Unsafe AI answer'),
            ),
          ],
          onChanged: (value) => setState(() => _type = value ?? _type),
        ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: _note,
          maxLines: 5,
          decoration: const InputDecoration(
            labelText: 'Optional note',
            helperText:
                'The admin queue receives only whether a note was supplied; conversation text is not exposed.',
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        AppPrimaryButton(
          label: 'Submit report',
          loading: _sending,
          onPressed: _sending
              ? null
              : () async {
                  setState(() => _sending = true);
                  await ref
                      .read(medicationIntelligenceRepositoryProvider)
                      .report(
                        type: _type,
                        targetType: _type == 'unsafe_ai'
                            ? 'ai_answer'
                            : 'medication',
                        targetId: widget.medicationId,
                        reason: _type,
                        note: _note.text.trim().isEmpty
                            ? null
                            : _note.text.trim(),
                      );
                  if (context.mounted) context.pop();
                },
        ),
      ],
    ),
  );
}

class SavedMedicineInformationScreen extends ConsumerWidget {
  const SavedMedicineInformationScreen({this.recent = false, super.key});
  final bool recent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final values = ref.watch(
      recent
          ? recentMedicationIdentitiesProvider
          : savedMedicationIdentitiesProvider,
    );
    return Scaffold(
      appBar: AppBar(
        title: Text(recent ? 'Recent medicines' : 'Saved medicines'),
      ),
      body: values.when(
        loading: () => const AppLoadingState(label: 'Loading medicines…'),
        error: (_, _) => const AppEmptyState(
          title: 'Medicines unavailable',
          message: 'No saved offline copies are available.',
        ),
        data: (items) => items.isEmpty
            ? AppEmptyState(
                title: recent ? 'No recent medicines' : 'No saved medicines',
                message:
                    'Verified medicine information you open or save appears here.',
                icon: Icons.medication_outlined,
              )
            : ListView.builder(
                padding: const EdgeInsets.all(AppSpacing.md),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
                  return ListTile(
                    leading: const Icon(Icons.medication_outlined),
                    title: Text(item.canonicalName),
                    subtitle: Text(
                      '${item.genericName ?? 'Generic not specified'} • ${item.cacheState}',
                    ),
                    onTap: () =>
                        context.push('/medicine-information/${item.id}'),
                  );
                },
              ),
      ),
    );
  }
}

String _providerLabel(String provider) => switch (provider) {
  'rxnorm' => 'RxNorm',
  'medlineplus_connect' => 'MedlinePlus',
  'dailymed' => 'DailyMed',
  'drap_dataset' => 'DRAP approved dataset',
  _ => provider,
};
