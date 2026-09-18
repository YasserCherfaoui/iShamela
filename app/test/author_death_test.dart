import 'package:flutter_test/flutter_test.dart';
import 'package:ishamela/l10n/app_localizations_ar.dart';
import 'package:ishamela/l10n/app_localizations_en.dart';

import 'package:ishamela/core/author_death.dart';

void main() {
  test('formatAuthorDeath hijri / CE / null', () {
    final ar = AppLocalizationsAr();
    final en = AppLocalizationsEn();
    expect(formatAuthorDeath(ar, null), isNull);
    expect(formatAuthorDeath(ar, 0), isNull);
    expect(formatAuthorDeath(ar, 676), 'ت 676هـ');
    expect(formatAuthorDeath(ar, -1999), 'ت 1999م');
    expect(formatAuthorDeath(en, 676), 'd. 676 AH');
    expect(formatAuthorDeath(en, -1999), 'd. 1999 CE');
  });
}
