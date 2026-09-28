import 'package:flutter/material.dart';

import 'package:ishamela/ui/theme/reader_theme_tokens.dart';

/// Drawn Liquid Glass material (SPEC-027 §4). One object per reading theme.
///
/// Native glass uses [tint] and the shape radius only; the OS supplies the rest.
@immutable
class GlassTokens {
  const GlassTokens({
    required this.blur,
    required this.saturation,
    required this.brightness,
    required this.tint,
    required this.stroke,
    required this.highlight,
    required this.shadow,
    required this.shadowY,
    required this.shadowBlur,
    required this.radiusPill,
    required this.radiusBar,
    required this.radiusSheet,
    required this.activeCapsule,
    required this.foregroundInk,
    required this.foregroundAccent,
    required this.foregroundGold,
  });

  final double blur;
  final double saturation;
  final double brightness;
  final Color tint;
  final Color stroke;
  final Color highlight;
  final Color shadow;
  final double shadowY;
  final double shadowBlur;
  final double radiusPill;
  final double radiusBar;
  final double radiusSheet;
  final Color activeCapsule;
  final Color foregroundInk;
  final Color foregroundAccent;
  final Color foregroundGold;

  static const light = GlassTokens(
    blur: 28,
    saturation: 1.70,
    brightness: 1.05,
    tint: Color(0x94FBF7EC),
    stroke: Color(0x99FFFFFF),
    highlight: Color(0xB3FFFFFF),
    shadow: Color(0x1F0E3B30),
    shadowY: 8,
    shadowBlur: 24,
    radiusPill: 999,
    radiusBar: 20,
    radiusSheet: 28,
    activeCapsule: Color(0x1F0E3B30),
    foregroundInk: Color(0xFF1F2A24),
    foregroundAccent: Color(0xFF0E3B30),
    foregroundGold: Color(0xFFA67C2E),
  );

  static const sepia = GlassTokens(
    blur: 28,
    saturation: 1.60,
    brightness: 1.03,
    tint: Color(0x99F1E5CC),
    stroke: Color(0x80FFFFFF),
    highlight: Color(0x99FFFFFF),
    shadow: Color(0x1F5A4A1E),
    shadowY: 8,
    shadowBlur: 24,
    radiusPill: 999,
    radiusBar: 20,
    radiusSheet: 28,
    activeCapsule: Color(0x1F6B5220),
    foregroundInk: Color(0xFF1F2A24),
    foregroundAccent: Color(0xFF0E3B30),
    foregroundGold: Color(0xFF8F6A1F),
  );

  static const night = GlassTokens(
    blur: 24,
    saturation: 1.40,
    brightness: 1.00,
    tint: Color(0x85101B17),
    stroke: Color(0x29F2E8CF),
    highlight: Color(0x2EF2E8CF),
    shadow: Color(0x59000000),
    shadowY: 8,
    shadowBlur: 24,
    radiusPill: 999,
    radiusBar: 20,
    radiusSheet: 28,
    activeCapsule: Color(0x24F2E8CF),
    foregroundInk: Color(0xFFF2E8CF),
    foregroundAccent: Color(0xFF8FC7AC),
    foregroundGold: Color(0xFFC6A15B),
  );

  static GlassTokens forAtmosphere(ReadingAtmosphere atmosphere) {
    switch (atmosphere) {
      case ReadingAtmosphere.paper:
        return light;
      case ReadingAtmosphere.sepia:
        return sepia;
      case ReadingAtmosphere.night:
        return night;
    }
  }

  /// Reduce Transparency / governor fallback (§4, §7): no blur, no extra
  /// saturation, tint opacity raised to 94%.
  GlassTokens frosted() {
    return GlassTokens(
      blur: 0,
      saturation: 1,
      brightness: brightness,
      tint: tint.withValues(alpha: 0.94),
      stroke: stroke,
      highlight: highlight,
      shadow: shadow,
      shadowY: shadowY,
      shadowBlur: shadowBlur,
      radiusPill: radiusPill,
      radiusBar: radiusBar,
      radiusSheet: radiusSheet,
      activeCapsule: activeCapsule,
      foregroundInk: foregroundInk,
      foregroundAccent: foregroundAccent,
      foregroundGold: foregroundGold,
    );
  }

  Color get foregroundCream => foregroundInk;
}
