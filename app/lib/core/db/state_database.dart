import 'package:ishamela/core/db/app_fs.dart';
import 'package:ishamela/core/db/sqlite_api.dart';

import 'package:ishamela/core/db/paths.dart';
import 'package:ishamela/core/models/models.dart';

/// Read-write app-state database (SPEC-004 / SPEC-005 reading_state).
class StateDatabase {
  StateDatabase(this._db);

  final AppDatabase _db;

  static Future<StateDatabase> open(AppPaths paths) async {
    final db = openAppDatabase(paths.stateSqlite);
    db.execute('PRAGMA foreign_keys = ON');
    final version =
        db.select('PRAGMA user_version').first.columnAt(0) as int;
    if (version < 1) {
      db.execute('''
        CREATE TABLE IF NOT EXISTS downloads (
          book_id INTEGER PRIMARY KEY,
          status TEXT NOT NULL CHECK (status IN (
            'queued','downloading','verifying','installing','done','error','paused'
          )),
          bytes_done INTEGER NOT NULL DEFAULT 0,
          bytes_total INTEGER,
          error TEXT,
          updated_at INTEGER NOT NULL
        )
      ''');
      db.execute('''
        CREATE TABLE IF NOT EXISTS installed_books (
          book_id INTEGER PRIMARY KEY,
          schema_version INTEGER NOT NULL,
          norm_version TEXT NOT NULL,
          sqlite_bytes INTEGER NOT NULL,
          installed_at INTEGER NOT NULL
        )
      ''');
      db.execute('PRAGMA user_version = 1');
    }
    final version2 =
        db.select('PRAGMA user_version').first.columnAt(0) as int;
    if (version2 < 2) {
      db.execute('''
        CREATE TABLE IF NOT EXISTS reading_state (
          book_id INTEGER PRIMARY KEY,
          page_id INTEGER NOT NULL,
          updated_at INTEGER NOT NULL
        )
      ''');
      db.execute('PRAGMA user_version = 2');
    }
    final version3 =
        db.select('PRAGMA user_version').first.columnAt(0) as int;
    if (version3 < 3) {
      db.execute('''
        CREATE TABLE IF NOT EXISTS settings (
          key TEXT PRIMARY KEY,
          value TEXT NOT NULL
        )
      ''');
      db.execute('PRAGMA user_version = 3');
    }
    final version4 =
        db.select('PRAGMA user_version').first.columnAt(0) as int;
    if (version4 < 4) {
      db.execute('''
        CREATE TABLE IF NOT EXISTS highlights (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          book_id INTEGER NOT NULL,
          page_id INTEGER NOT NULL,
          start_offset INTEGER NOT NULL,
          end_offset INTEGER NOT NULL,
          color TEXT NOT NULL,
          created_at INTEGER NOT NULL,
          CHECK (start_offset >= 0 AND end_offset > start_offset)
        )
      ''');
      db.execute('''
        CREATE TABLE IF NOT EXISTS text_notes (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          book_id INTEGER NOT NULL,
          page_id INTEGER NOT NULL,
          start_offset INTEGER NOT NULL,
          end_offset INTEGER NOT NULL,
          note TEXT NOT NULL,
          created_at INTEGER NOT NULL,
          CHECK (length(note) > 0)
        )
      ''');
      db.execute(
        'CREATE INDEX IF NOT EXISTS highlights_book_page '
        'ON highlights(book_id, page_id)',
      );
      db.execute(
        'CREATE INDEX IF NOT EXISTS text_notes_book_page '
        'ON text_notes(book_id, page_id)',
      );
      db.execute('PRAGMA user_version = 4');
    }
    final version5 =
        db.select('PRAGMA user_version').first.columnAt(0) as int;
    if (version5 < 5) {
      try {
        db.execute(
          'ALTER TABLE installed_books ADD COLUMN page_count INTEGER',
        );
      } catch (_) {
        // column may already exist
      }
      db.execute('PRAGMA user_version = 5');
    }
    final version6 =
        db.select('PRAGMA user_version').first.columnAt(0) as int;
    if (version6 < 6) {
      db.execute('''
        CREATE TABLE IF NOT EXISTS reading_history (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          book_id INTEGER NOT NULL,
          part TEXT,
          page_id INTEGER NOT NULL,
          print_page INTEGER,
          section_title TEXT,
          opened_at INTEGER NOT NULL,
          closed_at INTEGER
        )
      ''');
      db.execute(
        'CREATE INDEX IF NOT EXISTS reading_history_opened '
        'ON reading_history(opened_at DESC)',
      );
      db.execute(
        'CREATE INDEX IF NOT EXISTS reading_history_book '
        'ON reading_history(book_id, opened_at DESC)',
      );
      db.execute('''
        CREATE TABLE IF NOT EXISTS bookmarks (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          book_id INTEGER NOT NULL,
          part TEXT NOT NULL DEFAULT '',
          page_id INTEGER NOT NULL,
          print_page INTEGER,
          label TEXT,
          created_at INTEGER NOT NULL,
          UNIQUE(book_id, part, page_id)
        )
      ''');
      db.execute(
        'CREATE INDEX IF NOT EXISTS bookmarks_book '
        'ON bookmarks(book_id, created_at DESC)',
      );
      db.execute('PRAGMA user_version = 6');
    }
    final version7 =
        db.select('PRAGMA user_version').first.columnAt(0) as int;
    if (version7 < 7) {
      try {
        db.execute(
          'ALTER TABLE installed_books ADD COLUMN installed_size_bytes INTEGER',
        );
      } catch (_) {}
      db.execute(
        '''
        UPDATE installed_books
        SET installed_size_bytes = sqlite_bytes
        WHERE installed_size_bytes IS NULL
        ''',
      );
      db.execute('PRAGMA user_version = 7');
    }
    return StateDatabase(db);
  }

