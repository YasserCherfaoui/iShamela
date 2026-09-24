import 'package:flutter_test/flutter_test.dart';

import 'package:ishamela/core/auth/reading_diff.dart';

void main() {
  test('same page is not a difference', () {
    final diffs = diffReadingProgress(
      local: [(bookId: 1, pageId: 10, updatedAt: 5)],
      remote: [
        {'book_id': 1, 'page_id': 10, 'updatedAt': 9},
      ],
    );
    expect(diffs, isEmpty);
  });

  test('lists only-local, only-remote, and the newer side', () {
    final diffs = diffReadingProgress(
      local: [
        (bookId: 1, pageId: 4, updatedAt: 100),
        (bookId: 2, pageId: 8, updatedAt: 50),
        (bookId: 4, pageId: 1, updatedAt: 10),
      ],
      remote: [
        {'id': '2', 'page_id': 9, 'updatedAt': 80},
        {'book_id': 3, 'page_id': 3, 'updatedAt': 1},
        {'book_id': 4, 'page_id': 1, 'updatedAt': 1},
      ],
    );
    expect(diffs.map((d) => d.bookId), [1, 2, 3]);
    expect(diffs[0].kind, ReadingDiffKind.localOnly);
    expect(diffs[1].kind, ReadingDiffKind.remoteNewer);
    expect(diffs[1].localPageId, 8);
    expect(diffs[1].remotePageId, 9);
    expect(diffs[2].kind, ReadingDiffKind.remoteOnly);
  });
}
