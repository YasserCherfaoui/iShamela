import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:ishamela/ui/theme/glass_tokens.dart';

/// WCAG relative luminance, sRGB.
double relativeLuminance(Color color) {
  double channel(double c) {
    return c <= 0.04045 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();
  }

  final r = channel(color.r);
  final g = channel(color.g);
  final b = channel(color.b);
  return 0.2126 * r + 0.7152 * g + 0.0722 * b;
}

double contrastRatio(Color a, Color b) {
  final l1 = relativeLuminance(a);
  final l2 = relativeLuminance(b);
  final hi = math.max(l1, l2);
  final lo = math.min(l1, l2);
  return (hi + 0.05) / (lo + 0.05);
}

/// Source-over composite of [src] onto [dst].
Color compositeOver(Color src, Color dst) {
  final a = src.a;
  final outA = a + dst.a * (1 - a);
  if (outA == 0) return const Color(0x00000000);
  double channel(double s, double d) => (s * a + d * dst.a * (1 - a)) / outA;
  return Color.from(
    alpha: outA,
    red: channel(src.r, dst.r),
    green: channel(src.g, dst.g),
    blue: channel(src.b, dst.b),
  );
}

/// Lowest contrast of [foreground] against the glass tint over [page] and
/// over [ink] (a page of ink text behind the glass, SPEC-027 §7).
double worstGlassContrast({
  required Color foreground,
  required Color tint,
  required Color page,
  required Color ink,
}) {
  final overPage = contrastRatio(foreground, compositeOver(tint, page));
  final overInk = contrastRatio(foreground, compositeOver(tint, ink));
  return math.min(overPage, overInk);
}

/// Active-capsule fill. Raised to 24% when [foreground] cannot hold 4.5:1
/// on the worst backdrop (SPEC-027 §7). 24 px+ numerals use 3:1 via [large].
Color activeCapsuleForLabel({
  required GlassTokens tokens,
  required Color foreground,
  required Color page,
  required Color ink,
  bool large = false,
}) {
  final minRatio = large ? 3.0 : 4.5;
  final ratio = worstGlassContrast(
    foreground: foreground,
    tint: tokens.tint,
    page: page,
    ink: ink,
  );
  if (ratio < minRatio) {
    return tokens.activeCapsule.withValues(alpha: 0.24);
  }
  return tokens.activeCapsule;
}