  void close() => _db.dispose();

  List<Map<String, Object?>> listDownloads() {
    return _db
        .select(
          'SELECT book_id, status, bytes_done, bytes_total, error, updated_at '
          'FROM downloads ORDER BY updated_at DESC',
        )
        .map((r) => Map<String, Object?>.from(r))
        .toList();
  }

  void upsertDownload({
    required int bookId,
    required String status,
    required int bytesDone,
    int? bytesTotal,
    String? error,
    required int updatedAt,
  }) {
    _db.execute(
      '''
      INSERT INTO downloads (book_id, status, bytes_done, bytes_total, error, updated_at)
      VALUES (?, ?, ?, ?, ?, ?)
      ON CONFLICT(book_id) DO UPDATE SET
        status=excluded.status,
        bytes_done=excluded.bytes_done,
        bytes_total=excluded.bytes_total,
        error=excluded.error,
        updated_at=excluded.updated_at
      ''',
      [bookId, status, bytesDone, bytesTotal, error, updatedAt],
    );
  }

  void deleteDownload(int bookId) {
    _db.execute('DELETE FROM downloads WHERE book_id = ?', [bookId]);
  }

  void upsertInstalled({
    required int bookId,
    required int schemaVersion,
    required String normVersion,
    required int sqliteBytes,
    required int installedAt,
    int? pageCount,
    int? installedSizeBytes,
  }) {
    final size = installedSizeBytes ?? sqliteBytes;
    _db.execute(
      '''
      INSERT INTO installed_books
        (book_id, schema_version, norm_version, sqlite_bytes, installed_at,
         page_count, installed_size_bytes)
      VALUES (?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT(book_id) DO UPDATE SET
        schema_version=excluded.schema_version,
        norm_version=excluded.norm_version,
        sqlite_bytes=excluded.sqlite_bytes,
        installed_at=excluded.installed_at,
        page_count=excluded.page_count,
        installed_size_bytes=excluded.installed_size_bytes
      ''',
      [
        bookId,
        schemaVersion,
        normVersion,
        sqliteBytes,
        installedAt,
        pageCount,
        size,
      ],
    );
  }

