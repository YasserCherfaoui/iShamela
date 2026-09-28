import 'dart:ui';

import 'package:flutter/material.dart';

import 'package:ishamela/ui/glass/glass_color_matrix.dart';
import 'package:ishamela/ui/theme/glass_tokens.dart';

/// How many ancestor backdrop layers are already live.
class GlassBackdropScope extends InheritedWidget {
  const GlassBackdropScope({
    super.key,
    required this.depth,
    required super.child,
  });

  final int depth;

  static int depthOf(BuildContext context) {
    if (!context.mounted) return 0;
    final scope = context
        .dependOnInheritedWidgetOfExactType<GlassBackdropScope>();
    return scope?.depth ?? 0;
  }

  @override
  bool updateShouldNotify(GlassBackdropScope oldWidget) =>
      depth != oldWidget.depth;
}

/// Caps live backdrop layers at two per screen (SPEC-027 §6).
class GlassBackdropBudget {
  static final Set<int> _live = <int>{};

  static bool holds(int id) => _live.contains(id);

  static bool tryAcquire(int id) {
    if (_live.contains(id)) return true;
    if (_live.length >= 2) return false;
    _live.add(id);
    return true;
  }

  static void release(int id) => _live.remove(id);

  static void resetForTest() => _live.clear();
}

enum GlassShapeKind { pill, bar, sheet }

/// [GlassShape.pill], [GlassShape.bar], or [GlassShape.sheet] (SPEC-027 §5.1).
class GlassShape {
  const GlassShape.pill() : kind = GlassShapeKind.pill, radius = null;

  const GlassShape.bar([this.radius]) : kind = GlassShapeKind.bar;

  const GlassShape.sheet() : kind = GlassShapeKind.sheet, radius = null;

  final GlassShapeKind kind;
  final double? radius;

  BorderRadius borderRadius(GlassTokens tokens) {
    switch (kind) {
      case GlassShapeKind.pill:
        return BorderRadius.circular(tokens.radiusPill);
      case GlassShapeKind.bar:
        return BorderRadius.circular(radius ?? tokens.radiusBar);
      case GlassShapeKind.sheet:
        return BorderRadius.vertical(top: Radius.circular(tokens.radiusSheet));
    }
  }
}

/// Drawn recipe (SPEC-027 §5.3). No third-party glass package.
class DrawnGlassSurface extends StatefulWidget {
  const DrawnGlassSurface({
    super.key,
    required this.tokens,
    required this.shape,
    required this.child,
    this.tintOverride,
    this.useBackdrop = true,
    this.opaque = false,
  });

  final GlassTokens tokens;
  final GlassShape shape;
  final Widget child;
  final Color? tintOverride;
  final bool useBackdrop;
  final bool opaque;

  @override
  State<DrawnGlassSurface> createState() => _DrawnGlassSurfaceState();
}

class _DrawnGlassSurfaceState extends State<DrawnGlassSurface> {
  final int _id = identityHashCode(Object());
  bool _held = false;

  bool _syncHold() {
    final nested = GlassBackdropScope.depthOf(context) > 0;
    final blur = widget.opaque ? 0.0 : widget.tokens.blur;
    final want = widget.useBackdrop && !widget.opaque && !nested && blur > 0;
    if (want) {
      _held = GlassBackdropBudget.tryAcquire(_id);
    } else if (_held) {
      GlassBackdropBudget.release(_id);
      _held = false;
    }
    return _held;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncHold();
  }

  @override
  void didUpdateWidget(DrawnGlassSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncHold();
  }

  @override
  void dispose() {
    if (_held) GlassBackdropBudget.release(_id);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = widget.opaque ? _opaque(widget.tokens) : widget.tokens;
    final radius = widget.shape.borderRadius(tokens);
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final sigma = widget.opaque || !_held
        ? 0.0
        : glassBlurSigma(tokens.blur, dpr);
    final tint = widget.tintOverride ?? tokens.tint;
    final filter = sigma <= 0
        ? null
        : glassBackdropFilter(
            blurPx: tokens.blur,
            saturation: tokens.saturation,
            brightness: tokens.brightness,
            devicePixelRatio: dpr,
          );

    Widget layers = DecoratedBox(
      decoration: BoxDecoration(
        color: tint,
        borderRadius: radius,
        border: Border.all(color: tokens.stroke),
      ),
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          widget.child,
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 1,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(color: tokens.highlight),
              ),
            ),
          ),
        ],
      ),
    );

    if (filter != null) {
      // The controls stay outside the filter. On web a BackdropFilter
      // ancestor drops pointer events, so prev/next never receive the click.
      layers = Stack(
        fit: StackFit.passthrough,
        children: [
          Positioned.fill(
            child: BackdropFilter(
              filter: filter,
              child: const SizedBox.expand(),
            ),
          ),
          layers,
        ],
      );
      layers = GlassBackdropScope(
        depth: GlassBackdropScope.depthOf(context) + 1,
        child: layers,
      );
    }

    return RepaintBoundary(
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: [
            BoxShadow(
              color: tokens.shadow,
              offset: Offset(0, tokens.shadowY),
              blurRadius: tokens.shadowBlur,
            ),
          ],
        ),
        child: ClipRRect(borderRadius: radius, child: layers),
      ),
    );
  }
}

GlassTokens _opaque(GlassTokens tokens) {
  return GlassTokens(
    blur: 0,
    saturation: 1,
    brightness: 1,
    tint: tokens.tint.withValues(alpha: 1),
    stroke: tokens.stroke,
    highlight: const Color(0x00000000),
    shadow: const Color(0x00000000),
    shadowY: 0,
    shadowBlur: 0,
    radiusPill: tokens.radiusPill,
    radiusBar: tokens.radiusBar,
    radiusSheet: tokens.radiusSheet,
    activeCapsule: tokens.activeCapsule,
    foregroundInk: tokens.foregroundInk,
    foregroundAccent: tokens.foregroundAccent,
    foregroundGold: tokens.foregroundGold,
  );
}

/// Identity filter used by tests to assert the compose order.
ImageFilter debugGlassFilter(GlassTokens tokens, double dpr) {
  return glassBackdropFilter(
    blurPx: tokens.blur,
    saturation: tokens.saturation,
    brightness: tokens.brightness,
    devicePixelRatio: dpr,
  );
}
