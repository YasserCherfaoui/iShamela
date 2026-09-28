import 'package:ishamela/ui/glass/interface_style.dart';

/// How [GlassSurface] paints Liquid Glass (SPEC-027 §5.1).
enum GlassCapability { native, drawn, frosted }

/// Inputs that decide [GlassCapability]. Manuscript never reaches this.
class GlassCapabilityInput {
  const GlassCapabilityInput({
    required this.style,
    required this.applePlatform,
    required this.nativeAvailable,
    required this.reduceTransparency,
    required this.batterySaver,
    required this.governorTripped,
    this.elementBackdropWorks = true,
  });

  final InterfaceStyle style;
  final bool applePlatform;
  final bool nativeAvailable;
  final bool reduceTransparency;
  final bool batterySaver;
  final bool governorTripped;

  /// False when this element cannot sample the Flutter layer (SPEC-027 §5.2).
  final bool elementBackdropWorks;
}

/// Resolves the capability for Liquid Glass. Manuscript callers should not
/// paint glass at all; if they ask, the result is [GlassCapability.frosted]
/// only as a safe unused value — [style] manuscript is reported via
/// [resolvesToGlass] == false.
GlassCapability resolveGlassCapability(GlassCapabilityInput input) {
  if (input.style != InterfaceStyle.liquidGlass) {
    return GlassCapability.frosted;
  }
  if (input.reduceTransparency ||
      input.batterySaver ||
      input.governorTripped) {
    return GlassCapability.frosted;
  }
  if (input.applePlatform &&
      input.nativeAvailable &&
      input.elementBackdropWorks) {
    return GlassCapability.native;
  }
  return GlassCapability.drawn;
}

bool resolvesToGlass(InterfaceStyle style) =>
    style == InterfaceStyle.liquidGlass;
