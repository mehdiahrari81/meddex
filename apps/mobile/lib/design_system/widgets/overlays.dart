import 'package:flutter/material.dart';

import '../tokens.dart';
import 'buttons.dart';

abstract final class AppOverlays {
  static Future<bool> confirm(
    BuildContext context, {
    required String title,
    required String message,
    required String confirmLabel,
    required String cancelLabel,
    bool destructive = false,
  }) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(cancelLabel),
            ),
            if (destructive)
              AppDestructiveButton(
                label: confirmLabel,
                onPressed: () => Navigator.pop(context, true),
              )
            else
              AppPrimaryButton(
                label: confirmLabel,
                onPressed: () => Navigator.pop(context, true),
              ),
          ],
        ),
      ) ??
      false;

  static Future<T?> bottomSheet<T>(
    BuildContext context, {
    required WidgetBuilder builder,
  }) => showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (context) => Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpacing.lg,
      ),
      child: builder(context),
    ),
  );

  static void showMessage(BuildContext context, String message) {
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}
