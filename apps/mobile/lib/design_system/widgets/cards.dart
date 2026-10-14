import 'package:flutter/material.dart';

import '../tokens.dart';

class AppCard extends StatelessWidget {
  const AppCard({
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.md),
    this.onTap,
    this.semanticLabel,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) => Semantics(
    button: onTap != null,
    label: semanticLabel,
    child: Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    ),
  );
}

class MedicalInformationCard extends StatelessWidget {
  const MedicalInformationCard({
    required this.title,
    required this.child,
    this.sources = const [],
    super.key,
  });

  final String title;
  final Widget child;
  final List<Widget> sources;

  @override
  Widget build(BuildContext context) => AppCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        child,
        if (sources.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: sources,
          ),
        ],
      ],
    ),
  );
}

class AppSectionHeading extends StatelessWidget {
  const AppSectionHeading({required this.title, this.trailing, super.key});
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(title, style: Theme.of(context).textTheme.titleLarge),
      ),
      ?trailing,
    ],
  );
}

class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({required this.label, this.radius = 28, super.key});
  final String label;
  final double radius;

  @override
  Widget build(BuildContext context) => Semantics(
    image: true,
    label: label,
    child: CircleAvatar(
      radius: radius,
      child: Text(label.trim().isEmpty ? '?' : label.trim()[0].toUpperCase()),
    ),
  );
}
