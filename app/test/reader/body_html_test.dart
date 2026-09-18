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
}
