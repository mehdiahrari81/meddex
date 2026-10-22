import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../design_system/tokens.dart';
import '../../../design_system/widgets/buttons.dart';
import '../../../design_system/widgets/cards.dart';
import '../../../design_system/widgets/states.dart';
import '../application/prescription_workflow_controller.dart';
import '../domain/prescription_models.dart';
import 'delete_prescription.dart';
import 'prescription_field_display.dart';

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
    final retained = prescription!.items
        .where((item) => item.state != PrescriptionItemState.rejected)
        .toList(growable: false);
    final unresolved = retained.where(
      (item) =>
          !item.field(PrescriptionFieldType.medicationName).hasValue ||
          item.fields.values.any(prescriptionFieldNeedsCheck),
    );
    final canConfirm = retained.isNotEmpty && unresolved.isEmpty;
    final confirmedCount = retained
        .where((item) => item.state == PrescriptionItemState.readyForLookup)
        .length;
    final allConfirmed = canConfirm && confirmedCount == retained.length;
    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(fallbackLocation: '/scan'),
        title: const Text('Your medicines'),
        actions: [
          IconButton(
            tooltip: 'Delete prescription',
            onPressed: () async {
              if (await deletePrescriptionWithConfirmation(
                    context,
                    ref,
                    widget.prescriptionId,
                  ) &&
                  context.mounted) {
                context.go('/scan');
              }
            },
            icon: const Icon(Icons.delete_outline_rounded),
          ),
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
                'Check the medicine details against your prescription. Explanations describe the reference medicine; they do not confirm what was prescribed.',
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
          const SizedBox(height: AppSpacing.md),
          Text(
            '$confirmedCount of ${retained.length} medicines confirmed',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: AppSpacing.lg),
          if (retained.isEmpty)
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
            for (var index = 0; index < retained.length; index++) ...[
              _MedicationReviewCard(
                key: ValueKey(retained[index].id),
                number: index + 1,
                item: retained[index],
                imagePath: state.pages
                    .where(
                      (page) => page.pageNumber == retained[index].pageNumber,
                    )
                    .firstOrNull
                    ?.localPath,
                onEdit: () => context.push(
                  '/prescriptions/${widget.prescriptionId}/items/${retained[index].id}/edit',
                ),
                onDelete: () => _deleteItem(retained[index].id),
                onConfirmItem: () async {
                  final item = retained[index];
                  final notifier = ref.read(
                    prescriptionWorkflowControllerProvider.notifier,
                  );
                  try {
                    await notifier.confirmReviewedItem(item.id);
                  } on Object {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Use Check to correct unreadable details, then confirm again.',
                          ),
                        ),
                      );
                    }
                  }
                },
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
              if (context.mounted) {
                context.go('/prescriptions/history');
              }
            },
          ),
          const SizedBox(height: AppSpacing.sm),
          AppSecondaryButton(
            label: 'Delete prescription',
            icon: Icons.delete_outline_rounded,
            expand: true,
            onPressed: () async {
              if (await deletePrescriptionWithConfirmation(
                    context,
                    ref,
                    widget.prescriptionId,
                  ) &&
                  context.mounted) {
                context.go('/scan');
              }
            },
          ),
          const SizedBox(height: AppSpacing.sm),
          AppPrimaryButton(
            label: 'Add to My Medications',
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
              'Check or correct the unclear details before adding. Fields not written on the prescription may stay empty.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          AppPrimaryButton(
            label: 'Explain medicines',
            icon: Icons.auto_awesome_outlined,
            expand: true,
            onPressed: allConfirmed
                ? () => context.push(
                    '/prescriptions/${widget.prescriptionId}/explanations',
                  )
                : null,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Confirm all medicines, then tap Explain medicines.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
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
    if (confirmed == true && mounted) {
      try {
        await ref
            .read(prescriptionWorkflowControllerProvider.notifier)
            .deleteItem(itemId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Medicine removed from prescription')),
          );
        }
      } on Object {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not remove the medicine. Please retry.'),
            ),
          );
        }
      }
    }
  }
}

class _MedicationReviewCard extends StatefulWidget {
  const _MedicationReviewCard({
    required this.number,
    required this.item,
    required this.imagePath,
    required this.onEdit,
    required this.onDelete,
    required this.onConfirmItem,
    super.key,
  });
  final int number;
  final PrescriptionItem item;
  final String? imagePath;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final Future<void> Function() onConfirmItem;