  int? installedSizeBytes(int bookId) {
    final rows = _db.select(
      'SELECT installed_size_bytes FROM installed_books WHERE book_id = ? LIMIT 1',
      [bookId],
    );
    if (rows.isEmpty) return null;
    return rows.first['installed_size_bytes'] as int?;
  }

  void setInstalledSizeBytes(int bookId, int bytes) {
    _db.execute(
      'UPDATE installed_books SET installed_size_bytes = ? WHERE book_id = ?',
      [bytes, bookId],
    );
  }

  /// Known sizes only (excludes NULL).
  int get installedSizeBytesTotal {
    final rows = _db.select(
      'SELECT COALESCE(SUM(installed_size_bytes), 0) AS total '
      'FROM installed_books WHERE installed_size_bytes IS NOT NULL',
    );
    return rows.first['total'] as int;
  }

  bool get hasUnknownInstalledSizes {
    final rows = _db.select(
      'SELECT 1 FROM installed_books WHERE installed_size_bytes IS NULL LIMIT 1',
    );
    return rows.isNotEmpty;
  }

  List<({int bookId, int? sizeBytes})> installedBooksBySizeDesc() {
    return _db
        .select(
          '''
          SELECT book_id, installed_size_bytes FROM installed_books
          ORDER BY installed_size_bytes DESC NULLS LAST, book_id ASC
          ''',
        )
        .map(
          (r) => (
            bookId: r['book_id'] as int,
            sizeBytes: r['installed_size_bytes'] as int?,
          ),
        )
        .toList();
  }

  List<int> installedBookIdsMissingSize() {
    return _db
        .select(
          'SELECT book_id FROM installed_books WHERE installed_size_bytes IS NULL',
        )
        .map((r) => r['book_id'] as int)
        .toList();
  }

  int? installedPageCount(int bookId) {
    final rows = _db.select(
      'SELECT page_count FROM installed_books WHERE book_id = ? LIMIT 1',
      [bookId],
    );
    if (rows.isEmpty) return null;
    return rows.first['page_count'] as int?;
  }

  void deleteInstalled(int bookId) {
    _db.execute('DELETE FROM installed_books WHERE book_id = ?', [bookId]);
    _db.execute('DELETE FROM reading_state WHERE book_id = ?', [bookId]);
  }

  bool isInstalled(int bookId) {
    final rows = _db.select(
      'SELECT 1 FROM installed_books WHERE book_id = ? LIMIT 1',
      [bookId],
    );
    return rows.isNotEmpty;
  }

  List<int> installedBookIds() {
    return _db
        .select('SELECT book_id FROM installed_books ORDER BY book_id')
        .map((r) => r['book_id'] as int)
        .toList();
  }

  int get installedSqliteBytesTotal {
    final rows = _db.select(
      'SELECT COALESCE(SUM(sqlite_bytes), 0) AS total FROM installed_books',
    );
    return rows.first['total'] as int;
  }

  DownloadStatus? downloadStatus(int bookId) {
    final rows = _db.select(
      'SELECT status FROM downloads WHERE book_id = ? LIMIT 1',
      [bookId],
    );
    if (rows.isEmpty) return null;
    return DownloadStatus.parse(rows.first['status'] as String);
  }

  int? readingPageId(int bookId) {
    final rows = _db.select(
      'SELECT page_id FROM reading_state WHERE book_id = ? LIMIT 1',
      [bookId],
    );
    if (rows.isEmpty) return null;
    return rows.first['page_id'] as int;
  }

  /// Most recently updated reading position (for continue-reading hero).
  ({int bookId, int pageId, int updatedAt})? latestReadingState() {
    final rows = _db.select(
      '''
      SELECT book_id, page_id, updated_at FROM reading_state
      ORDER BY updated_at DESC LIMIT 1
      ''',
    );
    if (rows.isEmpty) return null;
    final r = rows.first;
    return (
      bookId: r['book_id'] as int,
      pageId: r['page_id'] as int,
      updatedAt: r['updated_at'] as int,
    );
  }

