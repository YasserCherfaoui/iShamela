import 'package:flutter/material.dart';

import 'package:ishamela/ui/glass/drawn/drawn_glass_surface.dart';
import 'package:ishamela/ui/glass/glass_surface.dart';

/// Reader bottom page-nav pill (SPEC-027 §3).
class GlassToolbar extends StatelessWidget {
  const GlassToolbar({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewPaddingOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, bottom + 22),
      child: GlassSurface(
        shape: const GlassShape.pill(),
        interactive: true,
        child: child,
      ),
    );
  }
}
