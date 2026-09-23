import 'package:flutter_test/flutter_test.dart';

import 'package:ishamela/core/arabic_digits.dart';

void main() {
  test('toArabicIndicDigits maps western digits', () {
    expect(toArabicIndicDigits(0), '٠');
    expect(toArabicIndicDigits(42), '٤٢');
    expect(toArabicIndicDigits(100), '١٠٠');
  });

  test('arabicPercent formats with ٪', () {
    expect(arabicPercent(42), '٪٤٢');
    expect(arabicPercent(150), '٪١٠٠');
  });
}