  @override
  State<_MedicationReviewCard> createState() => _MedicationReviewCardState();
}

class _MedicationReviewCardState extends State<_MedicationReviewCard> {
  bool _confirming = false;

  Future<void> _confirm() async {
    if (_confirming) return;
    setState(() => _confirming = true);
    try {
      await widget.onConfirmItem();
    } finally {
      if (mounted) setState(() => _confirming = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final number = widget.number;
    final imagePath = widget.imagePath;
    final onEdit = widget.onEdit;
    final onDelete = widget.onDelete;
    final confirmed = item.state == PrescriptionItemState.readyForLookup;
    return AppCard(
      semanticLabel:
          'Medicine $number. ${confirmed ? 'Details checked by you.' : 'Check against your prescription.'}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Medicine $number',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Text(
                      confirmed
                          ? 'Details checked by you'
                          : 'Check against prescription',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'Medicine item actions',
                enabled: !_confirming,
                onSelected: (value) => value == 'edit' ? onEdit() : onDelete(),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('Edit fields')),
                  PopupMenuItem(value: 'delete', child: Text('Delete item')),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          for (final type in const [
            PrescriptionFieldType.medicationName,
            PrescriptionFieldType.strength,
            PrescriptionFieldType.dosageForm,
            PrescriptionFieldType.dose,
            PrescriptionFieldType.frequency,
          ]) ...[
            _ReviewField(title: _fieldLabel(type), field: item.field(type)),
            const SizedBox(height: AppSpacing.sm),
          ],
          for (final type in const [
            PrescriptionFieldType.route,
            PrescriptionFieldType.duration,
            PrescriptionFieldType.instructions,
          ])
            if (item.field(type).hasValue) ...[
              _ReviewField(title: _fieldLabel(type), field: item.field(type)),
              const SizedBox(height: AppSpacing.sm),
            ],
          const Divider(height: AppSpacing.lg),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: const Text('Text from prescription'),
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: SelectableText(item.sourceText),
              ),
              if (imagePath != null)
                SizedBox(
                  height: 180,
                  child: Image.file(File(imagePath), fit: BoxFit.contain),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              AppSecondaryButton(
                label: 'Check',
                icon: Icons.edit_outlined,
                onPressed: _confirming ? null : onEdit,
              ),
              Semantics(
                checked: confirmed,
                label: confirmed
                    ? 'Medicine confirmed'
                    : 'Confirm medicine details',
                child: FilledButton(
                  key: ValueKey('confirm-${item.id}'),
                  onPressed: confirmed || _confirming ? null : _confirm,
                  style: confirmed
                      ? FilledButton.styleFrom(
                          disabledBackgroundColor: Theme.of(
                            context,
                          ).colorScheme.primaryContainer,
                          disabledForegroundColor: Theme.of(
                            context,
                          ).colorScheme.onPrimaryContainer,
                        )
                      : null,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_confirming) ...[
                        const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                      ] else if (confirmed) ...[
                        const Icon(Icons.check_circle_rounded, size: 20),
                        const SizedBox(width: AppSpacing.xs),
                      ],
                      const Flexible(child: Text('Confirm')),
                    ],
                  ),
                ),
              ),
            ],
          ),
          TextButton.icon(
            onPressed: _confirming ? null : onDelete,
            icon: const Icon(Icons.delete_outline_rounded),
            label: const Text('Remove medicine'),
          ),
        ],
      ),
    );
  }

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
  const _ReviewField({required this.title, required this.field});
  final String title;
  final ParsedField field;

  @override
  Widget build(BuildContext context) {
    final needsCheck = prescriptionFieldNeedsCheck(field);
    final value = prescriptionFieldValue(field);
    final explainedFrequency =
        field.type == PrescriptionFieldType.frequency &&
        prescriptionFrequencyMeaning(field.currentValue ?? '') != null;
    final showAsError = needsCheck && !explainedFrequency;
    return Semantics(
      label:
          '$title. $value. ${needsCheck ? 'Check against prescription.' : ''}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.labelLarge),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: showAsError ? Theme.of(context).colorScheme.error : null,
            ),
          ),
          if (needsCheck)
            Text(
              prescriptionFieldCheckMessage(field, title),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: showAsError
                    ? Theme.of(context).colorScheme.error
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }
}

String prescriptionFieldLabel(PrescriptionFieldType type) =>
    _MedicationReviewCardState._fieldLabel(type);
