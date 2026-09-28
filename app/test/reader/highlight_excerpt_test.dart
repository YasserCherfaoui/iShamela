import 'package:flutter_test/flutter_test.dart';
import 'package:ishamela/features/reader/highlight_excerpt.dart';

void main() {
  test('strips tags and collapses whitespace without changing the body', () {
    const body = '  <b>علم</b><br>  الفقه  ';
    expect(highlightListExcerpt(body, 0, body.length), 'علم الفقه');
    expect(body, '  <b>علم</b><br>  الفقه  ');
  });

  test('clamps offsets past the end of the body', () {
    const body = 'كتاب';
    expect(highlightListExcerpt(body, 2, 40), 'اب');
    expect(highlightListExcerpt(body, 9, 12), '');
  });

  test('keeps inner text of a title span', () {
    const body = '<span data-type="title">باب الإيمان</span>';
    expect(highlightListExcerpt(body, 0, body.length), 'باب الإيمان');
  });
}