  void upsertReadingState({
    required int bookId,
    required int pageId,
    required int updatedAt,
  }) {
    _db.execute(
      '''
      INSERT INTO reading_state (book_id, page_id, updated_at)
      VALUES (?, ?, ?)
      ON CONFLICT(book_id) DO UPDATE SET
        page_id=excluded.page_id,
        updated_at=excluded.updated_at
      ''',
      [bookId, pageId, updatedAt],
    );
  }

  String? setting(String key) {
    try {
      final rows = _db.select(
        'SELECT value FROM settings WHERE key = ? LIMIT 1',
        [key],
      );
      if (rows.isEmpty) return null;
      return rows.first['value'] as String;
    } catch (_) {
      return null;
    }
  }

  void setSetting(String key, String value) {
    _db.execute(
      '''
      INSERT INTO settings (key, value) VALUES (?, ?)
      ON CONFLICT(key) DO UPDATE SET value=excluded.value
      ''',
      [key, value],
    );
  }

  List<Map<String, Object?>> highlightsForPage(int bookId, int pageId) {
    return _db
        .select(
          'SELECT id, start_offset, end_offset, color, created_at '
          'FROM highlights WHERE book_id = ? AND page_id = ? '
          'ORDER BY created_at ASC',
          [bookId, pageId],
        )
        .map((r) => Map<String, Object?>.from(r))
        .toList();
  }

  List<Map<String, Object?>> highlightsForBook(int bookId) {
    return _db
        .select(
          'SELECT id, page_id, start_offset, end_offset, color, created_at '
          'FROM highlights WHERE book_id = ? '
          'ORDER BY page_id ASC, start_offset ASC, id ASC',
          [bookId],
        )
        .map((r) => Map<String, Object?>.from(r))
        .toList();
  }

  int annotationCountForBook(int bookId) {
    final h = _db.select(
      'SELECT COUNT(*) AS c FROM highlights WHERE book_id = ?',
      [bookId],
    );
    final n = _db.select(
      'SELECT COUNT(*) AS c FROM text_notes WHERE book_id = ?',
      [bookId],
    );
    return (h.first['c'] as int) + (n.first['c'] as int);
  }

  int insertHighlight({
    required int bookId,
    required int pageId,
    required int start,
    required int end,
    required String color,
    required int createdAt,
  }) {
    _db.execute(
      'INSERT INTO highlights '
      '(book_id, page_id, start_offset, end_offset, color, created_at) '
      'VALUES (?, ?, ?, ?, ?, ?)',
      [bookId, pageId, start, end, color, createdAt],
    );
    return _db.lastInsertRowId;
  }

  void deleteHighlight(int id) {
    _db.execute('DELETE FROM highlights WHERE id = ?', [id]);
  }

  List<Map<String, Object?>> notesForPage(int bookId, int pageId) {
    return _db
        .select(
          'SELECT id, page_id, start_offset, end_offset, note, created_at '
          'FROM text_notes WHERE book_id = ? AND page_id = ? '
          'ORDER BY start_offset ASC, id ASC',
          [bookId, pageId],
        )
        .map((r) => Map<String, Object?>.from(r))
        .toList();
  }

  /// All notes for a book in SPEC-012 index order.
  List<Map<String, Object?>> notesForBook(int bookId) {
    return _db
        .select(
          'SELECT id, page_id, start_offset, end_offset, note, created_at '
          'FROM text_notes WHERE book_id = ? '
          'ORDER BY page_id ASC, start_offset ASC, id ASC',
          [bookId],
        )
        .map((r) => Map<String, Object?>.from(r))
        .toList();
  }

