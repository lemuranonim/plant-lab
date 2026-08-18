import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:plant_lab/core/access/access_context.dart';
import 'package:plant_lab/core/access/access_context_provider.dart';
import 'package:plant_lab/core/widgets/operational_mode_banner.dart';

class NavigationShell extends ConsumerWidget {
  const NavigationShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final access = ref.watch(accessContextProvider).valueOrNull;
    if (access == null) {
      return const Scaffold(
        body: Column(
          children: [
            OperationalModeBanner(),
            Expanded(child: Center(child: CircularProgressIndicator())),
          ],
        ),
      );
    }

    final destinations = _destinationsFor(access);
    final visibleIndex = destinations.indexWhere(
      (destination) => destination.branchIndex == navigationShell.currentIndex,
    );

    return Scaffold(
      body: Column(
        children: [
          const OperationalModeBanner(),
          _AccessScopeBanner(access: access),
          Expanded(child: navigationShell),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: visibleIndex < 0 ? 0 : visibleIndex,
        onTap: (index) {
          final branchIndex = destinations[index].branchIndex;
          navigationShell.goBranch(
            branchIndex,
            initialLocation: branchIndex == navigationShell.currentIndex,
          );
        },
        items: destinations
            .map(
              (destination) => BottomNavigationBarItem(
                icon: Icon(destination.icon),
                activeIcon: Icon(destination.activeIcon),
                label: destination.label,
              ),
            )
            .toList(growable: false),
      ),
    );
  }
}

List<_ScopedNavigationDestination> _destinationsFor(AccessContext access) {
  return [
    const _ScopedNavigationDestination(
      branchIndex: 0,
      icon: Icons.dashboard_outlined,
      activeIcon: Icons.dashboard,
      label: 'Dashboard',
    ),
    if (access.canAccessPlant) ...[
      const _ScopedNavigationDestination(
        branchIndex: 1,
        icon: Icons.agriculture_outlined,
        activeIcon: Icons.agriculture,
        label: 'Receiving',
      ),
      const _ScopedNavigationDestination(
        branchIndex: 2,
        icon: Icons.assignment_outlined,
        activeIcon: Icons.assignment,
        label: 'Inspections',
      ),
    ],
    if (access.canAccessLab)
      const _ScopedNavigationDestination(
        branchIndex: 3,
        icon: Icons.science_outlined,
        activeIcon: Icons.science,
        label: 'Lab Test',
      ),
  ];
}

class _ScopedNavigationDestination {
  const _ScopedNavigationDestination({
    required this.branchIndex,
    required this.icon,
    required this.activeIcon,
    required this.label,
  });

  final int branchIndex;
  final IconData icon;
  final IconData activeIcon;
  final String label;
}

class _AccessScopeBanner extends StatelessWidget {
  const _AccessScopeBanner({required this.access});

  final AccessContext access;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: colorScheme.primaryContainer.withValues(alpha: 0.45),
      child: Row(
        children: [
          Icon(
            Icons.verified_user_outlined,
            size: 18,
            color: colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${access.primaryRoleName} • ${access.siteSummary}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
