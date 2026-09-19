import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';

import 'package:ishamela/ui/book_spine.dart';
import 'package:ishamela/ui/theme/ishamela_tokens.dart';
import 'package:ishamela/ui/theme/reader_theme_tokens.dart';
import 'package:ishamela/ui/theme/ishamela_theme.dart';

void main() {
  group('spineWordFromTitle', () {
    test('skips definite article and short stop words', () {
      expect(spineWordFromTitle('الكتاب المبين'), 'المبين');
      expect(spineWordFromTitle('في علم الأصول'), 'علم');
    });

    test('falls back on short titles', () {
      expect(spineWordFromTitle('ال'), 'ال');
      expect(spineWordFromTitle(''), '•');
    });

    test('strips HTML tags', () {
      expect(
        spineWordFromTitle('<span data-type="title">مقدمة الرسالة</span>'),
        'مقدمة',
      );
    });
  });

  group('theme tokens', () {
    test('IshamelaTokens lerp keeps palette length', () {
      final a = IshamelaTokens.paperLight;
      final b = a.copyWith(gold: const Color(0xFF000000));
      final mid = a.lerp(b, 0.5);
      expect(mid.spinePalette, hasLength(5));
      expect(mid.gold, isNot(equals(a.gold)));
    });

    test('ReaderThemeTokens atmospheres differ', () {
      expect(ReaderThemeTokens.paper.ground, isNot(ReaderThemeTokens.night.ground));
      expect(ReaderThemeTokens.night.highlightUnderline, isNotNull);
      expect(ReaderThemeTokens.sepia.highlightUnderline, isNull);
    });

    test('buildIshamelaTheme wires extensions', () {
      final theme = buildIshamelaTheme(ReadingAtmosphere.paper);
      expect(theme.extension<IshamelaTokens>(), isNotNull);
      expect(theme.extension<ReaderThemeTokens>()?.atmosphere,
          ReadingAtmosphere.paper);
      expect(theme.scaffoldBackgroundColor, IshamelaTokens.paperLight.paper);
    });

    test('night keeps brand-deep green900; emphasis is titles mint', () {
      final theme = buildIshamelaTheme(ReadingAtmosphere.night);
      final chrome = theme.extension<IshamelaTokens>()!;
      expect(chrome.green900, const Color(0xFF0E3B30));
      expect(chrome.emphasis, const Color(0xFF8FC7AC));
      expect(chrome.paper, const Color(0xFF101B17));
      expect(theme.brightness, Brightness.dark);
    });

    test('ReadingAtmosphere round-trip', () {
      expect(ReadingAtmosphere.fromId('night'), ReadingAtmosphere.night);
      expect(ReadingAtmosphere.sepia.id, 'sepia');
      expect(ReadingAtmosphere.fromId(null), ReadingAtmosphere.paper);
    });
  });
}
