import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:ishamela/features/reader/body_display_map.dart';
import 'package:ishamela/features/reader/reader_styles.dart';
import 'package:ishamela/features/reader/text_roles.dart';

void main() {
  test('title span classifies as title', () {
    const body =
        '<span data-type="title" id=toc-1>المقدمة</span>\nالحمد لله';
    final roles = classifyTextRoles(body);
    expect(roles.display.startsWith('المقدمة'), isTrue);
    for (var i = 0; i < 'المقدمة'.length; i++) {
      expect(roles.roleAt(i), TextRole.title);
    }
    expect(roles.roleAt('المقدمة\n'.length), TextRole.body);
  });

  test('all honorific phrases share honorific role', () {
    const body =
        'قال النبي صلى اللَّهُ عليه وسلم وقال أبو بكر رضي الله عنه ورحمه الله وعز وجل.';
    final roles = classifyTextRoles(body);
    final seen = <TextRole>{};
    for (var i = 0; i < roles.display.length; i++) {
      seen.add(roles.roleAt(i));
    }
    expect(seen.contains(TextRole.honorific), isTrue);
    expect(
      roles.display.contains('رضي الله عنه') ||
          roles.roles.any((r) => r == TextRole.honorific),
      isTrue,
    );
  });

  test('Unicode honorific ligatures classify as honorific', () {
    // Corpus forms from SPEC-006 census (ﷺ ﷿ ﷻ ؓ …).
    const body = 'النبي\uFDFA قال أبو بكر\uFD41 وعائشة\uFD42 والله\uFDFF و\uFDFB';
    final roles = classifyTextRoles(body);
    for (final ch in ['\uFDFA', '\uFD41', '\uFD42', '\uFDFF', '\uFDFB']) {
      final i = roles.display.indexOf(ch);
      expect(i, greaterThanOrEqualTo(0), reason: 'missing $ch');
      expect(roles.roleAt(i), TextRole.honorific, reason: ch);
    }
  });

  test('quran marks color inner text too', () {
    const body = '﴿آية كريمة﴾، نص.';
    final roles = classifyTextRoles(body);
    final open = roles.display.indexOf('﴿');
    final close = roles.display.indexOf('﴾');
    expect(open, greaterThanOrEqualTo(0));
    expect(close, greaterThan(open));
    for (var i = open; i <= close; i++) {
      expect(roles.roleAt(i), TextRole.quran);
    }
    expect(roles.roleAt(roles.display.indexOf('،')), TextRole.punctuation);
  });

  test('CRLF and br become newlines', () {
    final crlf = BodyDisplayMap.fromBody('سطر1\r\nسطر2');
    expect(crlf.display, 'سطر1\nسطر2');
    final br = BodyDisplayMap.fromBody('أ<br>ب');
    expect(br.display, 'أ\nب');
  });

  test('ReaderTextStyles migrates legacy keys and stores font', () {
    final json = jsonEncode({
      'salawat': {'color': '#112233', 'bold': true},
      'quran_mark': {'color': '#AABBCC', 'bold': false},
      'font': 'scheherazade',
      'font_size': 24,
    });
    final merged = ReaderTextStyles.fromJsonString(json);
    expect(merged.styleFor(TextRole.honorific).color.toARGB32(), 0xFF112233);
    expect(merged.styleFor(TextRole.quran).color.toARGB32(), 0xFFAABBCC);
    expect(merged.font, ReaderFont.scheherazade);
    expect(merged.fontSize, 24);
  });
}
