import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/tts/tts_provider.dart';
import '../../../design_system/tokens.dart';
import '../../../design_system/widgets/buttons.dart';
import '../../../design_system/widgets/states.dart';
import '../../settings/application/settings_controller.dart';
import '../application/prescription_workflow_controller.dart';

class OcrRawTextReviewScreen extends ConsumerStatefulWidget {
  const OcrRawTextReviewScreen({required this.prescriptionId, super.key});
  final String prescriptionId;

  @override
  ConsumerState<OcrRawTextReviewScreen> createState() =>
      _OcrRawTextReviewScreenState();
}

class _OcrRawTextReviewScreenState
    extends ConsumerState<OcrRawTextReviewScreen> {
  TextEditingController? _text;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(prescriptionWorkflowControllerProvider.notifier)
          .loadDraft(widget.prescriptionId);
    });
  }

  @override
  void dispose() {
    _text?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final workflow = ref.watch(prescriptionWorkflowControllerProvider);
    final prescription = workflow.prescription;
    if (prescription?.id != widget.prescriptionId) {
      return const Scaffold(
        body: AppLoadingState(label: 'Loading detected text…'),
      );
    }
    _text ??= TextEditingController(text: prescription!.rawOcrText ?? '');
    final page = workflow.pages.firstOrNull;
    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(fallbackLocation: '/scan'),
        title: const Text('OCR Raw Text Review'),
        actions: [
          IconButton(
            tooltip: 'Read detected prescription',
            onPressed: () async {
              final ttsEnabled =
                  ref
                      .read(settingsControllerProvider)
                      .valueOrNull
                      ?.ttsEnabled ??
                  false;
              if (!ttsEnabled) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Enable text to speech in Settings first.'),
                  ),
                );
                return;
              }
              await ref
                  .read(textToSpeechProvider)
                  .speak(
                    _text!.text,
                    locale: Localizations.localeOf(context).languageCode,
                  );
            },
            icon: const Icon(Icons.volume_up_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          AppSpacing.xxl,
        ),
        children: [
          const AppBanner(
            message:
                'Text recognized from the image is not a confirmed instruction. Handwriting can be especially difficult—compare it carefully or ask a pharmacist if unsure.',
            icon: Icons.fact_check_outlined,
          ),
          if (page != null) ...[
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              height: 260,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadii.medium),
                child: InteractiveViewer(
                  minScale: 1,
                  maxScale: 5,
                  child: Image.file(File(page.localPath), fit: BoxFit.contain),
                ),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Text(
            'Raw detected text',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.xs),
          Directionality(
            textDirection: _hasUrdu(_text!.text)
                ? TextDirection.rtl
                : TextDirection.ltr,
            child: TextField(
              controller: _text,
              minLines: 8,
              maxLines: 18,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Edit obvious OCR text errors',
                helperText:
                    'Numbers are never corrected automatically. Preserve the written dose exactly.',
                alignLabelWithHint: true,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          AppPrimaryButton(
            label: 'Review structured fields',
            icon: Icons.view_list_outlined,
            expand: true,
            onPressed: () async {
              if (_text!.text != (prescription!.rawOcrText ?? '')) {
                await ref
                    .read(prescriptionWorkflowControllerProvider.notifier)
                    .reparseCorrectedText(_text!.text);
              }
              if (context.mounted) {
                context.go('/prescriptions/${widget.prescriptionId}/review');
              }
            },
          ),
          const SizedBox(height: AppSpacing.sm),
          AppSecondaryButton(
            label: 'Unable to read — enter manually',
            icon: Icons.edit_note_rounded,
            expand: true,
            onPressed: () =>
                context.push('/prescriptions/${widget.prescriptionId}/manual'),
          ),
        ],
      ),
    );
  }

  bool _hasUrdu(String value) => RegExp(r'[\u0600-\u06ff]').hasMatch(value);
}
