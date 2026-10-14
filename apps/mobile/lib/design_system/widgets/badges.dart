import 'package:flutter/material.dart';

import '../tokens.dart';

class AppTag extends StatelessWidget {
  const AppTag({required this.label, this.icon, super.key});
  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Chip(
    avatar: icon == null ? null : Icon(icon, size: 16),
    label: Text(label),
    visualDensity: VisualDensity.compact,
  );
}

class SourceBadge extends StatelessWidget {
  const SourceBadge({required this.label, super.key});
  final String label;

  @override
  Widget build(BuildContext context) =>
      AppTag(label: label, icon: AppIcons.source);
}

class ConfidenceBadge extends StatelessWidget {
  const ConfidenceBadge({
    required this.label,
    required this.requiresVerification,
    super.key,
  });
  final String label;
  final bool requiresVerification;

  @override
  Widget build(BuildContext context) => Semantics(
    label: label,
    child: Chip(
      avatar: Icon(
        requiresVerification
            ? Icons.help_outline_rounded
            : Icons.verified_outlined,
        size: 16,
      ),
      label: Text(label),
      backgroundColor: requiresVerification
          ? Theme.of(context).colorScheme.tertiaryContainer
          : Theme.of(context).colorScheme.secondaryContainer,
    ),
  );
}

class OfflineIndicator extends StatelessWidget {
  const OfflineIndicator({required this.label, super.key});
  final String label;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    label: label,
    excludeSemantics: true,
    child: Material(
      color: Theme.of(context).colorScheme.inverseSurface,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.cloud_off_outlined,
                size: 16,
                color: Theme.of(context).colorScheme.onInverseSurface,
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                label,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onInverseSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
