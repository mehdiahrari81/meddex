import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../design_system/tokens.dart';
import '../../../design_system/widgets/buttons.dart';
import '../../../design_system/widgets/states.dart';
import '../application/prescription_workflow_controller.dart';
import '../domain/prescription_providers.dart';

class PrescriptionProcessingScreen extends ConsumerStatefulWidget {
  const PrescriptionProcessingScreen({required this.prescriptionId, super.key});
  final String prescriptionId;

  @override
  ConsumerState<PrescriptionProcessingScreen> createState() =>
      _PrescriptionProcessingScreenState();
}

class _PrescriptionProcessingScreenState
    extends ConsumerState<PrescriptionProcessingScreen> {
  var _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(prescriptionWorkflowControllerProvider.notifier)
          .process(widget.prescriptionId);
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(prescriptionWorkflowControllerProvider, (previous, next) {
      if (next.stage == PrescriptionProcessingStage.reviewRequired &&
          previous?.stage != PrescriptionProcessingStage.reviewRequired) {
        context.go('/prescriptions/${widget.prescriptionId}/ocr-review');
      }
    });
    final workflow = ref.watch(prescriptionWorkflowControllerProvider);
    if (workflow.stage == PrescriptionProcessingStage.failed) {
      return Scaffold(
        appBar: AppBar(
          leading: const AppBackButton(fallbackLocation: '/scan'),
          title: const Text('Scan Error'),
        ),
        body: _ProcessingFailure(
          code: workflow.errorCode,
          onRetry: () => ref
              .read(prescriptionWorkflowControllerProvider.notifier)
              .process(widget.prescriptionId),
          onManual: () =>
              context.go('/prescriptions/${widget.prescriptionId}/manual'),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('OCR Processing'),
        leading: IconButton(
          tooltip: 'Cancel processing',
          onPressed: () {
            ref
                .read(prescriptionWorkflowControllerProvider.notifier)
                .cancelProcessing();
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/scan');
            }
          },
          icon: const Icon(Icons.close_rounded),
        ),
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AppLoadingState(label: _label(workflow.stage)),
          if (workflow.quality.any((result) => !result.acceptable)) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: AppBanner(
                message: _qualityMessage(workflow.quality),
                icon: Icons.photo_camera_back_outlined,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _label(PrescriptionProcessingStage stage) => switch (stage) {
    PrescriptionProcessingStage.checkingQuality => 'Checking image quality…',
    PrescriptionProcessingStage.preprocessing => 'Improving image readability…',
    PrescriptionProcessingStage.readingPrescription => 'Reading prescription…',
    PrescriptionProcessingStage.organizingInformation =>
      'Organizing detected information…',
    _ => 'Preparing secure offline review…',
  };

  String _qualityMessage(List<CaptureQualityResult> values) {
    final issues = values.expand((value) => value.issues).toSet();
    if (issues.contains(CaptureIssue.blur)) {
      return 'Image may be blurry. Compare recognized text carefully or retake the photo.';
    }
    if (issues.contains(CaptureIssue.dark)) {
      return 'Image appears dark. Some text may need manual correction.';
    }
    if (issues.contains(CaptureIssue.bright)) {
      return 'Image appears very bright. Glare may hide prescription text.';
    }
    if (issues.contains(CaptureIssue.cropped)) {
      return 'Some text may be outside the image. Continue only if the complete instruction is visible.';
    }
    return 'Image quality may reduce text recognition. Verification is required.';
  }
}

class _ProcessingFailure extends StatelessWidget {
  const _ProcessingFailure({
    required this.code,
    required this.onRetry,
    required this.onManual,
  });
  final String? code;
  final VoidCallback onRetry;
  final VoidCallback onManual;

  @override
  Widget build(BuildContext context) {
    final noText = code == 'no_text_detected';
    return AppEmptyState(
      icon: noText ? Icons.text_fields_rounded : Icons.error_outline_rounded,
      title: noText
          ? 'No readable text was detected'
          : 'Text recognition failed',
      message: noText
          ? 'Try a clearer photo, improve the crop, choose another image, or enter the medicine manually.'
          : 'The image was kept as a draft. You can retry OCR or continue with manual entry.',
      action: Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: [
          AppPrimaryButton(label: 'Try again', onPressed: onRetry),
          AppSecondaryButton(label: 'Enter manually', onPressed: onManual),
        ],
      ),
    );
  }
}
