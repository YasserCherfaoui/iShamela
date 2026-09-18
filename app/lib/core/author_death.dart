import 'package:ishamela/l10n/app_localizations.dart';

/// SPEC-018 death-date rendering. Never converts calendars.
String? formatAuthorDeath(AppLocalizations l10n, int? deathYearHijri) {
  if (deathYearHijri == null || deathYearHijri == 0) return null;
  if (deathYearHijri < 0) {
    return l10n.diedCE(-deathYearHijri);
  }
  return l10n.diedHijri(deathYearHijri);
}
