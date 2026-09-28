import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ishamela/core/providers.dart';
import 'package:ishamela/ui/glass/drawn/drawn_glass_surface.dart';
import 'package:ishamela/ui/glass/glass_surface.dart';
import 'package:ishamela/ui/theme/glass_tokens.dart';

/// Bottom sheet whose surface is glass in Liquid Glass and the caller's
/// Warm Manuscript card otherwise (SPEC-027 §3, §6).
Future<T?> showGlassSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = false,
  bool showDragHandle = false,
  Color? backgroundColor,
  ShapeBorder? shape,
}) {
  final scope = GlassStyleScope.maybeOf(context);
  final glass = scope?.liquid ?? false;
  if (!glass) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: isScrollControlled,
      showDragHandle: showDragHandle,
      backgroundColor: backgroundColor,
      shape: shape,
      builder: builder,
    );
  }

  final container = ProviderScope.containerOf(context);
  final gate = _GlassSheetGate(container);
  gate.enter();
  var hosted = false;
  final radius = GlassTokens.forAtmosphere(scope!.atmosphere).radiusSheet;
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    showDragHandle: showDragHandle,
    backgroundColor: const Color(0x00000000),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(radius)),
    ),
    builder: (ctx) {
      hosted = true;
      return _GlassSheetHost(
        gate: gate,
        child: GlassSurface(
          shape: const GlassShape.sheet(),
          child: builder(ctx),
        ),
      );
    },
  ).whenComplete(() {
    if (!hosted) gate.leave();
  });
}

/// Bars stay opaque for the whole time the sheet route is mounted.
/// [leave] runs from the host's dispose, after the close animation.
class _GlassSheetGate {
  _GlassSheetGate(this.container);

  final ProviderContainer container;
  bool _open = false;

  void enter() {
    _open = true;
    container.read(glassSheetDepthProvider.notifier).enter();
  }

  void leave() {
    if (!_open) return;
    _open = false;
    container.read(glassSheetDepthProvider.notifier).leave();
  }
}

class _GlassSheetHost extends StatefulWidget {
  const _GlassSheetHost({required this.gate, required this.child});

  final _GlassSheetGate gate;
  final Widget child;

  @override
  State<_GlassSheetHost> createState() => _GlassSheetHostState();
}

class _GlassSheetHostState extends State<_GlassSheetHost> {
  @override
  void dispose() {
    final gate = widget.gate;
    // Riverpod forbids provider writes during dispose. The next frame is
    // after the route is gone, so chrome can blur again without touching
    // the sheet's text controller.
    WidgetsBinding.instance.addPostFrameCallback((_) => gate.leave());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
