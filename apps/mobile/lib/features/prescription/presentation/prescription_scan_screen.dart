import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_routes.dart';
import '../../../design_system/tokens.dart';
import '../../../design_system/widgets/buttons.dart';
import '../../../design_system/widgets/cards.dart';
import '../../../design_system/widgets/states.dart';
import '../application/prescription_providers.dart';
import '../application/prescription_workflow_controller.dart';

class PrescriptionScanScreen extends ConsumerWidget {
  const PrescriptionScanScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workflow = ref.watch(prescriptionWorkflowControllerProvider);
    final draft = ref.watch(latestPrescriptionDraftProvider);
    final busy =
        workflow.stage != PrescriptionProcessingStage.idle &&
        workflow.stage != PrescriptionProcessingStage.failed &&
        workflow.stage != PrescriptionProcessingStage.reviewRequired;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Prescription'),
        actions: [
          IconButton(
            tooltip: 'Prescription history',
            onPressed: () => context.push(AppRoute.prescriptionHistory.path),
            icon: const Icon(Icons.history_rounded),
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
                'OCR may suggest text. Compare every medicine name and number with the prescription before confirming.',
            icon: Icons.health_and_safety_outlined,
          ),
          const SizedBox(height: AppSpacing.lg),
          draft.when(
            loading: () => const AppSkeleton(height: 74),
            error: (_, _) => const SizedBox.shrink(),
            data: (value) => value == null
                ? const SizedBox.shrink()
                : Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                    child: AppCard(
                      semanticLabel: 'Continue reviewing prescription',
                      onTap: () =>
                          context.push('/prescriptions/${value.id}/review'),
                      child: const Row(
                        children: [
                          Icon(Icons.restore_page_outlined),
                          SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Continue reviewing prescription',
                                  style: TextStyle(fontWeight: FontWeight.w700),
                                ),
                                Text(
                                  'Your field corrections were saved offline.',
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.chevron_right_rounded),
                        ],
                      ),
                    ),
                  ),
          ),
          Text(
            'Choose a capture method',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Keep the whole page inside the frame and avoid glare or shadows.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: AppSpacing.lg),
          _CaptureChoice(
            icon: Icons.camera_alt_outlined,
            title: 'Use camera',
            body:
                'Rear camera with framing, focus, torch, preview, crop and rotate.',
            onTap: busy
                ? null
                : () => context.push(AppRoute.prescriptionCamera.path),
          ),
          const SizedBox(height: AppSpacing.sm),
          _CaptureChoice(
            icon: Icons.document_scanner_outlined,
            title: 'Automatic document scan',
            body:
                'Android: automatic edges, perspective correction, crop and multipage scanning.',
            onTap: busy
                ? null
                : () async {
                    final id = await ref
                        .read(prescriptionWorkflowControllerProvider.notifier)
                        .scanDocument();
                    if (id != null && context.mounted) {
                      context.push('/prescriptions/$id/preview');
                    }
                  },
          ),
          const SizedBox(height: AppSpacing.sm),
          _CaptureChoice(
            icon: Icons.photo_library_outlined,
            title: 'Choose from photos',
            body: 'Import one prescription image from your photo library.',
            onTap: busy
                ? null
                : () async {
                    final id = await ref
                        .read(prescriptionWorkflowControllerProvider.notifier)
                        .importGallery();
                    if (id != null && context.mounted) {
                      context.push('/prescriptions/$id/preview');
                    }
                  },
          ),
          const SizedBox(height: AppSpacing.sm),
          _CaptureChoice(
            icon: Icons.file_open_outlined,
            title: 'Choose image files',
            body:
                'Import JPG, PNG, WebP or HEIC pages. PDF import is not enabled.',
            onTap: busy
                ? null
                : () async {
                    final id = await ref
                        .read(prescriptionWorkflowControllerProvider.notifier)
                        .importFiles();
                    if (id != null && context.mounted) {
                      context.push('/prescriptions/$id/preview');
                    }
                  },
          ),
          const SizedBox(height: AppSpacing.lg),
          AppSecondaryButton(
            label: 'Enter prescription manually',
            icon: Icons.edit_note_rounded,
            expand: true,
            onPressed: busy
                ? null
                : () async {
                    final id = await ref
                        .read(prescriptionWorkflowControllerProvider.notifier)
                        .createManual();
                    if (context.mounted) {
                      context.push('/prescriptions/$id/manual');
                    }
                  },
          ),
          const SizedBox(height: AppSpacing.sm),
          AppSecondaryButton(
            label: 'Scan medicine barcode',
            icon: Icons.qr_code_scanner_rounded,
            expand: true,
            onPressed: () => context.push(AppRoute.barcodeScanner.path),
          ),
          if (busy) ...[
            const SizedBox(height: AppSpacing.lg),
            AppLoadingState(label: _stageLabel(workflow.stage)),
          ],
          if (workflow.stage == PrescriptionProcessingStage.failed) ...[
            const SizedBox(height: AppSpacing.lg),
            AppInlineError(message: _safeError(workflow.errorCode)),
          ],
        ],
      ),
    );
  }

  String _stageLabel(PrescriptionProcessingStage stage) => switch (stage) {
    PrescriptionProcessingStage.importing => 'Importing prescription…',
    PrescriptionProcessingStage.checkingQuality => 'Checking image quality…',
    PrescriptionProcessingStage.preprocessing => 'Improving readability…',
    PrescriptionProcessingStage.readingPrescription => 'Reading prescription…',
    PrescriptionProcessingStage.organizingInformation =>
      'Organizing detected information…',
    _ => 'Preparing prescription…',
  };

  String _safeError(String? code) => switch (code) {
    'document_scan_failed' =>
      'Automatic document scan is unavailable. Use the camera or import an image.',
    'gallery_import_failed' =>
      'The photo could not be imported. Check access and try another image.',
    'file_import_failed' =>
      'The selected file is unsupported or could not be read.',
    _ =>
      'The capture could not be prepared. Your existing drafts were not changed.',
  };
}

class _CaptureChoice extends StatelessWidget {
  const _CaptureChoice({
    required this.icon,
    required this.title,
    required this.body,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String body;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => AppCard(
    onTap: onTap,
    semanticLabel: '$title. $body',
    child: Row(
      children: [
        Icon(icon, size: 32, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: AppSpacing.xxs),
              Text(body),
            ],
          ),
        ),
        const Icon(Icons.chevron_right_rounded),
      ],
    ),
  );
}
