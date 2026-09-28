import 'dart:ui';

/// Backdrop color matrix: saturation, then brightness (SPEC-027 §5.3).
List<double> glassColorMatrix({
  required double saturation,
  required double brightness,
}) {
  const lr = 0.213;
  const lg = 0.715;
  const lb = 0.072;
  final s = saturation;
  final inv = 1 - s;
  final a = inv * lr;
  final b = inv * lg;
  final c = inv * lb;
  final m = brightness;
  return <double>[
    (a + s) * m, b * m, c * m, 0, 0,
    a * m, (b + s) * m, c * m, 0, 0,
    a * m, b * m, (c + s) * m, 0, 0,
    0, 0, 0, 1, 0,
  ];
}

/// σ = blur/2.4. Physical blur tracks devicePixelRatio only up to 3×.
double glassBlurSigma(double blurPx, double devicePixelRatio) {
  if (blurPx <= 0) return 0;
  final dpr = devicePixelRatio <= 0 ? 1.0 : devicePixelRatio;
  final clamped = dpr > 3 ? 3.0 : dpr;
  return (blurPx / 2.4) * (clamped / dpr);
}

ImageFilter glassBackdropFilter({
  required double blurPx,
  required double saturation,
  required double brightness,
  required double devicePixelRatio,
}) {
  final sigma = glassBlurSigma(blurPx, devicePixelRatio);
  return ImageFilter.compose(
    outer: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
    inner: ColorFilter.matrix(
      glassColorMatrix(saturation: saturation, brightness: brightness),
    ),
  );
}
