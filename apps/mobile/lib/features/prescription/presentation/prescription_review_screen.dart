import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../design_system/tokens.dart';
import '../../../design_system/widgets/badges.dart';
import '../../../design_system/widgets/buttons.dart';
import '../../../design_system/widgets/cards.dart';
import '../../../design_system/widgets/states.dart';
import '../../../domain/models/confidence_result.dart';
import '../application/prescription_workflow_controller.dart';
import '../domain/prescription_models.dart';

class PrescriptionStructuredReviewScreen extends ConsumerStatefulWidget {
  const PrescriptionStructuredReviewScreen({
    required this.prescriptionId,
    super.key,
  });
  final String prescriptionId;

  @override
  ConsumerState<PrescriptionStructuredReviewScreen> createState() =>
      _PrescriptionStructuredReviewScreenState();
}

class _PrescriptionStructuredReviewScreenState
    extends ConsumerState<PrescriptionStructuredReviewScreen> {
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
    final state = ref.watch(prescriptionWorkflowControllerProvider);
    final prescription = state.prescription;
    if (prescription?.id != widget.prescriptionId) {
      return const Scaffold(
        body: AppLoadingState(label: 'Restoring prescription review…'),
      );
    }
    final unresolved = prescription!.items.where(
      (item) =>
          item.state != PrescriptionItemState.readyForLookup &&
          item.state != PrescriptionItemState.rejected,
    );
    final canConfirm = prescription.items.isNotEmpty && unresolved.isEmpty;
    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(fallbackLocation: '/scan'),
        title: const Text('Prescription Structured Review'),
        actions: [
          IconButton(
            tooltip: 'View raw OCR text',
            onPressed: prescription.rawOcrText == null
                ? null
                : () => context.push(
                    '/prescriptions/${widget.prescriptionId}/ocr-review',
                  ),
            icon: const Icon(Icons.text_snippet_outlined),
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
                'Please confirm that each medicine name and displayed number matches your prescription. This app does not verify the medicine identity yet.',
            icon: Icons.warning_amber_rounded,
          ),
          if (prescription.likelyDuplicateOf != null) ...[
            const SizedBox(height: AppSpacing.sm),
            AppBanner(
              message:
                  'This prescription may already exist. You can keep reviewing this scan or open history to compare.',
              icon: Icons.copy_all_outlined,
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          if (prescription.items.isEmpty)
            AppEmptyState(
              title: 'No medicine entries detected',
              message:
                  'Add a missing medicine manually. The raw image and OCR draft remain available.',
              icon: Icons.playlist_add_rounded,
              action: AppPrimaryButton(
                label: 'Add missing medicine',
                onPressed: () => context.push(
                  '/prescriptions/${widget.prescriptionId}/manual',
                ),
              ),
            )
          else
            for (var index = 0; index < prescription.items.length; index++) ...[
              _MedicationReviewCard(
                number: index + 1,
                item: prescription.items[index],
                imagePath: state.pages
                    .where(
                      (page) =>
                          page.pageNumber ==
                          prescription.items[index].pageNumber,
                    )
                    .firstOrNull
                    ?.localPath,
                onEdit: () => context.push(
                  '/prescriptions/${widget.prescriptionId}/items/${prescription.items[index].id}/edit',
                ),
                onDelete: () => _deleteItem(prescription.items[index].id),
                onConfirmName: () async {
                  final item = prescription.items[index];
                  final name = item.field(PrescriptionFieldType.medicationName);
                  if (name.ambiguous) {
                    await _editItem(item.id);
                    return;
                  }
                  await ref
                      .read(prescriptionWorkflowControllerProvider.notifier)
                      .confirmField(
                        item.id,
                        PrescriptionFieldType.medicationName,
                      );
                },
                onConfirmItem: () => ref
                    .read(prescriptionWorkflowControllerProvider.notifier)
                    .confirmItem(prescription.items[index].id),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
          AppSecondaryButton(
            label: 'Add missing medicine',
            icon: Icons.add_rounded,
            expand: true,
            onPressed: () =>
                context.push('/prescriptions/${widget.prescriptionId}/manual'),
          ),
          const SizedBox(height: AppSpacing.sm),
          AppSecondaryButton(
            label: 'Review unresolved fields (${unresolved.length})',
            icon: Icons.rule_folder_outlined,
            expand: true,
            onPressed: unresolved.isEmpty
                ? null
                : () => context.push(
                    '/prescriptions/${widget.prescriptionId}/unresolved',
                  ),
          ),
          const SizedBox(height: AppSpacing.sm),
          AppSecondaryButton(
            label: 'Save as unresolved',
            icon: Icons.save_outlined,
            expand: true,
            onPressed: () async {
              await ref
                  .read(prescriptionWorkflowControllerProvider.notifier)
                  .saveUnresolved();
              if (context.mounted) context.go('/prescriptions/history');
            },
          ),
          const SizedBox(height: AppSpacing.sm),
          AppPrimaryButton(
            label: 'Review final confirmation',
            icon: Icons.fact_check_outlined,
            expand: true,
            onPressed: canConfirm
                ? () => context.push(
                    '/prescriptions/${widget.prescriptionId}/confirm',
                  )
                : null,
          ),
          if (!canConfirm) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Confirm each retained medicine name before final confirmation. Optional missing fields may remain absent.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _editItem(String itemId) async {
    await context.push(
      '/prescriptions/${widget.prescriptionId}/items/$itemId/edit',
    );
  }

  Future<void> _deleteItem(String itemId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete detected medicine?'),
        content: const Text(
          'This removes the structured item. The original OCR result remains preserved internally.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref
          .read(prescriptionWorkflowControllerProvider.notifier)
          .deleteItem(itemId);
    }
  }
}

class _MedicationReviewCard extends StatelessWidget {
  const _MedicationReviewCard({
    required this.number,
    required this.item,
    required this.imagePath,
    required this.onEdit,
    required this.onDelete,
    required this.onConfirmName,
    required this.onConfirmItem,
  });
  final int number;
  final PrescriptionItem item;
  final String? imagePath;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onConfirmName;
  final VoidCallback onConfirmItem;

  @override
  Widget build(BuildContext context) {
    final name = item.field(PrescriptionFieldType.medicationName);
    final nameConfirmed = name.userConfirmed;
    return AppCard(
      semanticLabel: 'Possible medicine $number. Verification required.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Possible medicine $number',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              ConfidenceBadge(
                label: _stateLabel(item.state),
                requiresVerification:
                    item.state != PrescriptionItemState.readyForLookup,
              ),
              PopupMenuButton<String>(
                tooltip: 'Medicine item actions',
                onSelected: (value) => value == 'edit' ? onEdit() : onDelete(),
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'edit', child: Text('Edit fields')),
                  PopupMenuItem(value: 'delete', child: Text('Delete item')),
                ],
              ),
            ],
          ),
          if (imagePath != null && item.region != null) ...[
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              height: 100,
              width: double.infinity,
              child: Image.file(File(imagePath!), fit: BoxFit.cover),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          _ReviewField(
            title: 'Medicine name',
            field: name,
            numericSafety: false,
          ),
          if (name.machineNormalizedValue != null) ...[
            const SizedBox(height: AppSpacing.xs),
            AppBanner(
              message:
                  'Possible match: ${name.machineNormalizedValue}\nOriginal: ${name.originalValue}',
              icon: Icons.spellcheck_rounded,
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          if (!nameConfirmed)
            AppPrimaryButton(
              label: name.ambiguous
                  ? 'Resolve medicine name'
                  : 'Confirm medicine name',
              icon: Icons.check_circle_outline_rounded,
              onPressed: onConfirmName,
            ),
          const Divider(height: AppSpacing.lg),
          for (final type in PrescriptionFieldType.values.skip(1))
            if (item.fields[type]?.hasValue ?? false) ...[
              _ReviewField(
                title: _fieldLabel(type),
                field: item.fields[type]!,
                numericSafety:
                    type == PrescriptionFieldType.strength ||
                    type == PrescriptionFieldType.dose,
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
          Row(
            children: [
              TextButton.icon(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Edit fields'),
              ),
              const Spacer(),
              AppPrimaryButton(
                label: 'Confirm item',
                onPressed:
                    nameConfirmed &&
                        item.state != PrescriptionItemState.readyForLookup
                    ? onConfirmItem
                    : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _stateLabel(PrescriptionItemState state) => switch (state) {
    PrescriptionItemState.readyForLookup => 'User confirmed',
    PrescriptionItemState.edited => 'Edited · review',
    PrescriptionItemState.unresolved => 'Unresolved',
    _ => 'Review required',
  };

  static String _fieldLabel(PrescriptionFieldType type) => switch (type) {
    PrescriptionFieldType.medicationName => 'Medicine name',
    PrescriptionFieldType.strength => 'Strength',
    PrescriptionFieldType.dosageForm => 'Form',
    PrescriptionFieldType.dose => 'Dose quantity',
    PrescriptionFieldType.route => 'Route',
    PrescriptionFieldType.frequency => 'Frequency',
    PrescriptionFieldType.duration => 'Duration',
    PrescriptionFieldType.instructions => 'Instructions',
  };
}

class _ReviewField extends StatelessWidget {
  const _ReviewField({
    required this.title,
    required this.field,
    required this.numericSafety,
  });
  final String title;
  final ParsedField field;
  final bool numericSafety;

  @override
  Widget build(BuildContext context) => Semantics(
    label:
        '$title. ${field.currentValue ?? 'Unresolved'}. ${field.userConfirmed ? 'Confirmed by user' : 'Needs review'}',
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.labelLarge),
              Text(
                field.currentValue ?? 'Unresolved',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color:
                      numericSafety && field.confidence != ConfidenceBand.high
                      ? Theme.of(context).colorScheme.error
                      : null,
                ),
              ),
              if (field.ambiguous)
                Text(
                  field.possibleMeanings.isEmpty
                      ? 'Meaning is ambiguous'
                      : 'Possible meanings: ${field.possibleMeanings.join(', ')}',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
            ],
          ),
        ),
        ConfidenceBadge(
          label: field.confidence.name,
          requiresVerification: !field.userConfirmed,
        ),
      ],
    ),
  );
}

String prescriptionFieldLabel(PrescriptionFieldType type) =>
    _MedicationReviewCard._fieldLabel(type);
