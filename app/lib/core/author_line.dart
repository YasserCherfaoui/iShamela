/// Format author display with optional Hijri death year (DESIGN-001).
String? formatAuthorLine(String? name, int? deathYearHijri) {
  if (name == null || name.isEmpty) return null;
  if (deathYearHijri == null) return name;
  return '$name · ت $deathYearHijriهـ';
}
