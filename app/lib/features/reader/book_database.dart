import 'package:ishamela/core/db/open_readonly.dart';
import 'package:ishamela/core/db/paths.dart';
import 'package:sqlite3/sqlite3.dart';

/// One page from an installed book bundle (SPEC-002 / SPEC-005).
class BookPage {
  BookPage({
    required this.id,
    required this.body,
    this.part,
    this.pageNumber,
  });

  final int id;
  final String? part;
  final int? pageNumber;

  /// Verbatim `pages.body` — never normalize for display.
  final String body;
}

/// Read-only access to an installed book SQLite file.
class BookDatabase {
  BookDatabase._(this._db, this.bookId);

  final Database _db;
  final int bookId;

  static BookDatabase open(AppPaths paths, int bookId) {
    final file = paths.bookSqlite(bookId);
    if (!file.existsSync()) {
      throw StateError('book $bookId is not installed');
    }
    return BookDatabase._(openReadonlySqlite(file), bookId);
  }

  void close() => _db.dispose();

  String? meta(String key) {
    final rows = _db.select(
      'SELECT value FROM meta WHERE key = ? LIMIT 1',
      [key],
    );
    if (rows.isEmpty) return null;
    return rows.first['value'] as String;
  }

  List<int> pageIds() {
    return _db
        .select('SELECT id FROM pages ORDER BY id')
        .map((r) => r['id'] as int)
        .toList();
  }

  BookPage? pageById(int id) {
    final rows = _db.select(
      'SELECT id, part, page_number, body FROM pages WHERE id = ? LIMIT 1',
      [id],
    );
    if (rows.isEmpty) return null;
    final r = rows.first;
    return BookPage(
      id: r['id'] as int,
      part: r['part'] as String?,
      pageNumber: r['page_number'] as int?,
      body: r['body'] as String,
    );
  }

  /// First page whose print [pageNumber] matches (citation jump).
  BookPage? pageByPrintNumber(int pageNumber) {
    final rows = _db.select(
      'SELECT id, part, page_number, body FROM pages '
      'WHERE page_number = ? ORDER BY id LIMIT 1',
      [pageNumber],
    );
    if (rows.isEmpty) return null;
    final r = rows.first;
    return BookPage(
      id: r['id'] as int,
      part: r['part'] as String?,
      pageNumber: r['page_number'] as int?,
      body: r['body'] as String,
    );
  }
}
