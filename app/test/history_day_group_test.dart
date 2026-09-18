import 'package:flutter_test/flutter_test.dart';

import 'package:ishamela/core/models/models.dart';
import 'package:ishamela/features/library/history_page.dart';

void main() {
  test('groupHistoryByDay buckets local calendar days', () {
    final now = DateTime(2026, 9, 18, 15);
    final today = DateTime(2026, 9, 18, 10).millisecondsSinceEpoch;
    final yesterday = DateTime(2026, 9, 17, 10).millisecondsSinceEpoch;
    final thisWeek = DateTime(2026, 9, 15, 10).millisecondsSinceEpoch;
    final older = DateTime(2026, 8, 1, 10).millisecondsSinceEpoch;
    ReadingHistoryEntry e(int id, int at) => ReadingHistoryEntry(
          id: id,
          bookId: id,
          pageId: 1,
          openedAt: at,
        );
    final groups = groupHistoryByDay(
      [e(1, today), e(2, yesterday), e(3, thisWeek), e(4, older)],
      now,
    );
    expect(groups.map((g) => g.key), [
      HistoryDayBucket.today,
      HistoryDayBucket.yesterday,
      HistoryDayBucket.thisWeek,
      HistoryDayBucket.older,
    ]);
  });
}
