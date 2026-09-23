/// Format integers with Arabic-Indic digits (٠١٢٣٤٥٦٧٨٩) for Home/Profile stats.
String toArabicIndicDigits(int value) {
  const western = '0123456789';
  const arabic = '٠١٢٣٤٥٦٧٨٩';
  final raw = value.toString();
  final buf = StringBuffer();
  for (final cu in raw.runes) {
    final ch = String.fromCharCode(cu);
    final i = western.indexOf(ch);
    buf.write(i >= 0 ? arabic[i] : ch);
  }
  return buf.toString();
}

/// Percent 0–100 as Arabic-Indic with ٪ suffix (RTL-friendly).
String arabicPercent(int percent) {
  final p = percent.clamp(0, 100);
  return '٪${toArabicIndicDigits(p)}';
}
