import 'dart:convert';

import 'package:ishamela/core/db/app_fs.dart';
import 'package:ishamela/core/db/sqlite_api.dart';

import 'package:ishamela/core/db/paths.dart';
import 'package:ishamela/core/models/models.dart';
import 'package:ishamela/core/sync/sync_drain.dart';
import 'package:ishamela/core/sync/uuid_v5.dart';

/// Read-write app-state database (SPEC-004 / SPEC-005 reading_state).
class StateDatabase {
  StateDatabase(this._db);

  final AppDatabase _db;

  /// Fired after a synced row is appended to the outbox. The scheduler nudges.
  void Function()? onWrite;

  static Future<StateDatabase> open(AppPaths paths) async {
    final db = openAppDatabase(paths.stateSqlite);
    db.execute('PRAGMA foreign_keys = ON');
    try {
      db.execute('PRAGMA journal_mode=WAL');
      db.execute('PRAGMA synchronous=NORMAL');
    } catch (_) {
      // WASM builds may reject WAL. The default journal still persists rows.
    }
    final version = db.select('PRAGMA user_version').first.columnAt(0) as int;
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
    final version2 = db.select('PRAGMA user_version').first.columnAt(0) as int;
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
    final version3 = db.select('PRAGMA user_version').first.columnAt(0) as int;
    if (version3 < 3) {
      db.execute('''
        CREATE TABLE IF NOT EXISTS settings (
          key TEXT PRIMARY KEY,
          value TEXT NOT NULL
        )
      ''');
      db.execute('PRAGMA user_version = 3');
    }
    final version4 = db.select('PRAGMA user_version').first.columnAt(0) as int;
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
    final version5 = db.select('PRAGMA user_version').first.columnAt(0) as int;
    if (version5 < 5) {
      try {
        db.execute('ALTER TABLE installed_books ADD COLUMN page_count INTEGER');
      } catch (_) {
        // column may already exist
      }
      db.execute('PRAGMA user_version = 5');
    }
    final version6 = db.select('PRAGMA user_version').first.columnAt(0) as int;
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
    final version7 = db.select('PRAGMA user_version').first.columnAt(0) as int;
    if (version7 < 7) {
      try {
        db.execute(
          'ALTER TABLE installed_books ADD COLUMN installed_size_bytes INTEGER',
        );
      } catch (_) {}
      db.execute('''
        UPDATE installed_books
        SET installed_size_bytes = sqlite_bytes
        WHERE installed_size_bytes IS NULL
        ''');
      db.execute('PRAGMA user_version = 7');
    }
    final version8 = db.select('PRAGMA user_version').first.columnAt(0) as int;
    if (version8 < 8) {
      // SPEC-023: session duration + sync_state for Home / Profile.
      try {
        db.execute(
          'ALTER TABLE reading_history ADD COLUMN duration_seconds INTEGER',
        );
      } catch (_) {
        // column may already exist
      }
      db.execute('''
        CREATE TABLE IF NOT EXISTS sync_state (
          id INTEGER PRIMARY KEY CHECK (id = 1),
          last_synced_at INTEGER,
          last_error TEXT,
          cellular_allowed INTEGER NOT NULL DEFAULT 1
        )
      ''');
      db.execute(
        'INSERT OR IGNORE INTO sync_state (id, cellular_allowed) VALUES (1, 1)',
      );
      db.execute('PRAGMA user_version = 8');
    }
    final version9 = db.select('PRAGMA user_version').first.columnAt(0) as int;
    if (version9 < 9) {
      // SPEC-025: library exclusions + auto-download toggle.
      try {
        db.execute(
          'ALTER TABLE sync_state ADD COLUMN auto_download INTEGER NOT NULL DEFAULT 1',
        );
      } catch (_) {}
      db.execute(
        'CREATE TABLE IF NOT EXISTS library_exclusions (book_id INTEGER PRIMARY KEY)',
      );
      db.execute('''
        CREATE TABLE IF NOT EXISTS library_marks (
          book_id INTEGER PRIMARY KEY,
          deferred INTEGER NOT NULL DEFAULT 0,
          held INTEGER NOT NULL DEFAULT 0,
          unavailable INTEGER NOT NULL DEFAULT 0,
          auto_sync INTEGER NOT NULL DEFAULT 0
        )
      ''');
      db.execute('PRAGMA user_version = 9');
    }
    final version10 = db.select('PRAGMA user_version').first.columnAt(0) as int;
    if (version10 < 10) {
      db.execute('''
        CREATE TABLE IF NOT EXISTS highlight_deletions (
          book_id INTEGER NOT NULL,
          page_id INTEGER NOT NULL,
          start_offset INTEGER NOT NULL,
          end_offset INTEGER NOT NULL,
          color TEXT NOT NULL,
          deleted_at INTEGER NOT NULL,
          PRIMARY KEY (book_id, page_id, start_offset, end_offset, color)
        )
      ''');
      db.execute('PRAGMA user_version = 10');
    }
    final version11 = db.select('PRAGMA user_version').first.columnAt(0) as int;
    if (version11 < 11) {
      // SPEC-028: viewport, qualified progress, outbox. Existing positions
      // are copied so continue-reading survives the upgrade.
      db.execute('''
        CREATE TABLE IF NOT EXISTS book_session (
          book_id INTEGER PRIMARY KEY,
          page INTEGER NOT NULL,
          volume INTEGER,
          scroll_offset REAL,
          updated_at INTEGER NOT NULL
        )
      ''');
      db.execute('''
        CREATE TABLE IF NOT EXISTS reading_progress (
          book_id INTEGER PRIMARY KEY,
          page INTEGER NOT NULL,
          volume INTEGER,
          scroll_offset REAL,
          progress_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL,
          deleted_at INTEGER,
          server_seq INTEGER,
          device_id TEXT,
          sync_state TEXT NOT NULL DEFAULT 'pending'
            CHECK (sync_state IN ('synced','pending','conflict'))
        )
      ''');
      db.execute('''
        CREATE TABLE IF NOT EXISTS bookshelf_sync (
          book_id INTEGER PRIMARY KEY,
          added_at INTEGER NOT NULL,
          removed_everywhere INTEGER NOT NULL DEFAULT 0,
          updated_at INTEGER NOT NULL,
          deleted_at INTEGER,
          server_seq INTEGER,
          device_id TEXT,
          sync_state TEXT NOT NULL DEFAULT 'pending'
            CHECK (sync_state IN ('synced','pending','conflict'))
        )
      ''');
      db.execute('''
        CREATE TABLE IF NOT EXISTS sync_outbox (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          kind TEXT NOT NULL CHECK (kind IN ('beacon','change')),
          table_name TEXT,
          record_key TEXT,
          payload_json TEXT NOT NULL,
          created_at INTEGER NOT NULL,
          attempts INTEGER NOT NULL DEFAULT 0,
          last_error TEXT
        )
      ''');
      db.execute('''
        CREATE TABLE IF NOT EXISTS sync_meta (
          key TEXT PRIMARY KEY,
          value TEXT
        )
      ''');
      for (final table in ['bookmarks', 'text_notes', 'reading_history']) {
        try {
          db.execute('ALTER TABLE $table ADD COLUMN server_id TEXT');
        } catch (_) {}
      }
      db.execute('''
        INSERT OR IGNORE INTO book_session (book_id, page, updated_at)
        SELECT book_id, page_id, updated_at FROM reading_state
      ''');
      db.execute('''
        INSERT OR IGNORE INTO reading_progress
          (book_id, page, progress_at, updated_at, sync_state)
        SELECT book_id, page_id, updated_at, updated_at, 'pending'
        FROM reading_state
      ''');
      db.execute('PRAGMA user_version = 11');
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
    if (!libraryExclusionIds().contains(bookId)) {
      _enqueueShelf(bookId: bookId, addedAt: installedAt, removed: false);
    }
  }

  int? installedSizeBytes(int bookId) {
    final rows = _db.select(
      'SELECT installed_size_bytes FROM installed_books WHERE book_id = ? LIMIT 1',
      [bookId],
    );
    if (rows.isEmpty) return null;
    return rows.first['installed_size_bytes'] as int?;
  }

  int? installedAt(int bookId) {
    final rows = _db.select(
      'SELECT installed_at FROM installed_books WHERE book_id = ? LIMIT 1',
      [bookId],
    );
    if (rows.isEmpty) return null;
    return rows.first['installed_at'] as int?;
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
        .select('''
          SELECT book_id, installed_size_bytes FROM installed_books
          ORDER BY installed_size_bytes DESC NULLS LAST, book_id ASC
          ''')
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

  /// Every saved reading position, newest first. Sync uploads this list.
  List<({int bookId, int pageId, int updatedAt})> listReadingStates() {
    final rows = _db.select('''
      SELECT book_id, page_id, updated_at FROM reading_state
      ORDER BY updated_at DESC
      ''');
    return [
      for (final r in rows)
        (
          bookId: r['book_id'] as int,
          pageId: r['page_id'] as int,
          updatedAt: r['updated_at'] as int,
        ),
    ];
  }

  /// Most recently updated reading position (for continue-reading hero).
  ({int bookId, int pageId, int updatedAt})? latestReadingState() {
    final rows = _db.select('''
      SELECT book_id, page_id, updated_at FROM reading_state
      ORDER BY updated_at DESC LIMIT 1
      ''');
    if (rows.isEmpty) return null;
    final r = rows.first;
    return (
      bookId: r['book_id'] as int,
      pageId: r['page_id'] as int,
      updatedAt: r['updated_at'] as int,
    );
  }

  /// Page to reopen: last viewport, else qualified progress, else legacy state.
  int? viewportPageId(int bookId) =>
      bookSessionPage(bookId) ??
      readingProgressPage(bookId) ??
      readingPageId(bookId);

  int? bookSessionPage(int bookId) {
    final rows = _db.select(
      'SELECT page FROM book_session WHERE book_id = ? LIMIT 1',
      [bookId],
    );
    if (rows.isEmpty) return null;
    return rows.first['page'] as int;
  }

  void upsertBookSession({
    required int bookId,
    required int page,
    required int updatedAt,
    int? volume,
    double? scrollOffset,
  }) {
    _db.execute(
      '''
      INSERT INTO book_session (book_id, page, volume, scroll_offset, updated_at)
      VALUES (?, ?, ?, ?, ?)
      ON CONFLICT(book_id) DO UPDATE SET
        page=excluded.page,
        volume=excluded.volume,
        scroll_offset=excluded.scroll_offset,
        updated_at=excluded.updated_at
      ''',
      [bookId, page, volume, scrollOffset, updatedAt],
    );
  }

  int? readingProgressPage(int bookId) => readingProgressFor(bookId)?.page;

  LocalReadingProgress? readingProgressFor(int bookId) {
    final rows = _db.select(
      '''
      SELECT book_id, page, volume, scroll_offset, progress_at, device_id, sync_state
      FROM reading_progress WHERE book_id = ? LIMIT 1
      ''',
      [bookId],
    );
    if (rows.isEmpty) return null;
    return LocalReadingProgress.fromRow(rows.first);
  }

  LocalReadingProgress? latestReadingProgress() {
    final rows = _db.select('''
      SELECT book_id, page, volume, scroll_offset, progress_at, device_id, sync_state
      FROM reading_progress
      ORDER BY progress_at DESC LIMIT 1
      ''');
    if (rows.isEmpty) return null;
    return LocalReadingProgress.fromRow(rows.first);
  }

  /// Qualified progress only. Also updates legacy reading_state so older
  /// readers of that table do not treat a peek as progress.
  void commitQualifiedProgress({
    required int bookId,
    required int page,
    required int progressAt,
    int? volume,
    double? scrollOffset,
  }) {
    final existing = readingProgressFor(bookId);
    if (existing != null && existing.progressAt >= progressAt) return;
    final deviceId = syncMeta('device_id');
    _db.execute(
      '''
      INSERT INTO reading_progress (
        book_id, page, volume, scroll_offset, progress_at, updated_at,
        device_id, sync_state
      ) VALUES (?, ?, ?, ?, ?, ?, ?, 'pending')
      ON CONFLICT(book_id) DO UPDATE SET
        page=excluded.page,
        volume=excluded.volume,
        scroll_offset=excluded.scroll_offset,
        progress_at=excluded.progress_at,
        updated_at=excluded.updated_at,
        device_id=excluded.device_id,
        sync_state='pending'
      ''',
      [bookId, page, volume, scrollOffset, progressAt, progressAt, deviceId],
    );
    upsertReadingState(bookId: bookId, pageId: page, updatedAt: progressAt);
    _enqueue(
      kind: 'beacon',
      tableName: 'reading_progress',
      recordKey: '$bookId',
      payload: _beaconPayload(
        bookId: bookId,
        page: page,
        progressAt: progressAt,
        volume: volume,
        scrollOffset: scrollOffset,
        deviceId: deviceId,
      ),
      createdAt: progressAt,
    );
  }

  bool applyPulledChange({
    required String table,
    required Map<String, Object?> record,
  }) {
    switch (table) {
      case 'reading_progress':
        return _applyPulledProgress(record);
      case 'reading_history_events':
        return _applyPulledHistory(record);
      case 'bookmarks':
        return _applyPulledBookmark(record);
      case 'notes':
        return _applyPulledNote(record);
      case 'bookshelf':
        return _applyPulledShelf(record);
      default:
        return false;
    }
  }

  void prepareSignInReplay({required String deviceId, required int nowMs}) {
    setSyncMeta('device_id', deviceId);
    _db.execute('UPDATE reading_progress SET device_id = ?', [deviceId]);
    _db.execute('DELETE FROM sync_outbox');
    for (final row in _db.select(
      'SELECT book_id, page, volume, scroll_offset, progress_at FROM reading_progress',
    )) {
      final bookId = row['book_id'] as int;
      final page = row['page'] as int;
      final progressAt = row['progress_at'] as int;
      _enqueue(
        kind: 'beacon',
        tableName: 'reading_progress',
        recordKey: '$bookId',
        payload: _beaconPayload(
          bookId: bookId,
          page: page,
          progressAt: progressAt,
          volume: row['volume'] as int?,
          scrollOffset: (row['scroll_offset'] as num?)?.toDouble(),
          deviceId: deviceId,
        ),
        createdAt: nowMs,
      );
    }
    for (final row in _db.select('''
      SELECT id, book_id, page_id, print_page, opened_at, duration_seconds, server_id
      FROM reading_history
    ''')) {
      final localId = row['id'] as int;
      final serverId = _ensureServerId(
        'reading_history',
        localId,
        row['server_id'] as String?,
      );
      final openedAt = row['opened_at'] as int;
      final page = (row['print_page'] as int?) ?? (row['page_id'] as int);
      _enqueueChange(
        table: 'reading_history_events',
        recordKey: serverId,
        createdAt: nowMs,
        record: {
          'id': serverId,
          'book_id': '${row['book_id']}',
          'page': page,
          'opened_at': _iso(openedAt),
          'duration_s': (row['duration_seconds'] as int?) ?? 0,
          'updated_at': _iso(openedAt),
        },
      );
    }
    for (final row in _db.select(
      'SELECT id, book_id, page_id, print_page, label, created_at, server_id FROM bookmarks',
    )) {
      final localId = row['id'] as int;
      final serverId = _ensureServerId(
        'bookmarks',
        localId,
        row['server_id'] as String?,
      );
      final createdAt = row['created_at'] as int;
      _enqueueChange(
        table: 'bookmarks',
        recordKey: serverId,
        createdAt: nowMs,
        record: {
          'id': serverId,
          'book_id': '${row['book_id']}',
          'page': (row['print_page'] as int?) ?? (row['page_id'] as int),
          'label': row['label'],
          'updated_at': _iso(createdAt),
        },
      );
    }
    for (final row in _db.select(
      'SELECT id, book_id, page_id, note, created_at, server_id FROM text_notes',
    )) {
      final localId = row['id'] as int;
      final serverId = _ensureServerId(
        'text_notes',
        localId,
        row['server_id'] as String?,
      );
      final createdAt = row['created_at'] as int;
      _enqueueChange(
        table: 'notes',
        recordKey: serverId,
        createdAt: nowMs,
        record: {
          'id': serverId,
          'book_id': '${row['book_id']}',
          'page': row['page_id'],
          'body': row['note'],
          'updated_at': _iso(createdAt),
        },
      );
    }
    for (final row in _db.select('''
      SELECT book_id, installed_at FROM installed_books
      WHERE book_id NOT IN (SELECT book_id FROM library_exclusions)
    ''')) {
      final bookId = row['book_id'] as int;
      final addedAt = row['installed_at'] as int;
      _db.execute(
        '''
        INSERT INTO bookshelf_sync (book_id, added_at, updated_at, device_id, sync_state)
        VALUES (?, ?, ?, ?, 'pending')
        ON CONFLICT(book_id) DO UPDATE SET
          device_id=excluded.device_id
        ''',
        [bookId, addedAt, addedAt, deviceId],
      );
      _enqueueChange(
        table: 'bookshelf',
        recordKey: '$bookId',
        createdAt: nowMs,
        record: {
          'book_id': '$bookId',
          'added_at': _iso(addedAt),
          'removed_everywhere': false,
          'updated_at': _iso(addedAt),
        },
      );
    }
  }

  List<OutboxItem> listOutbox() {
    return _db
        .select('''
      SELECT id, kind, table_name, record_key, payload_json, created_at,
             attempts, last_error
      FROM sync_outbox ORDER BY id ASC
      ''')
        .map((row) {
          final payload =
              jsonDecode(row['payload_json'] as String) as Map<String, dynamic>;
          return OutboxItem(
            id: row['id'] as int,
            kind: row['kind'] as String,
            tableName: row['table_name'] as String?,
            recordKey: row['record_key'] as String?,
            payload: Map<String, Object?>.from(payload),
            createdAt: row['created_at'] as int,
            attempts: row['attempts'] as int? ?? 0,
            lastError: row['last_error'] as String?,
          );
        })
        .toList();
  }

  void deleteOutbox(List<int> ids) {
    for (final id in ids) {
      _db.execute('DELETE FROM sync_outbox WHERE id = ?', [id]);
    }
  }

  void markOutboxFailure({
    required int id,
    required int attempts,
    required String lastError,
    required int nowMs,
  }) {
    _db.execute(
      '''
      UPDATE sync_outbox
      SET attempts = ?, last_error = ?, created_at = ?
      WHERE id = ?
      ''',
      [attempts, lastError, nowMs, id],
    );
  }

  bool hasSyncIssues() {
    final rows = _db.select(
      'SELECT 1 FROM sync_outbox WHERE attempts >= 10 LIMIT 1',
    );
    return rows.isNotEmpty;
  }

  void pruneOutbox() {
    _db.execute('DELETE FROM sync_outbox');
  }

  String? syncMeta(String key) {
    final rows = _db.select(
      'SELECT value FROM sync_meta WHERE key = ? LIMIT 1',
      [key],
    );
    if (rows.isEmpty) return null;
    return rows.first['value'] as String?;
  }

  void setSyncMeta(String key, String value) {
    _db.execute(
      '''
      INSERT INTO sync_meta (key, value) VALUES (?, ?)
      ON CONFLICT(key) DO UPDATE SET value=excluded.value
      ''',
      [key, value],
    );
  }

  void clearSyncSession() {
    _db.execute('DELETE FROM sync_outbox');
    _db.execute('DELETE FROM sync_meta');
  }

  /// Account deletion: synced rows, outbox, and cursor. Viewport stays.
  void wipeAccountLocal() {
    _db.execute('DELETE FROM reading_progress');
    _db.execute('DELETE FROM bookshelf_sync');
    _db.execute('DELETE FROM bookmarks');
    _db.execute('DELETE FROM text_notes');
    _db.execute('DELETE FROM reading_history');
    _db.execute('DELETE FROM reading_state');
    clearSyncSession();
  }

  void _enqueue({
    required String kind,
    required String payload,
    required int createdAt,
    String? tableName,
    String? recordKey,
  }) {
    _db.execute(
      '''
      INSERT INTO sync_outbox
        (kind, table_name, record_key, payload_json, created_at)
      VALUES (?, ?, ?, ?, ?)
      ''',
      [kind, tableName, recordKey, payload, createdAt],
    );
    onWrite?.call();
  }

  String ensureDeviceId() {
    final existing = syncMeta('device_id');
    if (existing != null && isDeviceUuid(existing)) return existing;
    final id = uuidV4();
    setSyncMeta('device_id', id);
    return id;
  }

  List<({int bookId, int addedAt, int updatedAt, bool removed})>
  listBookshelfSync() {
    return _db
        .select('''
          SELECT book_id, added_at, updated_at, removed_everywhere
          FROM bookshelf_sync
        ''')
        .map(
          (row) => (
            bookId: row['book_id'] as int,
            addedAt: row['added_at'] as int,
            updatedAt: row['updated_at'] as int,
            removed: (row['removed_everywhere'] as int? ?? 0) != 0,
          ),
        )
        .toList();
  }

  void _enqueueHistoryId(
    int localId, {
    required int nowMs,
    bool deleted = false,
  }) {
    final rows = _db.select(
      '''
      SELECT id, book_id, page_id, print_page, opened_at, duration_seconds, server_id
      FROM reading_history WHERE id = ? LIMIT 1
      ''',
      [localId],
    );
    if (rows.isEmpty) return;
    final row = rows.first;
    final serverId = _ensureServerId(
      'reading_history',
      localId,
      row['server_id'] as String?,
    );
    final openedAt = row['opened_at'] as int;
    final page = (row['print_page'] as int?) ?? (row['page_id'] as int);
    _enqueueChange(
      table: 'reading_history_events',
      recordKey: serverId,
      createdAt: nowMs,
      record: {
        'id': serverId,
        'book_id': '${row['book_id']}',
        'page': page,
        'opened_at': _iso(openedAt),
        'duration_s': (row['duration_seconds'] as int?) ?? 0,
        'updated_at': _iso(nowMs),
        if (deleted) 'deleted_at': _iso(nowMs),
      },
    );
  }

  void _enqueueBookmarkId(
    int localId, {
    required int nowMs,
    bool deleted = false,
  }) {
    final rows = _db.select(
      '''
      SELECT id, book_id, page_id, print_page, label, created_at, server_id
      FROM bookmarks WHERE id = ? LIMIT 1
      ''',
      [localId],
    );
    if (rows.isEmpty) return;
    final row = rows.first;
    final serverId = _ensureServerId(
      'bookmarks',
      localId,
      row['server_id'] as String?,
    );
    _enqueueChange(
      table: 'bookmarks',
      recordKey: serverId,
      createdAt: nowMs,
      record: {
        'id': serverId,
        'book_id': '${row['book_id']}',
        'page': (row['print_page'] as int?) ?? (row['page_id'] as int),
        'label': row['label'],
        'updated_at': _iso(nowMs),
        if (deleted) 'deleted_at': _iso(nowMs),
      },
    );
  }

  void _enqueueNoteId(int localId, {bool deleted = false}) {
    final rows = _db.select(
      '''
      SELECT id, book_id, page_id, note, created_at, server_id
      FROM text_notes WHERE id = ? LIMIT 1
      ''',
      [localId],
    );
    if (rows.isEmpty) return;
    final row = rows.first;
    final now = DateTime.now().millisecondsSinceEpoch;
    final serverId = _ensureServerId(
      'text_notes',
      localId,
      row['server_id'] as String?,
    );
    _enqueueChange(
      table: 'notes',
      recordKey: serverId,
      createdAt: now,
      record: {
        'id': serverId,
        'book_id': '${row['book_id']}',
        'page': row['page_id'],
        'body': row['note'],
        'updated_at': _iso(now),
        if (deleted) 'deleted_at': _iso(now),
      },
    );
  }

  void _enqueueShelf({
    required int bookId,
    required int addedAt,
    required bool removed,
  }) {
    final now = DateTime.now().millisecondsSinceEpoch;
    _db.execute(
      '''
      INSERT INTO bookshelf_sync (book_id, added_at, updated_at, device_id, sync_state, removed_everywhere)
      VALUES (?, ?, ?, ?, 'pending', ?)
      ON CONFLICT(book_id) DO UPDATE SET
        updated_at=excluded.updated_at,
        removed_everywhere=excluded.removed_everywhere,
        device_id=excluded.device_id,
        sync_state='pending'
      ''',
      [bookId, addedAt, now, syncMeta('device_id'), removed ? 1 : 0],
    );
    _enqueueChange(
      table: 'bookshelf',
      recordKey: '$bookId',
      createdAt: now,
      record: {
        'book_id': '$bookId',
        'added_at': _iso(addedAt),
        'removed_everywhere': removed,
        'updated_at': _iso(now),
      },
    );
  }

  void _enqueueChange({
    required String table,
    required String recordKey,
    required Map<String, Object?> record,
    required int createdAt,
  }) {
    _enqueue(
      kind: 'change',
      tableName: table,
      recordKey: recordKey,
      payload: jsonEncode(record),
      createdAt: createdAt,
    );
  }

  String _ensureServerId(String table, int localId, String? existing) {
    if (existing != null && existing.isNotEmpty) return existing;
    final id = uuidV5(ishamelaIdNamespace, '$table:$localId');
    _db.execute('UPDATE $table SET server_id = ? WHERE id = ?', [id, localId]);
    return id;
  }

  bool _applyPulledProgress(Map<String, Object?> record) {
    final bookId = _asInt(record['book_id']);
    final page = _asInt(record['page']);
    final progressAt = _millis(record['progress_at']);
    if (bookId == null || page == null || progressAt == null) return false;
    final local = readingProgressFor(bookId);
    if (local != null && local.progressAt >= progressAt) return false;
    _db.execute(
      '''
      INSERT INTO reading_progress (
        book_id, page, volume, scroll_offset, progress_at, updated_at,
        device_id, server_seq, sync_state
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, 'synced')
      ON CONFLICT(book_id) DO UPDATE SET
        page=excluded.page,
        volume=excluded.volume,
        scroll_offset=excluded.scroll_offset,
        progress_at=excluded.progress_at,
        updated_at=excluded.updated_at,
        device_id=excluded.device_id,
        server_seq=excluded.server_seq,
        sync_state='synced'
      ''',
      [
        bookId,
        page,
        _asInt(record['volume']),
        (record['scroll_offset'] as num?)?.toDouble(),
        progressAt,
        _millis(record['updated_at']) ?? progressAt,
        record['device_id'] as String?,
        _asInt(record['server_seq']),
      ],
    );
    return true;
  }

  bool _applyPulledHistory(Map<String, Object?> record) {
    final serverId = record['id'] as String?;
    final bookId = _asInt(record['book_id']);
    final page = _asInt(record['page']);
    final openedAt = _millis(record['opened_at']);
    final updatedAt = _millis(record['updated_at']);
    if (serverId == null ||
        bookId == null ||
        page == null ||
        openedAt == null) {
      return false;
    }
    if (record['deleted_at'] != null) {
      _db.execute('DELETE FROM reading_history WHERE server_id = ?', [
        serverId,
      ]);
      return true;
    }
    final rows = _db.select(
      'SELECT id, opened_at FROM reading_history WHERE server_id = ? LIMIT 1',
      [serverId],
    );
    if (rows.isNotEmpty) {
      final local = rows.first['opened_at'] as int;
      if (updatedAt != null && local >= updatedAt) return false;
      _db.execute(
        '''
        UPDATE reading_history
        SET page_id = ?, print_page = ?, opened_at = ?, duration_seconds = ?
        WHERE server_id = ?
        ''',
        [page, page, openedAt, _asInt(record['duration_s']) ?? 0, serverId],
      );
      return true;
    }
    _db.execute(
      '''
      INSERT INTO reading_history
        (book_id, part, page_id, print_page, opened_at, duration_seconds, server_id)
      VALUES (?, '', ?, ?, ?, ?, ?)
      ''',
      [
        bookId,
        page,
        page,
        openedAt,
        _asInt(record['duration_s']) ?? 0,
        serverId,
      ],
    );
    return true;
  }

  bool _applyPulledBookmark(Map<String, Object?> record) {
    final serverId = record['id'] as String?;
    final bookId = _asInt(record['book_id']);
    final page = _asInt(record['page']);
    final updatedAt = _millis(record['updated_at']);
    if (serverId == null ||
        bookId == null ||
        page == null ||
        updatedAt == null) {
      return false;
    }
    if (record['deleted_at'] != null) {
      _db.execute('DELETE FROM bookmarks WHERE server_id = ?', [serverId]);
      return true;
    }
    final rows = _db.select(
      'SELECT created_at FROM bookmarks WHERE server_id = ? LIMIT 1',
      [serverId],
    );
    if (rows.isNotEmpty) {
      if ((rows.first['created_at'] as int) >= updatedAt) return false;
      _db.execute(
        '''
        UPDATE bookmarks SET page_id = ?, print_page = ?, label = ?, created_at = ?
        WHERE server_id = ?
        ''',
        [page, page, record['label'], updatedAt, serverId],
      );
      return true;
    }
    _db.execute(
      '''
      INSERT INTO bookmarks (book_id, part, page_id, print_page, label, created_at, server_id)
      VALUES (?, '', ?, ?, ?, ?, ?)
      ''',
      [bookId, page, page, record['label'], updatedAt, serverId],
    );
    return true;
  }

  bool _applyPulledNote(Map<String, Object?> record) {
    final serverId = record['id'] as String?;
    final bookId = _asInt(record['book_id']);
    final page = _asInt(record['page']);
    final body = record['body'] as String?;
    final updatedAt = _millis(record['updated_at']);
    if (serverId == null ||
        bookId == null ||
        page == null ||
        body == null ||
        body.isEmpty ||
        updatedAt == null) {
      return false;
    }
    if (record['deleted_at'] != null) {
      _db.execute('DELETE FROM text_notes WHERE server_id = ?', [serverId]);
      return true;
    }
    final rows = _db.select(
      'SELECT created_at FROM text_notes WHERE server_id = ? LIMIT 1',
      [serverId],
    );
    if (rows.isNotEmpty) {
      if ((rows.first['created_at'] as int) >= updatedAt) return false;
      _db.execute(
        'UPDATE text_notes SET page_id = ?, note = ?, created_at = ? WHERE server_id = ?',
        [page, body, updatedAt, serverId],
      );
      return true;
    }
    _db.execute(
      '''
      INSERT INTO text_notes (book_id, page_id, start_offset, end_offset, note, created_at, server_id)
      VALUES (?, ?, 0, 0, ?, ?, ?)
      ''',
      [bookId, page, body, updatedAt, serverId],
    );
    return true;
  }

  bool _applyPulledShelf(Map<String, Object?> record) {
    final bookId = _asInt(record['book_id']);
    final addedAt = _millis(record['added_at']);
    final updatedAt = _millis(record['updated_at']);
    if (bookId == null || addedAt == null || updatedAt == null) return false;
    final rows = _db.select(
      'SELECT updated_at FROM bookshelf_sync WHERE book_id = ? LIMIT 1',
      [bookId],
    );
    if (rows.isNotEmpty && (rows.first['updated_at'] as int) >= updatedAt) {
      return false;
    }
    final removed = record['removed_everywhere'] == true ? 1 : 0;
    _db.execute(
      '''
      INSERT INTO bookshelf_sync (
        book_id, added_at, removed_everywhere, updated_at, device_id, sync_state
      ) VALUES (?, ?, ?, ?, ?, 'synced')
      ON CONFLICT(book_id) DO UPDATE SET
        added_at=excluded.added_at,
        removed_everywhere=excluded.removed_everywhere,
        updated_at=excluded.updated_at,
        device_id=excluded.device_id,
        sync_state='synced'
      ''',
      [bookId, addedAt, removed, updatedAt, record['device_id'] as String?],
    );
    return true;
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
      'DELETE FROM highlight_deletions WHERE book_id = ? AND page_id = ? '
      'AND start_offset = ? AND end_offset = ? AND color = ?',
      [bookId, pageId, start, end, color],
    );
    _db.execute(
      'INSERT INTO highlights '
      '(book_id, page_id, start_offset, end_offset, color, created_at) '
      'VALUES (?, ?, ?, ?, ?, ?)',
      [bookId, pageId, start, end, color, createdAt],
    );
    return _db.lastInsertRowId;
  }

  void deleteHighlight(int id) {
    final rows = _db.select(
      'SELECT book_id, page_id, start_offset, end_offset, color, created_at '
      'FROM highlights WHERE id = ?',
      [id],
    );
    if (rows.isNotEmpty) {
      final r = rows.first;
      final deletedAt = DateTime.now().millisecondsSinceEpoch;
      final createdAt = r['created_at'] as int;
      _rememberHighlightDeletion(
        bookId: r['book_id'] as int,
        pageId: r['page_id'] as int,
        start: r['start_offset'] as int,
        end: r['end_offset'] as int,
        color: r['color'] as String,
        deletedAt: deletedAt > createdAt ? deletedAt : createdAt + 1,
      );
    }
    _db.execute('DELETE FROM highlights WHERE id = ?', [id]);
  }

  List<Map<String, Object?>> listHighlights() {
    return _db
        .select(
          'SELECT id, book_id, page_id, start_offset, end_offset, color, '
          'created_at FROM highlights ORDER BY created_at ASC',
        )
        .map((r) => Map<String, Object?>.from(r))
        .toList();
  }

  List<Map<String, Object?>> listHighlightDeletions() {
    return _db
        .select(
          'SELECT book_id, page_id, start_offset, end_offset, color, deleted_at '
          'FROM highlight_deletions ORDER BY deleted_at ASC',
        )
        .map((r) => Map<String, Object?>.from(r))
        .toList();
  }

  /// Apply one remote highlight. A newer deletion on either side wins.
  bool applyRemoteHighlight({
    required int bookId,
    required int pageId,
    required int start,
    required int end,
    required String color,
    required int updatedAt,
    required bool deleted,
  }) {
    final tombstone = _highlightDeletionAt(
      bookId: bookId,
      pageId: pageId,
      start: start,
      end: end,
      color: color,
    );
    final existing = _db.select(
      'SELECT id, created_at FROM highlights WHERE book_id = ? AND page_id = ? '
      'AND start_offset = ? AND end_offset = ? AND color = ? LIMIT 1',
      [bookId, pageId, start, end, color],
    );
    if (deleted) {
      if (tombstone != null && tombstone >= updatedAt) return false;
      if (existing.isNotEmpty) {
        final createdAt = existing.first['created_at'] as int;
        if (createdAt > updatedAt) return false;
        _db.execute('DELETE FROM highlights WHERE id = ?', [
          existing.first['id'],
        ]);
      }
      _rememberHighlightDeletion(
        bookId: bookId,
        pageId: pageId,
        start: start,
        end: end,
        color: color,
        deletedAt: updatedAt,
      );
      return true;
    }
    if (tombstone != null && tombstone >= updatedAt) return false;
    if (existing.isNotEmpty) return false;
    insertHighlight(
      bookId: bookId,
      pageId: pageId,
      start: start,
      end: end,
      color: color,
      createdAt: updatedAt,
    );
    return true;
  }

  int? _highlightDeletionAt({
    required int bookId,
    required int pageId,
    required int start,
    required int end,
    required String color,
  }) {
    final rows = _db.select(
      'SELECT deleted_at FROM highlight_deletions WHERE book_id = ? '
      'AND page_id = ? AND start_offset = ? AND end_offset = ? AND color = ?',
      [bookId, pageId, start, end, color],
    );
    if (rows.isEmpty) return null;
    return rows.first['deleted_at'] as int;
  }

  void _rememberHighlightDeletion({
    required int bookId,
    required int pageId,
    required int start,
    required int end,
    required String color,
    required int deletedAt,
  }) {
    _db.execute(
      '''
      INSERT INTO highlight_deletions
        (book_id, page_id, start_offset, end_offset, color, deleted_at)
      VALUES (?, ?, ?, ?, ?, ?)
      ON CONFLICT(book_id, page_id, start_offset, end_offset, color)
      DO UPDATE SET deleted_at = excluded.deleted_at
      WHERE excluded.deleted_at > highlight_deletions.deleted_at
      ''',
      [bookId, pageId, start, end, color, deletedAt],
    );
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
    final id = _db.lastInsertRowId;
    _enqueueNoteId(id);
    return id;
  }

  void updateNote(int id, String note) {
    _db.execute('UPDATE text_notes SET note = ? WHERE id = ?', [note, id]);
    _enqueueNoteId(id);
  }

  void deleteNote(int id) {
    _enqueueNoteId(id, deleted: true);
    _db.execute('DELETE FROM text_notes WHERE id = ?', [id]);
  }

  // --- SPEC-014 / SPEC-023 reading history & bookmarks ---

  static const historyCoalesce = Duration(minutes: 30);
  static const historyMaxAge = Duration(days: 90);
  static const historyMaxRows = 500;

  /// Idle-cap for credited session seconds (SPEC-023 §2.3).
  static const historyDurationCapSeconds = 30 * 60;

  String _bookmarkPartKey(String? part) => part ?? '';

  /// Credited seconds for [elapsedMs], capped at [historyDurationCapSeconds].
  static int cappedDurationSeconds(int elapsedMs) {
    if (elapsedMs <= 0) return 0;
    final sec = elapsedMs ~/ 1000;
    return sec > historyDurationCapSeconds ? historyDurationCapSeconds : sec;
  }

  /// Open or coalesce a history session; prune on insert. Spec-testable windows.
  ///
  /// On coalesce (page turn or close), [duration_seconds] accumulates the delta
  /// since the last checkpoint (prior closed_at, or opened_at + prior duration),
  /// capped at [historyDurationCapSeconds] total.
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
      SELECT id, opened_at, closed_at, duration_seconds FROM reading_history
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
        final prevClosed = newest.first['closed_at'] as int?;
        final prevDuration = newest.first['duration_seconds'] as int?;
        final lastCheckpoint =
            prevClosed ?? (openedAt + (prevDuration ?? 0) * 1000);
        final deltaMs = nowMs - lastCheckpoint;
        final added = cappedDurationSeconds(deltaMs);
        final nextDuration = ((prevDuration ?? 0) + added)
            .clamp(0, historyDurationCapSeconds)
            .toInt();
        _db.execute(
          '''
          UPDATE reading_history SET
            part = ?, page_id = ?, print_page = ?, section_title = ?,
            closed_at = ?, duration_seconds = ?
          WHERE id = ?
          ''',
          [part, pageId, printPage, sectionTitle, closedAt, nextDuration, id],
        );
        _enqueueHistoryId(id, nowMs: nowMs);
        return id;
      }
    }
    final insertDuration = closing
        ? cappedDurationSeconds(0)
        : null; // open-only: no duration yet
    // closing on a brand-new row is unusual; duration stays 0 until activity.
    _db.execute(
      '''
      INSERT INTO reading_history
        (book_id, part, page_id, print_page, section_title, opened_at, closed_at,
         duration_seconds)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?)
      ''',
      [
        bookId,
        part,
        pageId,
        printPage,
        sectionTitle,
        nowMs,
        closedAt,
        insertDuration,
      ],
    );
    final id = _db.lastInsertRowId;
    _pruneReadingHistory(nowMs: nowMs, maxAge: maxAge, maxRows: maxRows);
    _enqueueHistoryId(id, nowMs: nowMs);
    return id;
  }

  void _pruneReadingHistory({
    required int nowMs,
    required Duration maxAge,
    required int maxRows,
  }) {
    final cutoff = nowMs - maxAge.inMilliseconds;
    final stale = _db.select(
      'SELECT id FROM reading_history WHERE opened_at < ?',
      [cutoff],
    );
    for (final row in stale) {
      _enqueueHistoryId(row['id'] as int, nowMs: nowMs, deleted: true);
    }
    _db.execute('DELETE FROM reading_history WHERE opened_at < ?', [cutoff]);
    final count =
        _db.select('SELECT COUNT(*) AS n FROM reading_history').first['n']
            as int;
    if (count <= maxRows) return;
    final overflow = count - maxRows;
    final oldest = _db.select(
      'SELECT id FROM reading_history ORDER BY opened_at ASC LIMIT ?',
      [overflow],
    );
    for (final row in oldest) {
      _enqueueHistoryId(row['id'] as int, nowMs: nowMs, deleted: true);
    }
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
        .select('''
          SELECT id, book_id, part, page_id, print_page, section_title,
                 opened_at, closed_at, duration_seconds
          FROM reading_history ORDER BY opened_at DESC
          ''')
        .map(_historyFromRow)
        .toList();
  }

  /// Raw history rows for DAOs that need map access (SPEC-023).
  List<Map<String, Object?>> readingHistoryRows() {
    return _db
        .select('''
          SELECT id, book_id, part, page_id, print_page, section_title,
                 opened_at, closed_at, duration_seconds
          FROM reading_history ORDER BY opened_at DESC
          ''')
        .map((r) => Map<String, Object?>.from(r))
        .toList();
  }

  ReadingHistoryEntry? latestReadingHistory() {
    final rows = _db.select('''
      SELECT id, book_id, part, page_id, print_page, section_title,
             opened_at, closed_at, duration_seconds
      FROM reading_history ORDER BY opened_at DESC LIMIT 1
      ''');
    if (rows.isEmpty) return null;
    return _historyFromRow(rows.first);
  }

  void clearReadingHistory() {
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final row in _db.select('SELECT id FROM reading_history')) {
      _enqueueHistoryId(row['id'] as int, nowMs: now, deleted: true);
    }
    _db.execute('DELETE FROM reading_history');
  }

  void deleteReadingHistory(int id) {
    _enqueueHistoryId(
      id,
      nowMs: DateTime.now().millisecondsSinceEpoch,
      deleted: true,
    );
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
      durationSeconds: r['duration_seconds'] as int?,
    );
  }

  // --- SPEC-023 / SPEC-024 sync_state + prefs ---

  SyncState getSyncState() {
    final rows = _db.select(
      'SELECT last_synced_at, last_error, cellular_allowed, auto_download '
      'FROM sync_state WHERE id = 1',
    );
    if (rows.isEmpty) {
      return const SyncState(cellularAllowed: true, autoDownload: true);
    }
    final r = rows.first;
    return SyncState(
      lastSyncedAt: r['last_synced_at'] as int?,
      lastError: r['last_error'] as String?,
      cellularAllowed: (r['cellular_allowed'] as int?) == 1,
      autoDownload: (r['auto_download'] as int?) != 0,
    );
  }

  void setSyncState({
    int? lastSyncedAt,
    String? lastError,
    bool? cellularAllowed,
    bool? autoDownload,
    bool clearError = false,
  }) {
    final cur = getSyncState();
    _db.execute(
      '''
      INSERT INTO sync_state
        (id, last_synced_at, last_error, cellular_allowed, auto_download)
      VALUES (1, ?, ?, ?, ?)
      ON CONFLICT(id) DO UPDATE SET
        last_synced_at = excluded.last_synced_at,
        last_error = excluded.last_error,
        cellular_allowed = excluded.cellular_allowed,
        auto_download = excluded.auto_download
      ''',
      [
        lastSyncedAt ?? cur.lastSyncedAt,
        clearError ? null : (lastError ?? cur.lastError),
        (cellularAllowed ?? cur.cellularAllowed) ? 1 : 0,
        (autoDownload ?? cur.autoDownload) ? 1 : 0,
      ],
    );
  }

  /// Prefs via existing `settings` table (sync banner dismiss, etc.).
  String? getPref(String key) => setting(key);

  void setPref(String key, String value) => setSetting(key, value);

  static const librarySetupPref = 'library_setup_done';

  bool get librarySetupDone => getPref(librarySetupPref) == '1';

  void setLibrarySetupDone(bool done) =>
      setPref(librarySetupPref, done ? '1' : '0');

  Set<int> libraryExclusionIds() =>
      _idSet('SELECT book_id FROM library_exclusions');

  void markRemovedEverywhere(int bookId) {
    _enqueueShelf(
      bookId: bookId,
      addedAt: installedAt(bookId) ?? DateTime.now().millisecondsSinceEpoch,
      removed: true,
    );
  }

  void addLibraryExclusion(int bookId) {
    _db.execute(
      'INSERT OR IGNORE INTO library_exclusions (book_id) VALUES (?)',
      [bookId],
    );
    _enqueueShelf(
      bookId: bookId,
      addedAt: installedAt(bookId) ?? DateTime.now().millisecondsSinceEpoch,
      removed: true,
    );
  }

  void clearLibraryExclusion(int bookId) {
    _db.execute('DELETE FROM library_exclusions WHERE book_id = ?', [bookId]);
    final added = installedAt(bookId);
    if (added != null) {
      _enqueueShelf(bookId: bookId, addedAt: added, removed: false);
    }
  }

  Set<int> libraryDeferredIds() => _markIds('deferred');

  Set<int> libraryHeldIds() => _markIds('held');

  Set<int> libraryUnavailableIds() => _markIds('unavailable');

  Set<int> libraryAutoIds() => _markIds('auto_sync');

  void markLibraryDeferred(int bookId, {required bool on}) =>
      _setMark(bookId, 'deferred', on);

  void markLibraryHeld(int bookId, {required bool on}) =>
      _setMark(bookId, 'held', on);

  void markLibraryUnavailable(int bookId, {required bool on}) =>
      _setMark(bookId, 'unavailable', on);

  void markLibraryAuto(int bookId, {required bool on}) =>
      _setMark(bookId, 'auto_sync', on);

  Set<int> _markIds(String column) {
    return _idSet('SELECT book_id FROM library_marks WHERE $column = 1');
  }

  void _setMark(int bookId, String column, bool on) {
    _db.execute('INSERT OR IGNORE INTO library_marks (book_id) VALUES (?)', [
      bookId,
    ]);
    _db.execute('UPDATE library_marks SET $column = ? WHERE book_id = ?', [
      on ? 1 : 0,
      bookId,
    ]);
  }

  Set<int> _idSet(String sql) {
    return _db.select(sql).map((r) => r['book_id'] as int).toSet();
  }

  /// Insert a history row pulled from another device when this open is new.
  void importSyncedHistory({
    required int bookId,
    required int pageId,
    required int openedAt,
    String? part,
    int? printPage,
    String? sectionTitle,
    int? closedAt,
    int? durationSeconds,
  }) {
    final existing = _db.select(
      'SELECT 1 FROM reading_history WHERE book_id = ? AND opened_at = ? LIMIT 1',
      [bookId, openedAt],
    );
    if (existing.isNotEmpty) return;
    _db.execute(
      '''
      INSERT INTO reading_history
        (book_id, part, page_id, print_page, section_title, opened_at, closed_at,
         duration_seconds)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?)
      ''',
      [
        bookId,
        part,
        pageId,
        printPage,
        sectionTitle,
        openedAt,
        closedAt,
        durationSeconds,
      ],
    );
  }

  /// Apply a remote progress doc when it is newer than the local row.
  bool applyRemoteProgress({
    required int bookId,
    required int pageId,
    required int updatedAt,
    int? printPage,
    String? part,
    String? sectionTitle,
  }) {
    final rows = _db.select(
      'SELECT updated_at FROM reading_state WHERE book_id = ? LIMIT 1',
      [bookId],
    );
    if (rows.isNotEmpty) {
      final local = rows.first['updated_at'] as int;
      if (local >= updatedAt) return false;
    }
    upsertReadingState(bookId: bookId, pageId: pageId, updatedAt: updatedAt);
    importSyncedHistory(
      bookId: bookId,
      pageId: pageId,
      openedAt: updatedAt,
      printPage: printPage,
      part: part,
      sectionTitle: sectionTitle,
      closedAt: updatedAt,
    );
    return true;
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
  }) => bookmarkForPage(bookId: bookId, pageId: pageId, part: part) != null;

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
    final id = _db.lastInsertRowId;
    _enqueueBookmarkId(id, nowMs: createdAt);
    return id;
  }

  void updateBookmarkLabel(int id, String? label) {
    final stored = (label == null || label.trim().isEmpty)
        ? null
        : label.trim();
    _db.execute('UPDATE bookmarks SET label = ? WHERE id = ?', [stored, id]);
    _enqueueBookmarkId(id, nowMs: DateTime.now().millisecondsSinceEpoch);
  }

  void deleteBookmark(int id) {
    _enqueueBookmarkId(
      id,
      nowMs: DateTime.now().millisecondsSinceEpoch,
      deleted: true,
    );
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

  /// All bookmarks across books (SPEC-023 quick-action destination).
  List<Bookmark> listAllBookmarks() {
    return _db
        .select('''
          SELECT id, book_id, part, page_id, print_page, label, created_at
          FROM bookmarks ORDER BY created_at DESC
          ''')
        .map(_bookmarkFromRow)
        .toList();
  }

  String _beaconPayload({
    required int bookId,
    required int page,
    required int progressAt,
    int? volume,
    double? scrollOffset,
    String? deviceId,
  }) {
    return jsonEncode({
      'bookId': '$bookId',
      'page': page,
      'volume': volume,
      'scrollOffset': scrollOffset,
      'progressAt': _iso(progressAt),
      'deviceId': deviceId,
    });
  }

  static String _iso(int ms) =>
      DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true).toIso8601String();

  static int? _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  static int? _millis(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) {
      return DateTime.tryParse(value)?.millisecondsSinceEpoch;
    }
    return null;
  }

  /// All text notes across books (SPEC-023 quick-action destination).
  List<Map<String, Object?>> listAllNotes() {
    return _db
        .select('''
          SELECT id, book_id, page_id, start_offset, end_offset, note, created_at
          FROM text_notes ORDER BY created_at DESC
          ''')
        .map((r) => Map<String, Object?>.from(r))
        .toList();
  }
}

class LocalReadingProgress {
  const LocalReadingProgress({
    required this.bookId,
    required this.page,
    required this.progressAt,
    this.volume,
    this.scrollOffset,
    this.deviceId,
    this.syncState = 'pending',
  });

  final int bookId;
  final int page;
  final int? volume;
  final double? scrollOffset;
  final int progressAt;
  final String? deviceId;
  final String syncState;

  static LocalReadingProgress fromRow(Row row) {
    return LocalReadingProgress(
      bookId: row['book_id'] as int,
      page: row['page'] as int,
      volume: row['volume'] as int?,
      scrollOffset: (row['scroll_offset'] as num?)?.toDouble(),
      progressAt: row['progress_at'] as int,
      deviceId: row['device_id'] as String?,
      syncState: row['sync_state'] as String? ?? 'pending',
    );
  }
}
