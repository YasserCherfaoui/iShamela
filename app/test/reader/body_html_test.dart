import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ishamela/features/reader/body_html.dart';

void main() {
  test('HTML title span is not shown as raw tags', () {
    const raw =
        '<span data-type="title" id=toc-1>المقدمة</span>\nالحمد لله';
    final spans = parseBodySpans(raw);
    final text = spans.map((s) => s.toPlainText()).join();
    expect(text.contains('<span'), isFalse);
    expect(text.contains('المقدمة'), isTrue);
    expect(text.contains('الحمد'), isTrue);
  });

  test('nested non-title span does not clear outer title styling', () {
    const raw =
        '<span data-type="title">باب <span>الأول</span> في العلم</span>';
    final spans = parseBodySpans(raw).cast<TextSpan>();
    expect(spans, hasLength(3));
    for (final span in spans) {
      expect(span.style?.fontWeight, FontWeight.bold);
      expect(span.style?.fontSize, 22);
    }
  });

  test('nested bold tags keep bold until outer closing tag', () {
    const raw = '<b>أول <b>وسط</b> آخر</b> عادي';
    final spans = parseBodySpans(raw).cast<TextSpan>();
    expect(spans, hasLength(4));
    expect(spans[0].style?.fontWeight, FontWeight.bold);
    expect(spans[1].style?.fontWeight, FontWeight.bold);
    expect(spans[2].style?.fontWeight, FontWeight.bold);
    expect(spans[3].style?.fontWeight, isNot(FontWeight.bold));
  });
}
