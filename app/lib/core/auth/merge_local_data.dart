import 'package:ishamela/core/db/state_database.dart';
import 'package:ishamela/core/models/models.dart';

/// Local rows captured before a verified merge (SPEC-022 §6).
class LocalUserDataSnapshot {
  const LocalUserDataSnapshot({
    required this.history,
    required this.bookmarks,
    required this.notes,
    required this.progress,
  });

  final List<Map<String, Object?>> history;
  final List<Map<String, Object?>> bookmarks;
  final List<Map<String, Object?>> notes;
  final List<Map<String, Object?>> progress;

  bool get isEmpty =>
      history.isEmpty &&
      bookmarks.isEmpty &&
      notes.isEmpty &&
      progress.isEmpty;
}

/// Builds a [LocalUserDataSnapshot] from public [StateDatabase] APIs.
///
/// Bookmarks/notes are collected per installed book; progress uses the latest
/// reading_state row when present. Full-table listing may land with Home/Profile.
LocalUserDataSnapshot snapshotLocalUserData(
  StateDatabase db, {
  Iterable<int> bookIds = const [],
}) {
  final history = db.listReadingHistory().map(_historyMap).toList();

  final bookmarks = <Map<String, Object?>>[];
  final notes = <Map<String, Object?>>[];
  for (final bookId in bookIds) {
    for (final b in db.bookmarksForBook(bookId)) {
      bookmarks.add(_bookmarkMap(b));
    }
    for (final n in db.notesForBook(bookId)) {
      notes.add({
        'id': n['id'],
        'book_id': bookId,
        'page_id': n['page_id'],
        'start_offset': n['start_offset'],
        'end_offset': n['end_offset'],
        'note': n['note'],
        'updatedAt': n['created_at'],
      });
    }
  }

  final progress = <Map<String, Object?>>[];
  final latest = db.latestReadingState();
  if (latest != null) {
    progress.add({
      'book_id': latest.bookId,
      'page_id': latest.pageId,
      'updatedAt': latest.updatedAt,
    });
  }

  return LocalUserDataSnapshot(
    history: history,
    bookmarks: bookmarks,
    notes: notes,
    progress: progress,
  );
}

Map<String, Object?> _historyMap(ReadingHistoryEntry e) => {
      'id': e.id,
      'book_id': e.bookId,
      'part': e.part,
      'page_id': e.pageId,
      'print_page': e.printPage,
      'section_title': e.sectionTitle,
      'opened_at': e.openedAt,
      'closed_at': e.closedAt,
      'updatedAt': e.closedAt ?? e.openedAt,
    };

Map<String, Object?> _bookmarkMap(Bookmark b) => {
      'id': b.id,
      'book_id': b.bookId,
      'part': b.part,
      'page_id': b.pageId,
      'print_page': b.printPage,
      'label': b.label,
      'updatedAt': b.createdAt,
    };
