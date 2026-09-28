import 'package:flutter/material.dart';

import 'package:ishamela/ui/glass/drawn/drawn_glass_surface.dart';
import 'package:ishamela/ui/glass/glass_surface.dart';

/// Reader top bar. Text in the page scrolls underneath (SPEC-027 §3).
class GlassAppBar extends StatelessWidget {
  const GlassAppBar({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.viewPaddingOf(context).top;
    return Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: EdgeInsets.fromLTRB(12, top + 8, 12, 0),
        child: GlassSurface(shape: const GlassShape.pill(), child: child),
      ),
    );
  }
}
