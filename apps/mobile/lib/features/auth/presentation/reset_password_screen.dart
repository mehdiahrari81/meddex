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

class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  ConsumerState<ResetPasswordScreen> createState() =>
      _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _form = GlobalKey<FormState>();
  final _token = TextEditingController();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  var _saving = false;
  String? _error;

  @override
  void dispose() {
    _token.dispose();
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.l10n.resetPasswordTitle)),
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: AppDimensions.formMaxWidth,
          ),
          child: Form(
            key: _form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(context.l10n.resetPasswordDescription),
                const SizedBox(height: AppSpacing.lg),
                AppInputField(
                  controller: _token,
                  label: context.l10n.resetCode,
                  validator: (value) => (value?.trim().length ?? 0) >= 32
                      ? null
                      : context.l10n.resetCodeRequired,
                ),
                const SizedBox(height: AppSpacing.md),
                AppPasswordInput(
                  controller: _password,
                  label: context.l10n.newPassword,
                  validator: (value) =>
                      RegExp(
                        r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[^A-Za-z0-9]).{12,128}$',
                      ).hasMatch(value ?? '')
                      ? null
                      : context.l10n.passwordRequirements,
                ),
                const SizedBox(height: AppSpacing.md),
                AppPasswordInput(
                  controller: _confirmation,
                  label: context.l10n.confirmPassword,
                  validator: (value) => value == _password.text
                      ? null
                      : context.l10n.passwordsDoNotMatch,
                ),
                const SizedBox(height: AppSpacing.lg),
                if (_error != null) ...[
                  AppInlineError(message: _error!),
                  const SizedBox(height: AppSpacing.md),
                ],
                AppPrimaryButton(
                  label: context.l10n.resetPasswordTitle,
                  loading: _saving,
                  onPressed: _save,
                  expand: true,
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(authRepositoryProvider)
          .resetPassword(token: _token.text.trim(), password: _password.text);
      await ref.read(authControllerProvider.notifier).signOut();
      if (mounted) {
        AppOverlays.showMessage(context, context.l10n.passwordResetComplete);
        context.go(AppRoute.auth.path);
      }
    } on Object {
      if (mounted) setState(() => _error = context.l10n.passwordResetFailed);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
