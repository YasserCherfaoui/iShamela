import 'package:flutter_test/flutter_test.dart';
import 'package:ishamela/core/search/normalizer.dart';
import 'package:ishamela/core/search/normalizer_map.dart';
import 'package:ishamela/features/reader/book_database.dart';

void main() {
  test('buildBookFtsMatch quotes tokens without prefix star', () {
    expect(
      buildBookFtsMatch(normalize('ابن تيمية')),
      '"ابن" "تيميه"',
    );
    expect(buildBookFtsMatch('foo AND bar'), '"foo" "AND" "bar"');
    expect(buildBookFtsMatch('NEAR * "x"'), '"NEAR" "x"');
  });

  test('buildBookFtsMatch differs from catalog prefix MATCH', () {
    final q = normalize('علم');
    expect(buildBookFtsMatch(q), '"علم"');
    expect(buildBookFtsMatch(q).contains('*'), isFalse);
  });

  test('bookSearchSnippet windows around first hit', () {
    const body =
        'مقدمة الكتاب ثم يظهر العلم النافع في هذا الباب بعد كلام طويل';
    final nr = normalizeWithMap(body);
    final ranges = findHighlightRanges(nr, normalize('العلم'));
    expect(ranges, isNotEmpty);
    final snip = bookSearchSnippet(body, ranges, words: 3);
    expect(snip.contains('العلم'), isTrue);
    expect(snip.contains('مقدمة الكتاب ثم'), isFalse);
  });

  test('bookSearchSnippet strips HTML tags for display', () {
    const body =
        '<span data-type="title">عنوان</span> نص فيه كلمة الاختبار هنا بعد';
    final start = body.indexOf('الاختبار');
    final snip = bookSearchSnippet(body, [
      (start: start, end: start + 'الاختبار'.length),
    ], words: 4);
    expect(snip.contains('<'), isFalse);
    expect(snip.contains('الاختبار'), isTrue);
  });
}
