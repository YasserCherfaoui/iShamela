import 'package:flutter/material.dart';

import 'package:ishamela/ui/app_bottom_nav.dart';
import 'package:ishamela/ui/glass/drawn/drawn_glass_surface.dart';
import 'package:ishamela/ui/glass/glass_capability.dart';
import 'package:ishamela/ui/glass/glass_contrast.dart';
import 'package:ishamela/ui/glass/glass_surface.dart';
import 'package:ishamela/ui/theme/glass_tokens.dart';
import 'package:ishamela/ui/theme/ishamela_theme.dart';
import 'package:ishamela/ui/theme/reader_theme_tokens.dart';

/// Floating tab pill (SPEC-027 §3). Active tab is a soft capsule.
class GlassTabBar extends StatelessWidget {
  const GlassTabBar({
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
    final scope = GlassStyleScope.maybeOf(context);
    final atmosphere =
        scope?.atmosphere ?? ReaderThemeTokens.of(context).atmosphere;
    final tokens = _paint(scope, atmosphere);
    final page = ReaderThemeTokens.forAtmosphere(atmosphere).ground;
    final ink = ReaderThemeTokens.forAtmosphere(atmosphere).body;
    final reduce = MediaQuery.disableAnimationsOf(context);
    return GlassSurface(
      shape: const GlassShape.pill(),
      interactive: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(
          children: [
            for (var i = 0; i < destinations.length; i++)
              Expanded(
                child: _Tab(
                  destination: destinations[i],
                  selected: i == selectedIndex,
                  tokens: tokens,
                  page: page,
                  ink: ink,
                  reduceMotion: reduce,
                  onTap: () => onDestinationSelected(i),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

GlassTokens _paint(GlassStyleScope? scope, ReadingAtmosphere atmosphere) {
  final base = GlassTokens.forAtmosphere(atmosphere);
  if (scope?.capability == GlassCapability.frosted) return base.frosted();
  return base;
}

class _Tab extends StatelessWidget {
  const _Tab({
    required this.destination,
    required this.selected,
    required this.tokens,
    required this.page,
    required this.ink,
    required this.reduceMotion,
    required this.onTap,
  });

  final AppBottomNavDestination destination;
  final bool selected;
  final GlassTokens tokens;
  final Color page;
  final Color ink;
  final bool reduceMotion;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? tokens.foregroundAccent : tokens.foregroundInk;
    final capsule = activeCapsuleForLabel(
      tokens: tokens,
      foreground: fg,
      page: page,
      ink: ink,
    );
    return Semantics(
      button: true,
      selected: selected,
      label: destination.label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(tokens.radiusPill),
        child: AnimatedContainer(
          duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: selected ? capsule : const Color(0x00000000),
            borderRadius: BorderRadius.circular(tokens.radiusPill),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(destination.icon, size: 22, color: fg),
              const SizedBox(height: 2),
              Text(
                destination.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: kFontUi,
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: fg,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
