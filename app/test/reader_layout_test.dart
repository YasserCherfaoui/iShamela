import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ishamela/features/home/study_duration.dart';
import 'package:ishamela/features/reader/reader_page.dart';

void main() {
  test('a wide window does not force the contents pane open', () {
    expect(
      readerSidePaneVisible(chromeVisible: true, wide: true, open: false),
      isFalse,
    );
    expect(
      readerSidePaneVisible(chromeVisible: true, wide: true, open: true),
      isTrue,
    );
    expect(
      readerSidePaneVisible(chromeVisible: false, wide: true, open: true),
      isFalse,
    );
  });

  test('side panes clear the floating glass bar', () {
    expect(readerGlassTopClearance(0), kToolbarHeight + 20);
    expect(
      readerGlassTopClearance(24, searchHits: true),
      24 + 8 + kToolbarHeight + 12 + 48,
    );
  });

  test('study time stays in minutes under an hour and uses hours after', () {
    expect(formatStudyMinutes(59, const Locale('en')), '59');
    expect(formatStudyMinutes(60, const Locale('en')), '1h');
    expect(formatStudyMinutes(70, const Locale('en')), '1h10min');
    expect(formatStudyMinutes(70, const Locale('fr')), '1h10min');
    expect(formatStudyMinutes(70, const Locale('ar')), isNot('70'));
  });
}
