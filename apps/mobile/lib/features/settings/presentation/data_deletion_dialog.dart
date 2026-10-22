import 'package:flutter/material.dart';

import '../../../core/localization/localization_extension.dart';
import '../../../core/logging/app_logger.dart';

Future<bool> showDataDeletionDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String actionLabel,
  required Future<void> Function() onDelete,
}) async =>
    await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _DataDeletionDialog(
        title: title,
        message: message,
        actionLabel: actionLabel,
        onDelete: onDelete,
      ),
    ) ??
    false;

class _DataDeletionDialog extends StatefulWidget {
  const _DataDeletionDialog({
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onDelete,
  });
  final String title;
  final String message;
  final String actionLabel;
  final Future<void> Function() onDelete;
  @override
  State<_DataDeletionDialog> createState() => _DataDeletionDialogState();
}

class _DataDeletionDialogState extends State<_DataDeletionDialog> {
  bool _busy = false;
  bool _failed = false;
  Future<void> _delete() async {
    setState(() {
      _busy = true;
      _failed = false;
    });
    try {
      await widget.onDelete();
      if (mounted) {
        Navigator.pop(context, true);
      }
    } on Object catch (error) {
      AppLogger().log(
        LogLevel.warning,
        'data_deletion_failed',
        fields: {'error_type': error.runtimeType.toString()},
      );
      if (mounted) {
        setState(() {
          _busy = false;
          _failed = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: AlertDialog(
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.message),
            if (_failed) ...[
              const SizedBox(height: 12),
              Text(
                context.l10n.dataDeletionFailed,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context, false),
          child: Text(context.l10n.cancel),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
            foregroundColor: Theme.of(context).colorScheme.onError,
          ),
          onPressed: _busy ? null : _delete,
          child: _busy
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(_failed ? context.l10n.retry : widget.actionLabel),
        ),
      ],
    ),
  );
}
