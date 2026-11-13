import 'package:flutter_test/flutter_test.dart';
import 'package:ishamela/core/search/normalizer.dart';
import 'package:ishamela/core/search/normalizer_map.dart';

void main() {
  test(
    'normalizeWithMap highlights exact word despite HTML tags, tashkil, hamza, and punctuation',
    () {
      const body =
          '<span data-type="title">بَابُ العِلْمِ</span>، وَفِيهِ مَسْأَلَةٌ: '
          'قَالَ الشَّيْخُ «رَحِمَهُ اللَّهُ» فِي جُزْءٍ ١٢: التَّوْحِيدُ أَصْلُ الدِّينِ.';

      final nr = normalizeWithMap(body);
      expect(nr.norm, normalize(body));

      final ranges = findHighlightRanges(nr, normalize('التوحيد'));
      expect(ranges, hasLength(1));
      final matched = body.substring(ranges.first.start, ranges.first.end);
      expect(matched, 'التَّوْحِيد');
      expect(normalize(matched), normalize('التوحيد'));
    },
  );

  test('normalizeWithMap handles standalone hamza and folded forms', () {
    const body = 'المسألةُ في الماءِ، والمؤمنُ يسألُ عن الشَّيْءِ.';
    final nr = normalizeWithMap(body);
    expect(nr.norm, normalize(body));

    final ranges = findHighlightRanges(nr, normalize('الماء'));
    expect(ranges, hasLength(1));
    final matched = body.substring(ranges.first.start, ranges.first.end);
    expect(matched, 'الما');
    expect(normalize(matched), normalize('الماء'));
  });
}
