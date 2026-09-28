import 'package:flutter/material.dart';

import 'package:ishamela/ui/glass/drawn/drawn_glass_surface.dart';
import 'package:ishamela/ui/glass/glass_surface.dart';
import 'package:ishamela/ui/theme/ishamela_tokens.dart';

/// Search field chrome. When a parent [GlassCluster] already provides the
/// surface, this stays transparent so the two do not nest a backdrop.
class GlassSearchField extends StatelessWidget {
  const GlassSearchField({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scope = GlassStyleScope.maybeOf(context);
    if (scope == null || !scope.liquid) return child;
    if (GlassClusterMarker.inside(context)) return child;
    return GlassSurface(
      shape: const GlassShape.pill(),
      child: child,
    );
  }
}

InputDecoration glassSearchDecoration({
  required BuildContext context,
  required InputDecoration manuscript,
}) {
  final scope = GlassStyleScope.maybeOf(context);
  if (scope == null || !scope.liquid) return manuscript;
  final t = IshamelaTokens.of(context);
  const clear = Color(0x00000000);
  return manuscript.copyWith(
    filled: true,
    fillColor: clear,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(999),
      borderSide: const BorderSide(color: clear),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(999),
      borderSide: const BorderSide(color: clear),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(999),
      borderSide: BorderSide(color: t.green700, width: 1.5),
    ),
  );
}
