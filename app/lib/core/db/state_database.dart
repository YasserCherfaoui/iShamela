import 'package:sqlite3/sqlite3.dart';

import 'package:ishamela/core/db/paths.dart';
import 'package:ishamela/core/models/models.dart';

/// Read-write app-state database (SPEC-004 / SPEC-005 reading_state).
class StateDatabase {
  StateDatabase(this._db);

  final Database _db;

  static Future<StateDatabase> open(AppPaths paths) async {
    final db = sqlite3.open(paths.stateSqlite.path);
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
  }) {
    _db.execute(
      '''
      INSERT INTO installed_books
        (book_id, schema_version, norm_version, sqlite_bytes, installed_at, page_count)
      VALUES (?, ?, ?, ?, ?, ?)
      ON CONFLICT(book_id) DO UPDATE SET
        schema_version=excluded.schema_version,
        norm_version=excluded.norm_version,
        sqlite_bytes=excluded.sqlite_bytes,
        installed_at=excluded.installed_at,
        page_count=excluded.page_count
      ''',
      [bookId, schemaVersion, normVersion, sqliteBytes, installedAt, pageCount],
    );
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
          'SELECT id, start_offset, end_offset, note, created_at '
          'FROM text_notes WHERE book_id = ? AND page_id = ? '
          'ORDER BY created_at ASC',
          [bookId, pageId],
        )
        .map((r) => Map<String, Object?>.from(r))
        .toList();
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
}

