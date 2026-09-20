import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:ishamela/core/db/paths.dart';
import 'package:ishamela/core/db/state_database.dart';

Future<StateDatabase> _openTemp() async {
  final dir = await Directory.systemTemp.createTemp('ishamela-hist-');
  final paths = AppPaths(p.join(dir.path, 'ishamela'));
  await paths.ensureLayout();
  return StateDatabase.open(paths);
}

void main() {
  test('user_version 6 creates reading_history and bookmarks', () async {
    final state = await _openTemp();
    final ver = state
        .listReadingHistory(); // table must exist
    expect(ver, isEmpty);
    expect(state.bookmarksForBook(1), isEmpty);
    // Touch + bookmark to prove schema
    state.touchReadingHistory(
      bookId: 1,
      pageId: 10,
      nowMs: 1_000_000,
      printPage: 5,
    );
    expect(state.listReadingHistory(), hasLength(1));
    state.insertBookmark(
      bookId: 1,
      pageId: 10,
      createdAt: 1_000_000,
      printPage: 5,
    );
    expect(state.isPageBookmarked(bookId: 1, pageId: 10), isTrue);
    state.close();
  });

  test('history coalesces within 30 min window', () async {
    final state = await _openTemp();
    const t0 = 1_000_000;
    final id1 = state.touchReadingHistory(
      bookId: 7,
      pageId: 1,
      nowMs: t0,
      printPage: 1,
      sectionTitle: 'أ',
    );
    final id2 = state.touchReadingHistory(
      bookId: 7,
      pageId: 2,
      nowMs: t0 + const Duration(minutes: 20).inMilliseconds,
      printPage: 2,
      sectionTitle: 'ب',
    );
    expect(id2, id1);
    expect(state.listReadingHistory(), hasLength(1));
    expect(state.listReadingHistory().first.pageId, 2);
    expect(state.listReadingHistory().first.sectionTitle, 'ب');

    state.touchReadingHistory(
      bookId: 7,
      pageId: 3,
      nowMs: t0 + const Duration(minutes: 31).inMilliseconds,
      printPage: 3,
    );
    expect(state.listReadingHistory(), hasLength(2));
    state.close();
  });

  test('history prune by age and max rows', () async {
    final state = await _openTemp();
    const now = 10_000_000;
    // Age prune: one old row for book 1
    state.touchReadingHistory(
      bookId: 1,
      pageId: 1,
      nowMs: now - const Duration(days: 100).inMilliseconds,
      maxAge: const Duration(days: 90),
      maxRows: 500,
    );
    // Force insert (different book) that triggers prune
    state.touchReadingHistory(
      bookId: 2,
      pageId: 1,
      nowMs: now,
      maxAge: const Duration(days: 90),
      maxRows: 500,
    );
    expect(
      state.listReadingHistory().any((e) => e.bookId == 1),
      isFalse,
    );

    // Cap prune: 5 inserts with maxRows 3
    for (var i = 0; i < 5; i++) {
      state.touchReadingHistory(
        bookId: 100 + i,
        pageId: 1,
        nowMs: now + i * const Duration(hours: 1).inMilliseconds,
        maxAge: const Duration(days: 90),
        maxRows: 3,
      );
    }
    expect(state.listReadingHistory().length, lessThanOrEqualTo(3));
    state.close();
  });

  test('clear history leaves reading_state and bookmarks', () async {
    final state = await _openTemp();
    state.upsertReadingState(bookId: 1, pageId: 9, updatedAt: 1);
    state.touchReadingHistory(bookId: 1, pageId: 9, nowMs: 1);
    state.insertBookmark(bookId: 1, pageId: 9, createdAt: 1);
    state.clearReadingHistory();
    expect(state.listReadingHistory(), isEmpty);
    expect(state.readingPageId(1), 9);
    expect(state.isPageBookmarked(bookId: 1, pageId: 9), isTrue);
    state.close();
  });

  test('bookmark toggle unique on book/part/page', () async {
    final state = await _openTemp();
    final added = state.toggleBookmark(
      bookId: 1,
      pageId: 5,
      part: '2',
      printPage: 12,
      createdAt: 100,
    );
    expect(added, isNotNull);
    expect(state.isPageBookmarked(bookId: 1, pageId: 5, part: '2'), isTrue);
    // Same page different part = different bookmark
    state.toggleBookmark(
      bookId: 1,
      pageId: 5,
      part: null,
      createdAt: 101,
    );
    expect(state.bookmarksForBook(1), hasLength(2));
    // Toggle off
    final removed = state.toggleBookmark(
      bookId: 1,
      pageId: 5,
      part: '2',
      createdAt: 102,
    );
    expect(removed, isNull);
    expect(state.isPageBookmarked(bookId: 1, pageId: 5, part: '2'), isFalse);
    state.close();
  });

  test('null and empty part collide for bookmarks', () async {
    final state = await _openTemp();
    state.insertBookmark(bookId: 1, pageId: 1, part: null, createdAt: 1);
    expect(
      () => state.insertBookmark(
        bookId: 1,
        pageId: 1,
        part: '',
        createdAt: 2,
      ),
      throwsA(anything),
    );
    state.close();
  });

  test('latestReadingHistory orders by opened_at', () async {
    final state = await _openTemp();
    state.touchReadingHistory(bookId: 1, pageId: 1, nowMs: 100);
    state.touchReadingHistory(bookId: 2, pageId: 2, nowMs: 200);
    expect(state.latestReadingHistory()?.bookId, 2);
    state.close();
  });
}

// groupHistoryByDay lives in history_page.dart — covered via widget/manual use.
