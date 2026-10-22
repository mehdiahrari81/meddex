import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/logging/app_logger.dart';
import '../../../core/sync/sync_provider.dart';
import '../application/medication_deletion.dart';
import '../application/medication_providers.dart';
import '../domain/medication_models.dart';

Future<bool> deleteMedicationWithConfirmation(
  BuildContext context,
  WidgetRef ref,
  MedicationPlanDetails details, {
  bool hideDetails = false,
}) async {
  final repository = ref.read(medicationRepositoryProvider);
  final notifications = ref.read(notificationAdapterProvider);
  final sync = ref.read(syncCoordinatorProvider);
  final deleted = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _DeleteMedicationDialog(
      name: hideDetails ? 'this medication' : details.medication.displayName,
      onDelete: () async {
        final planIds = await repository.medicationPlanIds(
          details.medication.id,
        );
        // A cancellation error leaves records available for a clear retry.
        await cancelMedicationNotifications(notifications, planIds.toSet());
        await repository.deleteMedication(details.medication.id);
        if (context.mounted) {
          for (final id in planIds) {
            ref.invalidate(medicationPlanProvider(id));
          }
          ref.invalidate(medicationActivityProvider);
        }
        unawaited(synchronizeSafely(sync));
      },
    ),
  );
  if (deleted == true && context.mounted) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('Medication and its records deleted')),
      );
  }
  return deleted == true;
}

class _DeleteMedicationDialog extends StatefulWidget {
  const _DeleteMedicationDialog({required this.name, required this.onDelete});
  final String name;
  final Future<void> Function() onDelete;
  @override
  State<_DeleteMedicationDialog> createState() =>
      _DeleteMedicationDialogState();
}

class _DeleteMedicationDialogState extends State<_DeleteMedicationDialog> {
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
      AppLogger().log(
        LogLevel.warning,
        'medication_delete_failed',
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
      title: const Text('Delete medication?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Delete ${widget.name} and all its reminders, taken/skipped history, notes and refill records? This cannot be undone.',
          ),
          const SizedBox(height: 12),
          const Text(
            'Separately saved prescriptions stay in Prescription History. If offline, deletion from a synced backup finishes when you reconnect.',
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
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
            foregroundColor: Theme.of(context).colorScheme.onError,
          ),
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
              : Text(_failed ? 'Retry deletion' : 'Delete medication'),
        ),
      ],
    ),
  );
}
