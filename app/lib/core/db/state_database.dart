import 'dart:io';

import 'package:sqlite3/sqlite3.dart';

import 'package:ishamela/core/db/paths.dart';

const _stateUserVersion = 1;

/// Read-write app-state database (SPEC-004).
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
        );
        CREATE TABLE IF NOT EXISTS installed_books (
          book_id INTEGER PRIMARY KEY,
          schema_version INTEGER NOT NULL,
          norm_version TEXT NOT NULL,
          sqlite_bytes INTEGER NOT NULL,
          installed_at INTEGER NOT NULL
        );
      ''');
      db.execute('PRAGMA user_version = $_stateUserVersion');
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
  }) {
    _db.execute(
      '''
      INSERT INTO installed_books
        (book_id, schema_version, norm_version, sqlite_bytes, installed_at)
      VALUES (?, ?, ?, ?, ?)
      ON CONFLICT(book_id) DO UPDATE SET
        schema_version=excluded.schema_version,
        norm_version=excluded.norm_version,
        sqlite_bytes=excluded.sqlite_bytes,
        installed_at=excluded.installed_at
      ''',
      [bookId, schemaVersion, normVersion, sqliteBytes, installedAt],
    );
  }

  void deleteInstalled(int bookId) {
    _db.execute('DELETE FROM installed_books WHERE book_id = ?', [bookId]);
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
}

Database openReadonlySqlite(File path) {
  final db = sqlite3.open(path.path, mode: OpenMode.readOnly);
  db.execute('PRAGMA query_only = ON');
  return db;
}
