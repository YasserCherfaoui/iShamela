import 'package:flutter/material.dart';
import 'package:real_liquid_glass/real_liquid_glass.dart';

import 'package:ishamela/ui/glass/drawn/drawn_glass_surface.dart';
import 'package:ishamela/ui/glass/glass_capability.dart';
import 'package:ishamela/ui/glass/interface_style.dart';
import 'package:ishamela/ui/theme/glass_tokens.dart';
import 'package:ishamela/ui/theme/ishamela_tokens.dart';
import 'package:ishamela/ui/theme/reader_theme_tokens.dart';

/// Resolved once per frame from the app binder (SPEC-027 §5.1).
class GlassStyleScope extends InheritedWidget {
  const GlassStyleScope({
    super.key,
    required this.style,
    required this.capability,
    required this.atmosphere,
    required this.sheetDepth,
    required super.child,
  });

  final InterfaceStyle style;
  final GlassCapability capability;
  final ReadingAtmosphere atmosphere;
  final int sheetDepth;

  static GlassStyleScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<GlassStyleScope>();
  }

  bool get liquid => style == InterfaceStyle.liquidGlass;

  @override
  bool updateShouldNotify(GlassStyleScope oldWidget) {
    return style != oldWidget.style ||
        capability != oldWidget.capability ||
        atmosphere != oldWidget.atmosphere ||
        sheetDepth != oldWidget.sheetDepth;
  }
}

/// Marks a grouped glass chrome so nested fields do not add a backdrop.
class GlassClusterMarker extends InheritedWidget {
  const GlassClusterMarker({super.key, required super.child});

  static bool inside(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<GlassClusterMarker>() !=
        null;
  }

  @override
  bool updateShouldNotify(GlassClusterMarker oldWidget) => false;
}

/// Facade. Manuscript paints the Warm Manuscript container with no blur.
class GlassSurface extends StatelessWidget {
  const GlassSurface({
    super.key,
    required this.child,
    required this.shape,
    this.tintOverride,
    this.interactive = false,
    this.useBackdrop = true,
  });

  final Widget child;
  final GlassShape shape;
  final Color? tintOverride;
  final bool interactive;
  final bool useBackdrop;

  @override
  Widget build(BuildContext context) {
    final scope = GlassStyleScope.maybeOf(context);
    final atmosphere =
        scope?.atmosphere ?? ReaderThemeTokens.of(context).atmosphere;
    final tokens = GlassTokens.forAtmosphere(atmosphere);
    final style = scope?.style ?? InterfaceStyle.manuscript;
    if (style != InterfaceStyle.liquidGlass) {
      return _ManuscriptChrome(shape: shape, child: child);
    }

    final sheetOpen = (scope?.sheetDepth ?? 0) > 0;
    final isSheet = shape.kind == GlassShapeKind.sheet;
    final opaque = sheetOpen && !isSheet;
    var capability = scope?.capability ?? GlassCapability.drawn;
    if (opaque) capability = GlassCapability.frosted;
    final paintTokens = capability == GlassCapability.frosted
        ? tokens.frosted()
        : tokens;

    if (capability == GlassCapability.native && !opaque) {
      return LiquidGlassContainer(
        style: LiquidGlassStyle.regular,
        shape: _liquidShape(shape, paintTokens),
        tint: tintOverride ?? paintTokens.tint,
        interactive: interactive,
        child: GlassClusterMarker(child: child),
      );
    }

    return DrawnGlassSurface(
      tokens: paintTokens,
      shape: shape,
      tintOverride: tintOverride,
      useBackdrop: useBackdrop && !opaque,
      opaque: opaque,
      child: GlassClusterMarker(child: child),
    );
  }
}

LiquidGlassShape _liquidShape(GlassShape shape, GlassTokens tokens) {
  final radius = shape.borderRadius(tokens).topLeft.x;
  switch (shape.kind) {
    case GlassShapeKind.pill:
      return const LiquidGlassShape.capsule();
    case GlassShapeKind.bar:
    case GlassShapeKind.sheet:
      return LiquidGlassShape.roundedRectangle(radius);
  }
}

class _ManuscriptChrome extends StatelessWidget {
  const _ManuscriptChrome({required this.shape, required this.child});

  final GlassShape shape;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = IshamelaTokens.of(context);
    final radius = shape.borderRadius(GlassTokens.light);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: radius,
        border: Border.all(color: t.hairline),
      ),
      child: child,
    );
  }
}

/// Tokens for a control sitting on glass chrome. Null in Manuscript, and for
/// controls that are not inside a glass surface (list-row actions stay solid).
GlassTokens? glassChromeTokens(BuildContext context) {
  final scope = GlassStyleScope.maybeOf(context);
  if (scope == null || !scope.liquid) return null;
  if (!GlassClusterMarker.inside(context)) return null;
  final base = GlassTokens.forAtmosphere(scope.atmosphere);
  if (scope.capability == GlassCapability.frosted) return base.frosted();
  return base;
}

/// Wraps [child] in glass when Liquid Glass is on. Manuscript returns [child]
/// with no extra decoration, so existing chrome stays unchanged.
class GlassCluster extends StatelessWidget {
  const GlassCluster({
    super.key,
    required this.shape,
    required this.child,
    this.useBackdrop = true,
    this.tintOverride,
  });

  final GlassShape shape;
  final Widget child;
  final bool useBackdrop;
  final Color? tintOverride;

  @override
  Widget build(BuildContext context) {
    final scope = GlassStyleScope.maybeOf(context);
    final reduce = MediaQuery.disableAnimationsOf(context);
    final glass = scope?.liquid ?? false;
    return AnimatedSwitcher(
      duration: reduce ? Duration.zero : const Duration(milliseconds: 220),
      child: glass
          ? GlassClusterMarker(
              key: const ValueKey('glass'),
              child: GlassSurface(
                shape: shape,
                useBackdrop: useBackdrop,
                tintOverride: tintOverride,
                child: child,
              ),
            )
          : KeyedSubtree(key: const ValueKey('manuscript'), child: child),
    );
  }
}
