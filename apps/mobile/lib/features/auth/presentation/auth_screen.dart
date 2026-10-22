import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_routes.dart';
import '../../../core/localization/localization_extension.dart';
import '../../../core/errors/app_error.dart';
import '../../../design_system/tokens.dart';
import '../../../design_system/widgets/buttons.dart';
import '../../../design_system/widgets/forms.dart';
import '../../../design_system/widgets/states.dart';
import '../application/auth_controller.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({this.registering = false, this.returnLocation, super.key});
  final bool registering;
  final String? returnLocation;

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    ref.listen(authControllerProvider, (previous, next) {
      if (next.valueOrNull?.status == AuthStatus.authenticated) {
        context.go(widget.returnLocation ?? AppRoute.profile.path);
      }
    });
    final registering = widget.registering;

    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: AutofillGroup(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: AppDimensions.formMaxWidth,
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Icon(
                        Icons.health_and_safety_outlined,
                        size: 52,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        registering
                            ? context.l10n.createAccount
                            : context.l10n.signIn,
                        style: Theme.of(context).textTheme.headlineMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      if (registering) ...[
                        AppInputField(
                          controller: _name,
                          label: context.l10n.displayName,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.name],
                          validator: (value) =>
                              value == null || value.trim().isEmpty
                              ? context.l10n.nameRequired
                              : null,
                          prefixIcon: Icons.person_outline_rounded,
                        ),
                        const SizedBox(height: AppSpacing.md),
                      ],
                      AppInputField(
                        controller: _email,
                        label: context.l10n.email,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.email],
                        prefixIcon: Icons.email_outlined,
                        validator: _validateEmail,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AppPasswordInput(
                        controller: _password,
                        label: context.l10n.password,
                        validator: _validatePassword,
                        onSubmitted: (_) => _submit(),
                      ),
                      if (auth.hasError) ...[
                        const SizedBox(height: AppSpacing.md),
                        AppInlineError(message: _authError(auth.error)),
                      ],
                      if (!registering)
                        Align(
                          alignment: AlignmentDirectional.centerEnd,
                          child: TextButton(
                            onPressed: () =>
                                context.push(AppRoute.forgotPassword.path),
                            child: Text(context.l10n.forgotPassword),
                          ),
                        )
                      else
                        const SizedBox(height: AppSpacing.lg),
                      AppPrimaryButton(
                        expand: true,
                        loading: auth.isLoading,
                        label: registering
                            ? context.l10n.createAccount
                            : context.l10n.signIn,
                        onPressed: _submit,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      AppSecondaryButton(
                        expand: true,
                        label: registering
                            ? context.l10n.signIn
                            : context.l10n.createAccount,
                        onPressed: () => registering
                            ? context.go(AppRoute.auth.path)
                            : context.go(AppRoute.register.path),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      TextButton(
                        onPressed: () async {
                          await ref
                              .read(authControllerProvider.notifier)
                              .continueAsGuest();
                          if (context.mounted) context.go(AppRoute.home.path);
                        },
                        child: Text(context.l10n.continueAsGuest),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return context.l10n.emailRequired;
    }
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value.trim())) {
      return context.l10n.emailInvalid;
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return context.l10n.passwordRequired;
    if (widget.registering &&
        (value.length < 12 ||
            value.length > 128 ||
            !value.contains(RegExp('[A-Z]')) ||
            !value.contains(RegExp('[a-z]')) ||
            !value.contains(RegExp('[0-9]')) ||
            !value.contains(RegExp(r'[^A-Za-z0-9]')))) {
      return context.l10n.passwordRequirements;
    }
    return null;
  }

  String _authError(Object? error) => switch (error) {
    AccountExistsError() => context.l10n.authEmailExists,
    AuthenticationExpiredError() => context.l10n.authInvalidCredentials,
    NetworkUnavailableError() ||
    RequestTimeoutError() => context.l10n.authConnectionFailed,
    RateLimitedError() => context.l10n.authRateLimited,
    _ => context.l10n.authenticationFailed,
  };

  Future<void> _submit() async {
    if (ref.read(authControllerProvider).isLoading) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final controller = ref.read(authControllerProvider.notifier);
    if (widget.registering) {
      await controller.register(_email.text, _password.text, _name.text);
    } else {
      await controller.signIn(_email.text, _password.text);
    }
  }
}
