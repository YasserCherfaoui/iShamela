import 'package:ishamela/core/db/open_readonly.dart';
import 'package:ishamela/core/db/paths.dart';
import 'package:ishamela/core/search/normalizer.dart';
import 'package:ishamela/core/search/normalizer_map.dart';
import 'package:ishamela/features/catalog/catalog_service.dart'
    show buildCatalogFtsMatch;
import 'package:sqlite3/sqlite3.dart';

/// One page from an installed book bundle (SPEC-002 / SPEC-005).
class BookPage {
  BookPage({
    required this.id,
    required this.body,
    this.part,
    this.pageNumber,
    this.footnotes,
  });

  final int id;
  final String? part;
  final int? pageNumber;

  /// Verbatim `pages.body` — never normalize for display.
  final String body;

  /// Verbatim upstream footnotes (SPEC-012); null if absent.
  final String? footnotes;
}

class TocEntry {
  TocEntry({
    required this.id,
    required this.title,
    required this.pageId,
    required this.position,
    this.parentId,
  });

  final int id;
  final int? parentId;
  final String title;
  final int pageId;
  final int position;
}

class BookSearchHit {
  BookSearchHit({
    required this.pageId,
    required this.body,
    required this.highlightRanges,
    this.pageNumber,
    this.part,
  });

  final int pageId;
  final int? pageNumber;
  final String? part;
  final String body;
  final List<({int start, int end})> highlightRanges;
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
    try {
      final rows = _db.select(
        'SELECT id, part, page_number, body, footnotes '
        'FROM pages WHERE id = ? LIMIT 1',
        [id],
      );
      if (rows.isEmpty) return null;
      return _pageFromRow(rows.first);
    } catch (_) {
      final rows = _db.select(
        'SELECT id, part, page_number, body FROM pages WHERE id = ? LIMIT 1',
        [id],
      );
      if (rows.isEmpty) return null;
      return _pageFromRow(rows.first);
    }
  }

  BookPage? pageByPrintNumber(int pageNumber) {
    try {
      final rows = _db.select(
        'SELECT id, part, page_number, body, footnotes FROM pages '
        'WHERE page_number = ? ORDER BY id LIMIT 1',
        [pageNumber],
      );
      if (rows.isEmpty) return null;
      return _pageFromRow(rows.first);
    } catch (_) {
      final rows = _db.select(
        'SELECT id, part, page_number, body FROM pages '
        'WHERE page_number = ? ORDER BY id LIMIT 1',
        [pageNumber],
      );
      if (rows.isEmpty) return null;
      return _pageFromRow(rows.first);
    }
  }

  BookPage _pageFromRow(Row r) {
    String? footnotes;
    try {
      footnotes = r['footnotes'] as String?;
    } catch (_) {
      footnotes = null;
    }
    return BookPage(
      id: r['id'] as int,
      part: r['part'] as String?,
      pageNumber: r['page_number'] as int?,
      body: r['body'] as String,
      footnotes: footnotes,
    );
  }

  List<TocEntry> tocEntries() {
    try {
      return _db
          .select(
            'SELECT id, parent_id, title, page_id, position FROM toc '
            'ORDER BY position, id',
          )
          .map(
            (r) => TocEntry(
              id: r['id'] as int,
              parentId: r['parent_id'] as int?,
              title: r['title'] as String,
              pageId: r['page_id'] as int,
              position: r['position'] as int,
            ),
          )
          .toList();
    } catch (_) {
      return const [];
    }
  }

  /// In-book FTS (SPEC-005 MATCH construction).
  List<BookSearchHit> searchInBook(String query, {bool exactPhrase = false}) {
    final q = normalize(query);
    if (q.isEmpty) return const [];
    final match = exactPhrase
        ? '"${q.replaceAll('"', '""')}"'
        : buildCatalogFtsMatch(q);
    if (match.isEmpty) return const [];
    try {
      final rows = _db.select(
        '''
        SELECT p.id, p.page_number, p.part, p.body
        FROM pages_fts
        JOIN pages p ON p.id = pages_fts.rowid
        WHERE pages_fts MATCH ?
        ORDER BY p.id
        LIMIT 100
        ''',
        [match],
      );
      final tokens = exactPhrase
          ? [q]
          : q.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
      return rows.map((r) {
        final body = r['body'] as String;
        final nr = normalizeWithMap(body);
        final ranges = <({int start, int end})>[];
        for (final t in tokens) {
          ranges.addAll(findHighlightRanges(nr, t));
        }
        return BookSearchHit(
          pageId: r['id'] as int,
          pageNumber: r['page_number'] as int?,
          part: r['part'] as String?,
          body: body,
          highlightRanges: ranges,
        );
      }).toList();
    } catch (_) {
      return const [];
    }
  }
}
