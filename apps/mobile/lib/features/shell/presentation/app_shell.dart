import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/connectivity/connectivity_service.dart';
import '../../../core/localization/localization_extension.dart';
import '../../../design_system/tokens.dart';
import '../../../design_system/widgets/badges.dart';

class AppShell extends ConsumerWidget {
  const AppShell({required this.navigationShell, super.key});
  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectivity = ref.watch(connectivityProvider).valueOrNull;
    final destinations = _destinations(context);
    final isWide =
        MediaQuery.sizeOf(context).width >= AppDimensions.phoneBreakpoint;
    final indicator = switch (connectivity) {
      ConnectivityState.offline => OfflineIndicator(
        label: context.l10n.offline,
      ),
      ConnectivityState.reconnecting => OfflineIndicator(
        label: context.l10n.reconnecting,
      ),
      ConnectivityState.synchronizing => OfflineIndicator(
        label: context.l10n.synchronizing,
      ),
      _ => null,
    };

    if (isWide) {
      return Scaffold(
        body: Column(
          children: [
            ?indicator,
            Expanded(
              child: Row(
                children: [
                  NavigationRail(
                    selectedIndex: navigationShell.currentIndex,
                    onDestinationSelected: (index) => _go(index),
                    destinations: [
                      for (final destination in destinations)
                        NavigationRailDestination(
                          icon: Icon(destination.icon),
                          selectedIcon: Icon(destination.selectedIcon),
                          label: Text(destination.label),
                        ),
                    ],
                  ),
                  VerticalDivider(
                    width: 1,
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                  Expanded(child: navigationShell),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      body: Column(
        children: [
          ?indicator,
          Expanded(child: navigationShell),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: _go,
        destinations: [
          for (final destination in destinations)
            NavigationDestination(
              icon: Icon(destination.icon),
              selectedIcon: Icon(destination.selectedIcon),
              label: destination.label,
            ),
        ],
      ),
    );
  }

  void _go(int index) => navigationShell.goBranch(
    index,
    initialLocation: index == navigationShell.currentIndex,
  );

  List<_Destination> _destinations(BuildContext context) => [
    _Destination(context.l10n.home, AppIcons.home, AppIcons.homeSelected),
    _Destination(context.l10n.scan, AppIcons.scan, AppIcons.scanSelected),
    _Destination(context.l10n.learn, AppIcons.learn, AppIcons.learnSelected),
    _Destination(context.l10n.saved, AppIcons.saved, AppIcons.savedSelected),
    _Destination(
      context.l10n.profile,
      AppIcons.profile,
      AppIcons.profileSelected,
    ),
  ];
}

class _Destination {
  const _Destination(this.label, this.icon, this.selectedIcon);
  final String label;
  final IconData icon;
  final IconData selectedIcon;
}
