import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_controller.dart';

Future<bool> requestPrescriptionAiConsent(
  BuildContext context,
  WidgetRef ref,
) async {
  if (ref.read(authControllerProvider).valueOrNull?.status !=
      AuthStatus.authenticated) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Sign in to separate medicines with Gemini. Local review remains available.',
        ),
      ),
    );
    return false;
  }
  return await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Separate medicines with Gemini'),
          content: const Text(
            'Send the complete recognized text to Google Gemini or Groq to separate medicine names '
            'and their written fields, then separate the medicine information? Explanations load only after you confirm the details. '
            'The text may include personal details. Images stay out '
            'of this request. You can review locally to remove details first. '
            'Every medicine name and dose will still need your review.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Review locally'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Use Gemini'),
            ),
          ],
        ),
      ) ??
      false;
}
