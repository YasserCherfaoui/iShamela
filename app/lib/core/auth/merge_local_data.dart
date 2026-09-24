import 'package:ishamela/core/db/state_database.dart';
import 'package:ishamela/core/models/models.dart';

/// Local rows captured before a verified merge (SPEC-022 §6).
class LocalUserDataSnapshot {
  const LocalUserDataSnapshot({
    required this.history,
    required this.bookmarks,
    required this.notes,
    required this.highlights,
    required this.progress,
  });

  final List<Map<String, Object?>> history;
  final List<Map<String, Object?>> bookmarks;
  final List<Map<String, Object?>> notes;
  final List<Map<String, Object?>> highlights;
  final List<Map<String, Object?>> progress;

  bool get isEmpty =>
      history.isEmpty &&
      bookmarks.isEmpty &&
      notes.isEmpty &&
      highlights.isEmpty &&
      progress.isEmpty;
}

/// Builds a [LocalUserDataSnapshot] from public [StateDatabase] APIs.
///
/// Bookmarks/notes are collected per installed book. Progress is every
/// `reading_state` row so closing one book does not drop the others.
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

  final highlights = [
    for (final h in db.listHighlights())
      _highlightMap(
        bookId: h['book_id'] as int,
        pageId: h['page_id'] as int,
        start: h['start_offset'] as int,
        end: h['end_offset'] as int,
        color: h['color'] as String,
        updatedAt: h['created_at'] as int,
        deleted: false,
      ),
    for (final h in db.listHighlightDeletions())
      _highlightMap(
        bookId: h['book_id'] as int,
        pageId: h['page_id'] as int,
        start: h['start_offset'] as int,
        end: h['end_offset'] as int,
        color: h['color'] as String,
        updatedAt: h['deleted_at'] as int,
        deleted: true,
      ),
  ];

  final progress = [
    for (final row in db.listReadingStates())
      {
        'book_id': row.bookId,
        'page_id': row.pageId,
        'updatedAt': row.updatedAt,
      },
  ];

  return LocalUserDataSnapshot(
    history: history,
    bookmarks: bookmarks,
    notes: notes,
    highlights: highlights,
    progress: progress,
  );
}

/// Stable across devices. Local sqlite ids are not.
String highlightSyncId({
  required int bookId,
  required int pageId,
  required int start,
  required int end,
  required String color,
}) => '$bookId|$pageId|$start|$end|$color';

Map<String, Object?> _highlightMap({
  required int bookId,
  required int pageId,
  required int start,
  required int end,
  required String color,
  required int updatedAt,
  required bool deleted,
}) => {
  'id': highlightSyncId(
    bookId: bookId,
    pageId: pageId,
    start: start,
    end: end,
    color: color,
  ),
  'book_id': bookId,
  'page_id': pageId,
  'start_offset': start,
  'end_offset': end,
  'color': color,
  'deleted': deleted,
  'updatedAt': updatedAt,
};

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

int? _asInt(Object? v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v);
  return null;
}

/// Writes remote history, progress, and highlights into SQLite.
void applyPulledReading(
  StateDatabase db, {
  required List<Map<String, dynamic>> history,
  required List<Map<String, dynamic>> progress,
  List<Map<String, dynamic>> highlights = const [],
}) {
  for (final row in history) {
    final bookId = _asInt(row['book_id']);
    final pageId = _asInt(row['page_id']);
    final opened = _asInt(row['opened_at']) ?? _asInt(row['updatedAt']);
    if (bookId == null || pageId == null || opened == null) continue;
    db.importSyncedHistory(
      bookId: bookId,
      pageId: pageId,
      openedAt: opened,
      part: row['part'] as String?,
      printPage: _asInt(row['print_page']),
      sectionTitle: row['section_title'] as String?,
      closedAt: _asInt(row['closed_at']),
      durationSeconds: _asInt(row['duration_seconds']),
    );
  }
  for (final row in progress) {
    final bookId = _asInt(row['book_id']) ?? _asInt(row['id']);
    final pageId = _asInt(row['page_id']);
    final updated = _asInt(row['updatedAt']);
    if (bookId == null || pageId == null || updated == null) continue;
    db.applyRemoteProgress(
      bookId: bookId,
      pageId: pageId,
      updatedAt: updated,
      printPage: _asInt(row['print_page']),
      part: row['part'] as String?,
      sectionTitle: row['section_title'] as String?,
    );
  }
  for (final row in highlights) {
    final bookId = _asInt(row['book_id']);
    final pageId = _asInt(row['page_id']);
    final start = _asInt(row['start_offset']);
    final end = _asInt(row['end_offset']);
    final updated = _asInt(row['updatedAt']);
    final color = row['color'];
    if (bookId == null ||
        pageId == null ||
        start == null ||
        end == null ||
        updated == null ||
        color is! String ||
        color.isEmpty) {
      continue;
    }
    db.applyRemoteHighlight(
      bookId: bookId,
      pageId: pageId,
      start: start,
      end: end,
      color: color,
      updatedAt: updated,
      deleted: row['deleted'] == true,
    );
  }
}
