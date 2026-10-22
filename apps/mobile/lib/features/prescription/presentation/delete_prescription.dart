import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/logging/app_logger.dart';
import '../application/prescription_workflow_controller.dart';

String prescriptionCaptureLabel(DateTime capturedAt) =>
    DateFormat.yMMMd().add_jm().format(capturedAt.toLocal());

Future<bool> deletePrescriptionWithConfirmation(
  BuildContext context,
  WidgetRef ref,
  String prescriptionId, {
  DateTime? capturedAt,
}) async {
  final workflow = ref.read(prescriptionWorkflowControllerProvider.notifier);
  final deleted = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _DeletePrescriptionDialog(
      capturedAt: capturedAt,
      onDelete: () => workflow.deletePrescription(prescriptionId),
    ),
  );
  if (deleted == true && context.mounted) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Prescription deleted')));
  }
  return deleted == true;
}

class _DeletePrescriptionDialog extends StatefulWidget {
  const _DeletePrescriptionDialog({required this.onDelete, this.capturedAt});

  final Future<void> Function() onDelete;
  final DateTime? capturedAt;

  @override
  State<_DeletePrescriptionDialog> createState() =>
      _DeletePrescriptionDialogState();
}

class _DeletePrescriptionDialogState extends State<_DeletePrescriptionDialog> {
  bool _deleting = false;
  bool _failed = false;

  Future<void> _delete() async {
    setState(() {
      _deleting = true;
      _failed = false;
    });
    try {
      await widget.onDelete();
      if (mounted) Navigator.pop(context, true);
    } on Object catch (error) {
      // Log the type only: database/file exceptions can contain private data.
      AppLogger().log(
        LogLevel.warning,
        'scan_delete_failed',
        fields: {'error_type': error.runtimeType.toString()},
      );
      if (mounted) {
        setState(() {
          _deleting = false;
          _failed = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_deleting,
    child: AlertDialog(
      title: const Text('Delete prescription?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.capturedAt != null) ...[
            Text(
              'Captured ${prescriptionCaptureLabel(widget.capturedAt!)}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
          ],
          const Text(
            'Remove this scan, its images and medicine review from prescription history? '
            'Other prescriptions and medicines already added to My Medications stay saved.',
          ),
          if (_failed) ...[
            const SizedBox(height: 12),
            Text(
              'Deletion could not finish. Please retry.',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _deleting ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _deleting ? null : _delete,
          child: _deleting
              ? const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 8),
                    Text('Deleting…'),
                  ],
                )
              : Text(_failed ? 'Retry deletion' : 'Delete prescription'),
        ),
      ],
    ),
  );
}