  /// 1-based note index for [noteId] within [bookId], or null if missing.
  int? noteIndex(int bookId, int noteId) {
    final all = notesForBook(bookId);
    for (var i = 0; i < all.length; i++) {
      if (all[i]['id'] == noteId) return i + 1;
    }
    return null;
  }

  int insertNote({
    required int bookId,
    required int pageId,
    required int start,
    required int end,
    required String note,
    required int createdAt,
  }) {
    _db.execute(
      'INSERT INTO text_notes '
      '(book_id, page_id, start_offset, end_offset, note, created_at) '
      'VALUES (?, ?, ?, ?, ?, ?)',
      [bookId, pageId, start, end, note, createdAt],
    );
    return _db.lastInsertRowId;
  }

  void updateNote(int id, String note) {
    _db.execute('UPDATE text_notes SET note = ? WHERE id = ?', [note, id]);
  }

  void deleteNote(int id) {
    _db.execute('DELETE FROM text_notes WHERE id = ?', [id]);
  }

  // --- SPEC-014 reading history & bookmarks ---

  static const historyCoalesce = Duration(minutes: 30);
  static const historyMaxAge = Duration(days: 90);
  static const historyMaxRows = 500;

  String _bookmarkPartKey(String? part) => part ?? '';

  /// Open or coalesce a history session; prune on insert. Spec-testable windows.
  int touchReadingHistory({
    required int bookId,
    required int pageId,
    required int nowMs,
    String? part,
    int? printPage,
    String? sectionTitle,
    bool closing = false,
    Duration coalesceWindow = historyCoalesce,
    Duration maxAge = historyMaxAge,
    int maxRows = historyMaxRows,
  }) {
    final newest = _db.select(
      '''
      SELECT id, opened_at FROM reading_history
      WHERE book_id = ?
      ORDER BY opened_at DESC LIMIT 1
      ''',
      [bookId],
    );
    final closedAt = closing ? nowMs : null;
    if (newest.isNotEmpty) {
      final openedAt = newest.first['opened_at'] as int;
      if (nowMs - openedAt <= coalesceWindow.inMilliseconds) {
        final id = newest.first['id'] as int;
        _db.execute(
          '''
          UPDATE reading_history SET
            part = ?, page_id = ?, print_page = ?, section_title = ?,
            closed_at = ?
          WHERE id = ?
          ''',
          [part, pageId, printPage, sectionTitle, closedAt, id],
        );
        return id;
      }
    }
    _db.execute(
      '''
      INSERT INTO reading_history
        (book_id, part, page_id, print_page, section_title, opened_at, closed_at)
      VALUES (?, ?, ?, ?, ?, ?, ?)
      ''',
      [bookId, part, pageId, printPage, sectionTitle, nowMs, closedAt],
    );
    final id = _db.lastInsertRowId;
    _pruneReadingHistory(nowMs: nowMs, maxAge: maxAge, maxRows: maxRows);
    return id;
  }

  void _pruneReadingHistory({
    required int nowMs,
    required Duration maxAge,
    required int maxRows,
  }) {
    final cutoff = nowMs - maxAge.inMilliseconds;
    _db.execute(
      'DELETE FROM reading_history WHERE opened_at < ?',
      [cutoff],
    );
    final count =
        _db.select('SELECT COUNT(*) AS n FROM reading_history').first['n']
            as int;
    if (count <= maxRows) return;
    final overflow = count - maxRows;
    _db.execute(
      '''
      DELETE FROM reading_history WHERE id IN (
        SELECT id FROM reading_history ORDER BY opened_at ASC LIMIT ?
      )
      ''',
      [overflow],
    );
  }

  List<ReadingHistoryEntry> listReadingHistory() {
    return _db
        .select(
          '''
          SELECT id, book_id, part, page_id, print_page, section_title,
                 opened_at, closed_at
          FROM reading_history ORDER BY opened_at DESC
          ''',
        )
        .map(_historyFromRow)
        .toList();
  }

