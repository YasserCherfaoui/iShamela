import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:ishamela/core/auth/merge_local_data.dart';
import 'package:ishamela/core/db/paths.dart';
import 'package:ishamela/core/db/state_database.dart';

Future<StateDatabase> _openTemp() async {
  final dir = await Directory.systemTemp.createTemp('ishamela-sync-');
  final paths = AppPaths(p.join(dir.path, 'ishamela'));
  await paths.ensureLayout();
  return StateDatabase.open(paths);
}

void main() {
  test(
    'snapshot includes every reading position, not only the latest',
    () async {
      final state = await _openTemp();
      state.upsertReadingState(bookId: 1, pageId: 10, updatedAt: 100);
      state.upsertReadingState(bookId: 2, pageId: 20, updatedAt: 200);
      final snap = snapshotLocalUserData(state);
      final ids = snap.progress.map((row) => row['book_id']).toSet();
      expect(ids, {1, 2});
      state.close();
    },
  );

  test('remote progress replaces a local row only when it is newer', () async {
    final state = await _openTemp();
    state.upsertReadingState(bookId: 7, pageId: 3, updatedAt: 500);
    final kept = state.applyRemoteProgress(
      bookId: 7,
      pageId: 9,
      updatedAt: 400,
    );
    expect(kept, isFalse);
    expect(state.readingPageId(7), 3);

    final applied = state.applyRemoteProgress(
      bookId: 7,
      pageId: 11,
      updatedAt: 800,
    );
    expect(applied, isTrue);
    expect(state.readingPageId(7), 11);
    state.close();
  });
}
