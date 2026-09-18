import 'package:flutter_test/flutter_test.dart';

import 'package:ishamela/features/reader/sticky_toc.dart';

void main() {
  test('stickyTocIndex tracks section and always picks one', () {
    const ids = [10, 20, 30];
    expect(stickyTocIndex(ids, 5), 0);
    expect(stickyTocIndex(ids, 10), 0);
    expect(stickyTocIndex(ids, 15), 0);
    expect(stickyTocIndex(ids, 20), 1);
    expect(stickyTocIndex(ids, 25), 1);
    expect(stickyTocIndex(ids, 30), 2);
    expect(stickyTocIndex(ids, 99), 2);
  });
}
