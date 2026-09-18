import 'package:flutter/material.dart';

import 'package:ishamela/ui/theme/ishamela_tokens.dart';

class AppBottomNavDestination {
  const AppBottomNavDestination({
    required this.icon,
    required this.label,
    this.badgeCount,
  });

  final IconData icon;
  final String label;
  final int? badgeCount;
}

/// Card bottom nav with green100 active pill (DESIGN-001 §3).
class AppBottomNav extends StatelessWidget {
  const AppBottomNav({
    super.key,
    required this.destinations,
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  final List<AppBottomNavDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    final t = IshamelaTokens.of(context);
    return Material(
      color: t.card,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: t.hairline)),
          color: t.card,
        ),
        child: SafeArea(
          top: false,
          child: NavigationBar(
            selectedIndex: selectedIndex,
            onDestinationSelected: onDestinationSelected,
            destinations: [
              for (final d in destinations)
                NavigationDestination(
                  icon: _NavIcon(icon: d.icon, badgeCount: d.badgeCount),
                  selectedIcon: _NavIcon(
                    icon: d.icon,
                    badgeCount: d.badgeCount,
                    selected: true,
                  ),
                  label: d.label,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavIcon extends StatelessWidget {
  const _NavIcon({
    required this.icon,
    this.badgeCount,
    this.selected = false,
  });

  final IconData icon;
  final int? badgeCount;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final t = IshamelaTokens.of(context);
    Widget child = Icon(icon);
    if (selected) {
      child = Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: t.green100,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Icon(icon, color: t.green900),
      );
    }
    final count = badgeCount ?? 0;
    if (count <= 0) return child;
    return Badge(
      backgroundColor: t.gold,
      textColor: Colors.white,
      label: Text(
        count > 99 ? '99+' : '$count',
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
      ),
      child: child,
    );
  }
}
