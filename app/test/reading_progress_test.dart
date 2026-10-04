import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:ishamela/core/db/paths.dart';
import 'package:ishamela/core/db/state_database.dart';

Future<StateDatabase> _openTemp() async {
  final dir = await Directory.systemTemp.createTemp('ishamela-progress-');
  final paths = AppPaths(p.join(dir.path, 'ishamela'));
  await paths.ensureLayout();
  return StateDatabase.open(paths);
}

void main() {
  test(
    'reopen uses the viewport, and progress stays on the qualified page',
    () async {
      final state = await _openTemp();
      state.commitQualifiedProgress(bookId: 3, page: 2, progressAt: 10);
      state.upsertBookSession(bookId: 3, page: 80, updatedAt: 20);
      expect(state.viewportPageId(3), 80);
      expect(state.readingProgressPage(3), 2);
      state.close();
    },
  );

  test(
    'a bookmark, a note, and a history open each enqueue a change',
    () async {
      final state = await _openTemp();
      state.insertBookmark(bookId: 3, pageId: 4, createdAt: 10, printPage: 4);
      state.insertNote(
        bookId: 3,
        pageId: 4,
        start: 0,
        end: 2,
        note: 'هامش',
        createdAt: 11,
      );
      state.touchReadingHistory(bookId: 3, pageId: 4, nowMs: 12, printPage: 4);
      final tables = state.listOutbox().map((row) => row.tableName).toSet();
      expect(
        tables,
        containsAll(['bookmarks', 'notes', 'reading_history_events']),
      );
      state.close();
    },
  );

  test('sign-in replay replaces the outbox with every local row', () async {
    final state = await _openTemp();
    state.commitQualifiedProgress(bookId: 3, page: 9, progressAt: 100);
    state.insertBookmark(bookId: 3, pageId: 4, createdAt: 10, printPage: 4);
    state.prepareSignInReplay(
      deviceId: '11111111-1111-4111-8111-111111111111',
      nowMs: 200,
    );
    expect(state.syncMeta('device_id'), '11111111-1111-4111-8111-111111111111');
    final kinds = state.listOutbox().map((row) => row.kind).toList();
    expect(kinds, contains('beacon'));
    expect(kinds, contains('change'));
    state.clearSyncSession();
    expect(state.listOutbox(), isEmpty);
    expect(state.syncMeta('device_id'), isNull);
    expect(state.readingProgressPage(3), 9);
    state.close();
  });

  test(
    'qualifying writes progress and a beacon, and an older page does not win',
    () async {
      final state = await _openTemp();
      state.commitQualifiedProgress(bookId: 3, page: 9, progressAt: 100);
      expect(state.readingProgressPage(3), 9);
      final outbox = state.listOutbox();
      expect(outbox, hasLength(1));
      expect(outbox.single.kind, 'beacon');
      expect(outbox.single.recordKey, '3');

      state.commitQualifiedProgress(bookId: 3, page: 1, progressAt: 50);
      expect(state.readingProgressPage(3), 9);
      expect(state.listOutbox(), hasLength(1));
      state.close();
    },
  );

  test('sign-in replay then pull keeps the newer progress_at', () async {
    final state = await _openTemp();
    state.commitQualifiedProgress(bookId: 3, page: 9, progressAt: 100);
    state.prepareSignInReplay(
      deviceId: '11111111-1111-4111-8111-111111111111',
      nowMs: 200,
    );
    expect(
      state.applyPulledChange(
        table: 'reading_progress',
        record: {'book_id': 3, 'page': 1, 'progress_at': 50},
      ),
      isFalse,
    );
    expect(state.readingProgressPage(3), 9);
    expect(
      state.applyPulledChange(
        table: 'reading_progress',
        record: {'book_id': 3, 'page': 40, 'progress_at': 300},
      ),
      isTrue,
    );
    expect(state.readingProgressPage(3), 40);
    state.close();
  });
}
