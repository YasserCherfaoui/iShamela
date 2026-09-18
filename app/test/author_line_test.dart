import 'package:flutter_test/flutter_test.dart';

import 'package:ishamela/core/author_line.dart';

void main() {
  test('formatAuthorLine appends Hijri death year', () {
    expect(formatAuthorLine(null, 500), isNull);
    expect(formatAuthorLine('', 500), isNull);
    expect(formatAuthorLine('أحمد', null), 'أحمد');
    expect(formatAuthorLine('أحمد', 241), 'أحمد · ت 241هـ');
  });
}