  ReadingHistoryEntry? latestReadingHistory() {
    final rows = _db.select(
      '''
      SELECT id, book_id, part, page_id, print_page, section_title,
             opened_at, closed_at
      FROM reading_history ORDER BY opened_at DESC LIMIT 1
      ''',
    );
    if (rows.isEmpty) return null;
    return _historyFromRow(rows.first);
  }

  void clearReadingHistory() {
    _db.execute('DELETE FROM reading_history');
  }

  void deleteReadingHistory(int id) {
    _db.execute('DELETE FROM reading_history WHERE id = ?', [id]);
  }

  ReadingHistoryEntry _historyFromRow(Row r) {
    return ReadingHistoryEntry(
      id: r['id'] as int,
      bookId: r['book_id'] as int,
      part: r['part'] as String?,
      pageId: r['page_id'] as int,
      printPage: r['print_page'] as int?,
      sectionTitle: r['section_title'] as String?,
      openedAt: r['opened_at'] as int,
      closedAt: r['closed_at'] as int?,
    );
  }

  List<Bookmark> bookmarksForBook(int bookId) {
    return _db
        .select(
          '''
          SELECT id, book_id, part, page_id, print_page, label, created_at
          FROM bookmarks WHERE book_id = ?
          ORDER BY created_at DESC
          ''',
          [bookId],
        )
        .map(_bookmarkFromRow)
        .toList();
  }

  Bookmark? bookmarkForPage({
    required int bookId,
    required int pageId,
    String? part,
  }) {
    final key = _bookmarkPartKey(part);
    final rows = _db.select(
      '''
      SELECT id, book_id, part, page_id, print_page, label, created_at
      FROM bookmarks WHERE book_id = ? AND part = ? AND page_id = ?
      LIMIT 1
      ''',
      [bookId, key, pageId],
    );
    if (rows.isEmpty) return null;
    return _bookmarkFromRow(rows.first);
  }

  bool isPageBookmarked({
    required int bookId,
    required int pageId,
    String? part,
  }) =>
      bookmarkForPage(bookId: bookId, pageId: pageId, part: part) != null;

  /// Returns the bookmark id when added, or null when removed.
  int? toggleBookmark({
    required int bookId,
    required int pageId,
    required int createdAt,
    String? part,
    int? printPage,
    String? label,
  }) {
    final existing = bookmarkForPage(
      bookId: bookId,
      pageId: pageId,
      part: part,
    );
    if (existing != null) {
      deleteBookmark(existing.id);
      return null;
    }
    return insertBookmark(
      bookId: bookId,
      pageId: pageId,
      part: part,
      printPage: printPage,
      label: label,
      createdAt: createdAt,
    );
  }

  int insertBookmark({
    required int bookId,
    required int pageId,
    required int createdAt,
    String? part,
    int? printPage,
    String? label,
  }) {
    final key = _bookmarkPartKey(part);
    _db.execute(
      '''
      INSERT INTO bookmarks
        (book_id, part, page_id, print_page, label, created_at)
      VALUES (?, ?, ?, ?, ?, ?)
      ''',
      [bookId, key, pageId, printPage, label, createdAt],
    );
    return _db.lastInsertRowId;
  }

  void updateBookmarkLabel(int id, String? label) {
    final stored =
        (label == null || label.trim().isEmpty) ? null : label.trim();
    _db.execute(
      'UPDATE bookmarks SET label = ? WHERE id = ?',
      [stored, id],
    );
  }

  void deleteBookmark(int id) {
    _db.execute('DELETE FROM bookmarks WHERE id = ?', [id]);
  }

  Bookmark _bookmarkFromRow(Row r) {
    return Bookmark(
      id: r['id'] as int,
      bookId: r['book_id'] as int,
      part: (r['part'] as String?) ?? '',
      pageId: r['page_id'] as int,
      printPage: r['print_page'] as int?,
      label: r['label'] as String?,
      createdAt: r['created_at'] as int,
    );
  }
}

