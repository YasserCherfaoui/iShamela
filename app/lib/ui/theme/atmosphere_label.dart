import 'package:ishamela/l10n/app_localizations.dart';
import 'package:ishamela/ui/theme/reader_theme_tokens.dart';

String atmosphereLabel(AppLocalizations l10n, ReadingAtmosphere atmosphere) {
  switch (atmosphere) {
    case ReadingAtmosphere.paper:
      return l10n.atmospherePaper;
    case ReadingAtmosphere.sepia:
      return l10n.atmosphereSepia;
    case ReadingAtmosphere.night:
      return l10n.atmosphereNight;
    case ReadingAtmosphere.olive:
      return l10n.atmosphereOlive;
    case ReadingAtmosphere.gold:
      return l10n.atmosphereGold;
    case ReadingAtmosphere.ink:
      return l10n.atmosphereInk;
    case ReadingAtmosphere.blue:
      return l10n.atmosphereBlue;
    case ReadingAtmosphere.wood:
      return l10n.atmosphereWood;
  }
}
