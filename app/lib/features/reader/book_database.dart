import 'package:ishamela/core/db/open_readonly.dart';
import 'package:ishamela/core/db/paths.dart';
import 'package:ishamela/core/search/normalizer.dart';
import 'package:ishamela/core/search/normalizer_map.dart';
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
    required this.snippet,
    this.pageNumber,
    this.part,
  });

  final int pageId;
  final int? pageNumber;
  final String? part;
  final String body;
  final List<({int start, int end})> highlightRanges;

  /// Display snippet around the first hit (SPEC-005).
  final String snippet;
}

/// SPEC-005 in-book MATCH: quoted tokens, implicit AND, **no** prefix `*`.
/// FTS5 operator characters are stripped so user input is literal.
String buildBookFtsMatch(String normalizedQuery) {
  final parts = <String>[];
  for (final raw in normalizedQuery.split(RegExp(r'\s+'))) {
    if (raw.isEmpty) continue;
    final cleaned = raw
        .replaceAll(RegExp(r'["*\^:(){}]'), '')
        .replaceAll(RegExp(r'^-+|-+$'), '')
        .trim();
    if (cleaned.isEmpty) continue;
    final escaped = cleaned.replaceAll('"', '""');
    parts.add('"$escaped"');
  }
  return parts.join(' ');
}

/// ~[words] words each side of the first highlight, from original body.
String bookSearchSnippet(
  String body,
  List<({int start, int end})> ranges, {
  int words = 10,
}) {
  if (body.isEmpty) return '';
  int start;
  int end;
  if (ranges.isEmpty) {
    start = 0;
    end = body.length;
  } else {
    start = ranges.first.start.clamp(0, body.length);
    end = ranges.first.end.clamp(0, body.length);
    if (end < start) end = start;
    start = _expandWordsLeft(body, start, words);
    end = _expandWordsRight(body, end, words);
  }
  var snip = body.substring(start, end);
  snip = snip.replaceAll(RegExp(r'<[^>]*>'), ' ');
  snip = snip.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (snip.isEmpty) {
    snip = body
        .replaceAll(RegExp(r'<[^>]*>'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (snip.length > 160) snip = '${snip.substring(0, 159)}…';
    return snip;
  }
  final prefix = start > 0 ? '…' : '';
  final suffix = end < body.length ? '…' : '';
  return '$prefix$snip$suffix';
}

int _expandWordsLeft(String body, int index, int words) {
  var i = index;
  var n = 0;
  while (i > 0 && n < words) {
    i--;
    if (_isSpace(body.codeUnitAt(i))) {
      while (i > 0 && _isSpace(body.codeUnitAt(i - 1))) {
        i--;
      }
      n++;
    }
  }
  return i;
}

int _expandWordsRight(String body, int index, int words) {
  var i = index;
  var n = 0;
  while (i < body.length && n < words) {
    if (_isSpace(body.codeUnitAt(i))) {
      while (i < body.length && _isSpace(body.codeUnitAt(i))) {
        i++;
      }
      n++;
    } else {
      i++;
    }
  }
  return i;
}

bool _isSpace(int c) =>
    c == 0x20 || c == 0x09 || c == 0x0A || c == 0x0D || c == 0x00A0;

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

  /// In-book FTS (SPEC-005 MATCH — exact tokens, not catalog prefix).
  List<BookSearchHit> searchInBook(String query, {bool exactPhrase = false}) {
    return searchInBookCapped(
      query,
      exactPhrase: exactPhrase,
      hitCap: 100,
      countCap: 100,
    ).hits;
  }

  /// SPEC-017 capped search with approximate total (count capped at [countCap]).
  ({List<BookSearchHit> hits, int totalHits, bool capped}) searchInBookCapped(
    String query, {
    bool exactPhrase = false,
    int hitCap = 50,
    int countCap = 200,
  }) {
    final q = normalize(query);
    if (q.isEmpty) {
      return (hits: const [], totalHits: 0, capped: false);
    }
    final cleanedPhrase = q.replaceAll(RegExp(r'["*\^:(){}]'), '').trim();
    final match = exactPhrase
        ? '"${cleanedPhrase.replaceAll('"', '""')}"'
        : buildBookFtsMatch(q);
    if (match.isEmpty || match == '""') {
      return (hits: const [], totalHits: 0, capped: false);
    }
    try {
      final countRows = _db.select(
        '''
        SELECT COUNT(*) AS c FROM (
          SELECT 1 FROM pages_fts WHERE pages_fts MATCH ? LIMIT ?
        )
        ''',
        [match, countCap + 1],
      );
      final rawCount = countRows.first['c'] as int;
      final totalHits = rawCount > countCap ? countCap : rawCount;
      final capped = rawCount > hitCap;

      final rows = _db.select(
        '''
        SELECT p.id, p.page_number, p.part, p.body
        FROM pages_fts
        JOIN pages p ON p.id = pages_fts.rowid
        WHERE pages_fts MATCH ?
        ORDER BY p.id
        LIMIT ?
        ''',
        [match, hitCap],
      );
      final tokens = exactPhrase
          ? (cleanedPhrase.isEmpty ? <String>[] : [cleanedPhrase])
          : q
              .split(RegExp(r'\s+'))
              .map((t) => t.replaceAll(RegExp(r'["*\^:(){}]'), '').trim())
              .where((t) => t.isNotEmpty)
              .toList();
      final hits = rows.map((r) {
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
          snippet: bookSearchSnippet(body, ranges),
        );
      }).toList();
      return (hits: hits, totalHits: totalHits, capped: capped);
    } catch (_) {
      return (hits: const [], totalHits: 0, capped: false);
    }
  }
}
