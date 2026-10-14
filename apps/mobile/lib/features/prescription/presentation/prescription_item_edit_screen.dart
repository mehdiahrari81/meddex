import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../design_system/tokens.dart';
import '../../../design_system/widgets/buttons.dart';
import '../../../design_system/widgets/states.dart';
import '../application/prescription_workflow_controller.dart';
import '../domain/prescription_models.dart';
import 'prescription_review_screen.dart';

class PrescriptionItemEditScreen extends ConsumerStatefulWidget {
  const PrescriptionItemEditScreen({
    required this.prescriptionId,
    required this.itemId,
    super.key,
  });
  final String prescriptionId;
  final String itemId;

  @override
  ConsumerState<PrescriptionItemEditScreen> createState() =>
      _PrescriptionItemEditScreenState();
}

class _PrescriptionItemEditScreenState
    extends ConsumerState<PrescriptionItemEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _controllers = <PrescriptionFieldType, TextEditingController>{};
  bool _ready = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ref
          .read(prescriptionWorkflowControllerProvider.notifier)
          .loadDraft(widget.prescriptionId);
      if (!mounted) return;
      final item = ref
          .read(prescriptionWorkflowControllerProvider)
          .prescription!
          .items
          .firstWhere((value) => value.id == widget.itemId);
      for (final type in PrescriptionFieldType.values) {
        _controllers[type] = TextEditingController(
          text: item.field(type).currentValue ?? '',
        );
      }
      setState(() => _ready = true);
    });
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const Scaffold(
        body: AppLoadingState(label: 'Loading medicine fields…'),
      );
    }
    final item = ref
        .watch(prescriptionWorkflowControllerProvider)
        .prescription!
        .items
        .firstWhere((value) => value.id == widget.itemId);
    return Scaffold(
      appBar: AppBar(title: const Text('Prescription Item Edit')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.md,
            AppSpacing.xxl,
          ),
          children: [
            Text(
              'Original machine text',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            SelectableText(item.sourceText),
            const SizedBox(height: AppSpacing.lg),
            for (final type in PrescriptionFieldType.values) ...[
              TextFormField(
                controller: _controllers[type],
                textDirection: _hasUrdu(_controllers[type]!.text)
                    ? TextDirection.rtl
                    : TextDirection.ltr,
                keyboardType:
                    type == PrescriptionFieldType.strength ||
                        type == PrescriptionFieldType.dose
                    ? TextInputType.text
                    : TextInputType.text,
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  labelText: prescriptionFieldLabel(type),
                  helperText: type == PrescriptionFieldType.medicationName
                      ? 'Required. Compare every letter with the image.'
                      : type == PrescriptionFieldType.strength ||
                            type == PrescriptionFieldType.dose
                      ? 'Preserve every digit and decimal exactly. Optional if absent.'
                      : 'Optional if this was not written on the prescription.',
                ),
                validator: type == PrescriptionFieldType.medicationName
                    ? (value) => value?.trim().isEmpty ?? true
                          ? 'Medicine name is required.'
                          : null
                    : null,
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            AppPrimaryButton(
              label: 'Save corrections',
              loading: _saving,
              expand: true,
              onPressed: _saving ? null : _save,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final notifier = ref.read(
        prescriptionWorkflowControllerProvider.notifier,
      );
      final item = ref
          .read(prescriptionWorkflowControllerProvider)
          .prescription!
          .items
          .firstWhere((value) => value.id == widget.itemId);
      for (final type in PrescriptionFieldType.values) {
        final next = _controllers[type]!.text.trim();
        if (next != (item.field(type).currentValue ?? '')) {
          await notifier.editField(widget.itemId, type, next);
        }
      }
      if (mounted) context.pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  bool _hasUrdu(String value) => RegExp(r'[\u0600-\u06ff]').hasMatch(value);
}

class ManualMedicationEntryScreen extends ConsumerStatefulWidget {
  const ManualMedicationEntryScreen({required this.prescriptionId, super.key});
  final String prescriptionId;

  @override
  ConsumerState<ManualMedicationEntryScreen> createState() =>
      _ManualMedicationEntryScreenState();
}

class _ManualMedicationEntryScreenState
    extends ConsumerState<ManualMedicationEntryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _controllers = {
    for (final type in PrescriptionFieldType.values)
      type: TextEditingController(),
  };
  var _loading = true;
  var _saving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ref
          .read(prescriptionWorkflowControllerProvider.notifier)
          .loadDraft(widget.prescriptionId);
      if (mounted) setState(() => _loading = false);
    });
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: AppLoadingState(label: 'Preparing manual entry…'),
      );
    }
    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(fallbackLocation: '/scan'),
        title: const Text('Manual Medication Entry'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.md,
            AppSpacing.xxl,
          ),
          children: [
            const AppBanner(
              message:
                  'Manual entries are marked as user-entered and still require medication identity lookup in Module 4.',
              icon: Icons.edit_note_rounded,
            ),
            const SizedBox(height: AppSpacing.lg),
            for (final type in PrescriptionFieldType.values) ...[
              TextFormField(
                controller: _controllers[type],
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  labelText: prescriptionFieldLabel(type),
                  helperText: type == PrescriptionFieldType.medicationName
                      ? 'Required; enter exactly what is written.'
                      : 'Optional if absent.',
                ),
                validator: type == PrescriptionFieldType.medicationName
                    ? (value) => value?.trim().isEmpty ?? true
                          ? 'Medicine name is required.'
                          : null
                    : null,
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            AppPrimaryButton(
              label: 'Add medicine for review',
              icon: Icons.add_rounded,
              loading: _saving,
              expand: true,
              onPressed: _saving ? null : _save,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(prescriptionWorkflowControllerProvider.notifier)
          .addManualItem({
            for (final entry in _controllers.entries)
              entry.key: entry.value.text.trim(),
          });
      if (mounted) {
        context.go('/prescriptions/${widget.prescriptionId}/review');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
