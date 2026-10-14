import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_routes.dart';
import '../../../core/localization/localization_extension.dart';
import '../../../design_system/widgets/buttons.dart';
import '../../../design_system/widgets/states.dart';

enum PlaceholderDestination { scan, learn, saved, sessions, unknown }

class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({required this.destination, super.key});
  final PlaceholderDestination destination;

  @override
  Widget build(BuildContext context) {
    final (title, icon) = switch (destination) {
      PlaceholderDestination.scan => (
        context.l10n.scan,
        Icons.document_scanner_outlined,
      ),
      PlaceholderDestination.learn => (
        context.l10n.learn,
        Icons.school_outlined,
      ),
      PlaceholderDestination.saved => (
        context.l10n.saved,
        Icons.bookmark_outline_rounded,
      ),
      PlaceholderDestination.sessions => (
        context.l10n.manageSessions,
        Icons.devices_outlined,
      ),
      PlaceholderDestination.unknown => (
        context.l10n.unknownPageTitle,
        Icons.travel_explore_rounded,
      ),
    };
    final isUnknown = destination == PlaceholderDestination.unknown;
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: AppEmptyState(
        title: isUnknown
            ? context.l10n.unknownPageTitle
            : context.l10n.nothingHereYet,
        message: isUnknown
            ? context.l10n.unknownPageBody
            : context.l10n.futureContentBody,
        icon: icon,
        action: isUnknown
            ? AppPrimaryButton(
                label: context.l10n.goHome,
                onPressed: () => context.go(AppRoute.home.path),
              )
            : null,
      ),
    );
  }
}
