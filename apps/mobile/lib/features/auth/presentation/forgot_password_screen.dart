import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_routes.dart';

import '../../../core/localization/localization_extension.dart';
import '../../../design_system/tokens.dart';
import '../../../design_system/widgets/buttons.dart';
import '../../../design_system/widgets/forms.dart';
import '../../../design_system/widgets/overlays.dart';
import '../../../design_system/widgets/states.dart';
import '../application/auth_controller.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _email = TextEditingController();
  var _loading = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.l10n.forgotPassword)),
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: AppDimensions.formMaxWidth,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppBanner(message: context.l10n.passwordResetInstructions),
              const SizedBox(height: AppSpacing.lg),
              AppInputField(
                controller: _email,
                label: context.l10n.email,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                prefixIcon: Icons.email_outlined,
              ),
              const SizedBox(height: AppSpacing.lg),
              AppPrimaryButton(
                expand: true,
                loading: _loading,
                label: context.l10n.requestReset,
                onPressed: _request,
              ),
              const SizedBox(height: AppSpacing.md),
              TextButton(
                onPressed: () => context.push(AppRoute.resetPassword.path),
                child: Text(context.l10n.enterResetCode),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Future<void> _request() async {
    if (_email.text.trim().isEmpty) return;
    setState(() => _loading = true);
    try {
      await ref
          .read(authRepositoryProvider)
          .requestPasswordReset(_email.text.trim());
      if (mounted) {
        AppOverlays.showMessage(context, context.l10n.resetRequestSent);
      }
    } on Object {
      if (mounted) {
        AppOverlays.showMessage(context, context.l10n.authenticationFailed);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}
