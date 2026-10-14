import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../design_system/tokens.dart';
import '../../../design_system/widgets/buttons.dart';
import '../../../design_system/widgets/states.dart';
import '../application/prescription_providers.dart';
import '../application/prescription_workflow_controller.dart';
import '../domain/prescription_providers.dart';

class PrescriptionPreviewScreen extends ConsumerStatefulWidget {
  const PrescriptionPreviewScreen({required this.prescriptionId, super.key});
  final String prescriptionId;

  @override
  ConsumerState<PrescriptionPreviewScreen> createState() =>
      _PrescriptionPreviewScreenState();
}

class _PrescriptionPreviewScreenState
    extends ConsumerState<PrescriptionPreviewScreen> {
  var _pageIndex = 0;
  bool _adjusting = false;

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
  Widget build(BuildContext context) {
    final workflow = ref.watch(prescriptionWorkflowControllerProvider);
    final pages = workflow.pages;
    if (workflow.prescription?.id != widget.prescriptionId || pages.isEmpty) {
      return const Scaffold(
        body: AppLoadingState(label: 'Loading private prescription image…'),
      );
    }
    final page = pages[_pageIndex.clamp(0, pages.length - 1)];
    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(fallbackLocation: '/scan'),
        title: Text(
          'Image Preview${pages.length > 1 ? ' · Page ${_pageIndex + 1}' : ''}',
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: InteractiveViewer(
              minScale: .8,
              maxScale: 5,
              child: Center(child: Image.file(File(page.localPath))),
            ),
          ),
          if (pages.length > 1)
            SizedBox(
              height: 86,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.all(AppSpacing.xs),
                itemCount: pages.length,
                itemBuilder: (context, index) => Padding(
                  padding: const EdgeInsetsDirectional.only(end: AppSpacing.xs),
                  child: InkWell(
                    onTap: () => setState(() => _pageIndex = index),
                    child: Semantics(
                      label: 'Review page ${index + 1}',
                      selected: index == _pageIndex,
                      child: Container(
                        width: 64,
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: index == _pageIndex
                                ? Theme.of(context).colorScheme.primary
                                : Colors.transparent,
                            width: 3,
                          ),
                        ),
                        child: Image.file(
                          File(pages[index].localPath),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                children: [
                  const AppBanner(
                    message:
                        'Check that all text is visible. Quality warnings are estimates and do not block you from continuing.',
                    icon: Icons.visibility_outlined,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      AppSecondaryButton(
                        label: 'Crop / adjust',
                        icon: Icons.crop_rounded,
                        onPressed: _adjusting ? null : () => _crop(page),
                      ),
                      AppSecondaryButton(
                        label: 'Rotate',
                        icon: Icons.rotate_right_rounded,
                        onPressed: _adjusting ? null : () => _rotate(page),
                      ),
                      AppSecondaryButton(
                        label: 'Retake',
                        icon: Icons.replay_rounded,
                        onPressed: () => context.pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  AppPrimaryButton(
                    label: 'Use this image',
                    icon: Icons.document_scanner_outlined,
                    expand: true,
                    onPressed: _adjusting
                        ? null
                        : () {
                            context.go(
                              '/prescriptions/${widget.prescriptionId}/processing',
                            );
                          },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _crop(ImageReference page) async {
    setState(() => _adjusting = true);
    try {
      final adjusted = await ref.read(imageAdjustmentProvider).crop(page);
      if (adjusted != null) {
        await ref
            .read(prescriptionWorkflowControllerProvider.notifier)
            .storeAdjustedPage(adjusted);
      }
    } finally {
      if (mounted) setState(() => _adjusting = false);
    }
  }

  Future<void> _rotate(ImageReference page) async {
    setState(() => _adjusting = true);
    try {
      final adjusted = await ref
          .read(imagePreprocessorProvider)
          .rotate(page, 90);
      await ref
          .read(prescriptionWorkflowControllerProvider.notifier)
          .storeAdjustedPage(adjusted);
    } finally {
      if (mounted) setState(() => _adjusting = false);
    }
  }
}
