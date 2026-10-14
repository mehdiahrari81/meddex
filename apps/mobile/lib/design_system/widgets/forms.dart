import 'package:flutter/material.dart';

import '../tokens.dart';

class AppInputField extends StatelessWidget {
  const AppInputField({
    required this.controller,
    required this.label,
    this.hint,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.validator,
    this.onSubmitted,
    this.prefixIcon,
    super.key,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onSubmitted;
  final IconData? prefixIcon;

  @override
  Widget build(BuildContext context) => TextFormField(
    controller: controller,
    keyboardType: keyboardType,
    textInputAction: textInputAction,
    autofillHints: autofillHints,
    validator: validator,
    onFieldSubmitted: onSubmitted,
    decoration: InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: prefixIcon == null ? null : Icon(prefixIcon),
    ),
  );
}

class AppPasswordInput extends StatefulWidget {
  const AppPasswordInput({
    required this.controller,
    required this.label,
    this.validator,
    this.onSubmitted,
    super.key,
  });

  final TextEditingController controller;
  final String label;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onSubmitted;

  @override
  State<AppPasswordInput> createState() => _AppPasswordInputState();
}

class _AppPasswordInputState extends State<AppPasswordInput> {
  var _obscured = true;

  @override
  Widget build(BuildContext context) => TextFormField(
    controller: widget.controller,
    obscureText: _obscured,
    enableSuggestions: false,
    autocorrect: false,
    textInputAction: TextInputAction.done,
    autofillHints: const [AutofillHints.password],
    validator: widget.validator,
    onFieldSubmitted: widget.onSubmitted,
    decoration: InputDecoration(
      labelText: widget.label,
      prefixIcon: const Icon(Icons.lock_outline_rounded),
      suffixIcon: IconButton(
        constraints: const BoxConstraints.tightFor(
          width: AppDimensions.minTouchTarget,
          height: AppDimensions.minTouchTarget,
        ),
        onPressed: () => setState(() => _obscured = !_obscured),
        icon: Icon(
          _obscured ? Icons.visibility_outlined : Icons.visibility_off_outlined,
        ),
      ),
    ),
  );
}

class AppSearchFieldShell extends StatelessWidget {
  const AppSearchFieldShell({
    required this.hint,
    required this.onTap,
    super.key,
  });

  final String hint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    textField: true,
    label: hint,
    child: InkWell(
      borderRadius: BorderRadius.circular(AppRadii.medium),
      onTap: onTap,
      child: InputDecorator(
        decoration: const InputDecoration(
          prefixIcon: Icon(Icons.search_rounded),
        ),
        child: Text(
          hint,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    ),
  );
}
