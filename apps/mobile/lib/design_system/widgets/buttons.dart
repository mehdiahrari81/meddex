import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../tokens.dart';

class AppBackButton extends StatelessWidget {
  const AppBackButton({this.fallbackLocation = '/home', super.key});

  final String fallbackLocation;

  @override
  Widget build(BuildContext context) => BackButton(
    onPressed: () {
      if (context.canPop()) {
        context.pop();
      } else {
        context.go(fallbackLocation);
      }
    },
  );
}

class AppPrimaryButton extends StatelessWidget {
  const AppPrimaryButton({
    required this.label,
    required this.onPressed,
    this.icon,
    this.loading = false,
    this.expand = false,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool loading;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final child = Semantics(
      button: true,
      label: label,
      child: FilledButton(
        onPressed: loading ? null : onPressed,
        child: loading
            ? const SizedBox.square(
                dimension: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 20),
                    const SizedBox(width: AppSpacing.xs),
                  ],
                  Flexible(child: Text(label)),
                ],
              ),
      ),
    );
    return expand ? SizedBox(width: double.infinity, child: child) : child;
  }
}

class AppSecondaryButton extends StatelessWidget {
  const AppSecondaryButton({
    required this.label,
    required this.onPressed,
    this.icon,
    this.expand = false,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final button = OutlinedButton.icon(
      onPressed: onPressed,
      icon: icon == null ? const SizedBox.shrink() : Icon(icon),
      label: Text(label),
    );
    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}

class AppDestructiveButton extends StatelessWidget {
  const AppDestructiveButton({
    required this.label,
    required this.onPressed,
    super.key,
  });
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => FilledButton(
    style: FilledButton.styleFrom(
      backgroundColor: Theme.of(context).colorScheme.error,
      foregroundColor: Theme.of(context).colorScheme.onError,
    ),
    onPressed: onPressed,
    child: Text(label),
  );
}

class AppIconButton extends StatelessWidget {
  const AppIconButton({
    required this.icon,
    required this.semanticLabel,
    required this.onPressed,
    super.key,
  });
  final IconData icon;
  final String semanticLabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: semanticLabel,
    constraints: const BoxConstraints.tightFor(
      width: AppDimensions.minTouchTarget,
      height: AppDimensions.minTouchTarget,
    ),
    onPressed: onPressed,
    icon: Icon(icon),
  );
}
