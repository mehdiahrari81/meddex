import 'package:flutter/material.dart';

import '../tokens.dart';

class SettingsRow extends StatelessWidget {
  const SettingsRow({
    required this.title,
    required this.leading,
    this.subtitle,
    this.trailing,
    this.onTap,
    super.key,
  });

  final String title;
  final String? subtitle;
  final IconData leading;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => MergeSemantics(
    child: ListTile(
      minTileHeight: AppDimensions.largeTouchTarget,
      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      leading: Icon(leading),
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle!),
      trailing: trailing,
      onTap: onTap,
    ),
  );
}
