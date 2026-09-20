import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart' show rootBundle;

import 'package:ishamela/core/compress/zstd.dart';
import 'package:ishamela/core/config.dart';
import 'package:ishamela/core/db/app_fs.dart';
import 'package:ishamela/core/db/open_readonly.dart';
import 'package:ishamela/core/db/paths.dart';
import 'package:ishamela/core/db/sqlite_api.dart';
import 'package:ishamela/core/models/models.dart';
import 'package:ishamela/core/net/catalog_client.dart';
import 'package:ishamela/core/search/normalizer.dart';

export 'package:ishamela/core/net/catalog_client.dart' show catalogUrl;

/// Installs the catalog from the Shamela4 CDN when `catalog.json` exists, else
/// from the bundled asset built from Shamela4 `_meta` (SPEC-007).
class CatalogSync {
  CatalogSync({
    required CatalogClient client,
    required this.paths,
    required this.zstd,
  }) : _client = client;

  final AppPaths paths;
  final ZstdDecompressor zstd;
  final CatalogClient _client;

  String get baseUrl => _client.baseUrl;

  int? localCatalogVersion() {
    if (!appFileExistsSync(paths.catalogSqlite)) return null;
    final db = openReadonlySqlite(paths.catalogSqlite);
    try {
      final rows = db.select(
        "SELECT value FROM meta WHERE key = 'catalog_version' LIMIT 1",
      );
      if (rows.isEmpty) return null;
      return int.tryParse(rows.first['value'] as String);
    } finally {
      db.dispose();
    }
  }

  /// Prefer live `catalog.json` on the CDN; fall back to bundled Shamela4 catalog.
  Future<CatalogManifest?> sync({
    Duration timeout = const Duration(seconds: 5),
  }) async {
    try {
      developer.log(
        'catalog sync GET ${catalogUrl(baseUrl, 'catalog/catalog.json')}',
        name: 'CatalogSync',
      );
      final manifest = await _client.fetchManifest(timeout: timeout);
      final local = localCatalogVersion() ?? 0;
      if (manifest.catalogVersion <= local) {
        return manifest;
      }
      // Web cannot decompress zstd CDN payloads yet — use bundled plain DB.
      if (kIsWeb) {
        return await _installBundledAssetCatalog();
      }
      await _installCatalogDb(manifest);
      return manifest;
    } catch (e, st) {
      developer.log(
        'catalog.json unavailable ($e); installing bundled Shamela4 catalog',
        name: 'CatalogSync',
        error: e,
        stackTrace: st,
      );
      try {
        return await _installBundledAssetCatalog();
      } catch (e2, st2) {
        developer.log(
          'bundled catalog install failed: $e2',
          name: 'CatalogSync',
          error: e2,
          stackTrace: st2,
        );
        return null;
      }
    }
  }

  Future<CatalogManifest> _installBundledAssetCatalog() async {
    final manifestRaw = await rootBundle.loadString(
      'assets/catalog/catalog.json',
    );
    final manifest = CatalogManifest.fromJson(
      jsonDecode(manifestRaw) as Map<String, dynamic>,
    );
    final local = localCatalogVersion() ?? 0;
    if (manifest.catalogVersion <= local &&
        appFileExistsSync(paths.catalogSqlite)) {
      return manifest;
    }
    if (kIsWeb) {
      // Plain sqlite asset (no zstd FFI on web).
      final data = await rootBundle.load('assets/catalog/catalog.sqlite');
      final plain = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      await _swapPlainCatalog(plain);
      return manifest;
    }
    final zst = await rootBundle.load('assets/catalog/catalog.sqlite.zst');
    final bytes = zst.buffer.asUint8List(zst.offsetInBytes, zst.lengthInBytes);
    final digest = sha256.convert(bytes).toString();
    if (digest != manifest.catalogSqliteZstSha256) {
      throw StateError('bundled catalog.sqlite.zst sha256 mismatch');
    }
    await _swapDecompressedCatalog(bytes);
    return manifest;
  }

  Future<void> _installCatalogDb(CatalogManifest manifest) async {
    developer.log(
      'catalog sync GET ${catalogUrl(baseUrl, manifest.catalogSqliteZstPath)}',
      name: 'CatalogSync',
    );
    final bytes = await _client.fetchBytes(manifest.catalogSqliteZstPath);
    final digest = sha256.convert(bytes).toString();
    if (digest != manifest.catalogSqliteZstSha256) {
      throw StateError('catalog.sqlite.zst sha256 mismatch');
    }
    await _swapDecompressedCatalog(bytes);
  }

  Future<void> _swapDecompressedCatalog(Uint8List zstBytes) async {
    final plain = await zstd.decompress(zstBytes);
    await _swapPlainCatalog(plain);
  }

  Future<void> _swapPlainCatalog(Uint8List plain) async {
    final part = paths.catalogSqlitePart;
    await writeAppFile(part, plain);
    final db = openReadonlySqlite(part);
    try {
      final schema = db.select(
        "SELECT value FROM meta WHERE key = 'schema_version' LIMIT 1",
      );
      if (schema.isEmpty ||
          !supportedCatalogSchemaVersions.contains(schema.first['value'])) {
        throw StateError('unsupported catalog schema_version');
      }
    } finally {
      db.dispose();
    }
    await renameAppFile(part, paths.catalogSqlite);
  }
}

/// Read-only catalog queries.
class CatalogRepository {
  CatalogRepository(this.paths);

  final AppPaths paths;

  bool get hasCatalog => appFileExistsSync(paths.catalogSqlite);

  String? get normVersion {
    if (!hasCatalog) return null;
    final db = openReadonlySqlite(paths.catalogSqlite);
    try {
      final rows = db.select(
        "SELECT value FROM meta WHERE key = 'norm_version' LIMIT 1",
      );
      return rows.isEmpty ? null : rows.first['value'] as String;
    } finally {
      db.dispose();
    }
  }

  String? get generatedAt {
    if (!hasCatalog) return null;
    final db = openReadonlySqlite(paths.catalogSqlite);
    try {
      final rows = db.select(
        "SELECT value FROM meta WHERE key = 'generated_at' LIMIT 1",
      );
      return rows.isEmpty ? null : rows.first['value'] as String;
    } finally {
      db.dispose();
    }
  }

  int bookCount() {
    if (!hasCatalog) return 0;
    final db = openReadonlySqlite(paths.catalogSqlite);
    try {
      final rows = db.select('SELECT COUNT(*) AS n FROM books');
      return rows.first['n'] as int;
    } finally {
      db.dispose();
    }
  }

  /// Age of catalog `generated_at` in whole days; null if unknown.
  int? catalogAgeDays() {
    final raw = generatedAt;
    if (raw == null) return null;
    final when = DateTime.tryParse(raw);
    if (when == null) return null;
    return DateTime.now().toUtc().difference(when.toUtc()).inDays;
  }

  /// True when catalog `generated_at` is older than [maxAge] (SPEC-007 stale hint).
  bool isCatalogStale({Duration maxAge = const Duration(days: 30)}) {
    final days = catalogAgeDays();
    if (days == null) return false;
    return days > maxAge.inDays;
  }

  List<Category> categories() {
    final db = openReadonlySqlite(paths.catalogSqlite);
    try {
      return db
          .select(
            'SELECT id, name, position FROM categories ORDER BY position, id',
          )
          .map(
            (r) => Category(
              id: r['id'] as int,
              name: r['name'] as String,
              position: r['position'] as int,
            ),
          )
          .toList();
    } finally {
      db.dispose();
    }
  }

  List<Author> authors() {
    final db = openReadonlySqlite(paths.catalogSqlite);
    try {
      return db
          .select(
            'SELECT id, name, death_year_hijri FROM authors ORDER BY name',
          )
          .map(
            (r) => Author(
              id: r['id'] as int,
              name: r['name'] as String,
              deathYearHijri: r['death_year_hijri'] as int?,
            ),
          )
          .toList();
    } finally {
      db.dispose();
    }
  }

  List<Book> booksByCategory(int categoryId) {
    final db = openReadonlySqlite(paths.catalogSqlite);
    try {
      return db
          .select(
            '''
            SELECT b.*, a.name AS author_name, a.death_year_hijri AS author_death_year, c.name AS category_name
            FROM books b
            LEFT JOIN authors a ON a.id = b.author_id
            JOIN categories c ON c.id = b.category_id
            WHERE b.category_id = ?
            ORDER BY b.title
            ''',
            [categoryId],
          )
          .map(_bookFromRow)
          .toList();
    } finally {
      db.dispose();
    }
  }

  List<Book> booksByAuthor(int authorId) {
    final db = openReadonlySqlite(paths.catalogSqlite);
    try {
      return db
          .select(
            '''
            SELECT b.*, a.name AS author_name, a.death_year_hijri AS author_death_year, c.name AS category_name
            FROM books b
            LEFT JOIN authors a ON a.id = b.author_id
            JOIN categories c ON c.id = b.category_id
            WHERE b.author_id = ?
            ORDER BY b.title
            ''',
            [authorId],
          )
          .map(_bookFromRow)
          .toList();
    } finally {
      db.dispose();
    }
  }

  Book? bookById(int bookId) {
    final db = openReadonlySqlite(paths.catalogSqlite);
    try {
      final rows = db.select(
        '''
        SELECT b.*, a.name AS author_name, a.death_year_hijri AS author_death_year, c.name AS category_name
        FROM books b
        LEFT JOIN authors a ON a.id = b.author_id
        JOIN categories c ON c.id = b.category_id
        WHERE b.book_id = ?
        ''',
        [bookId],
      );
      if (rows.isEmpty) return null;
      return _bookFromRow(rows.first);
    } finally {
      db.dispose();
    }
  }

  Author? authorById(int authorId) {
    final db = openReadonlySqlite(paths.catalogSqlite);
    try {
      final rows = db.select(
        'SELECT id, name, death_year_hijri FROM authors WHERE id = ? LIMIT 1',
        [authorId],
      );
      if (rows.isEmpty) return null;
      final r = rows.first;
      return Author(
        id: r['id'] as int,
        name: r['name'] as String,
        deathYearHijri: r['death_year_hijri'] as int?,
      );
    } finally {
      db.dispose();
    }
  }

  /// Optional bio when catalog schema ships it (SPEC-018 AU-13).
  String? authorBio(int authorId) {
    final db = openReadonlySqlite(paths.catalogSqlite);
    try {
      final cols = db.select('PRAGMA table_info(authors)');
      final hasBio = cols.any((c) => c['name'] == 'bio');
      if (!hasBio) return null;
      final rows = db.select(
        'SELECT bio FROM authors WHERE id = ? LIMIT 1',
        [authorId],
      );
      if (rows.isEmpty) return null;
      final bio = rows.first['bio'] as String?;
      if (bio == null || bio.trim().isEmpty) return null;
      return bio;
    } catch (_) {
      return null;
    } finally {
      db.dispose();
    }
  }

  /// Batch-load books by id (one DB open). Missing ids are skipped.
  List<Book> booksByIds(Iterable<int> bookIds) {
    final ids = bookIds.toSet().toList()..sort();
    if (ids.isEmpty) return const [];
    final out = <Book>[];
    final db = openReadonlySqlite(paths.catalogSqlite);
    try {
      for (final chunk in _chunkIds(ids, 400)) {
        final placeholders = List.filled(chunk.length, '?').join(',');
        final rows = db.select(
          '''
          SELECT b.*, a.name AS author_name, a.death_year_hijri AS author_death_year, c.name AS category_name
          FROM books b
          LEFT JOIN authors a ON a.id = b.author_id
          JOIN categories c ON c.id = b.category_id
          WHERE b.book_id IN ($placeholders)
          ORDER BY b.title
          ''',
          chunk,
        );
        out.addAll(rows.map(_bookFromRow));
      }
    } finally {
      db.dispose();
    }
    return out;
  }

  /// Categories that contain at least one of [installedIds], with counts.
  List<({Category category, int count})> categoriesForInstalled(
    Set<int> installedIds,
  ) {
    if (installedIds.isEmpty) return const [];
    final counts = <int, int>{};
    final db = openReadonlySqlite(paths.catalogSqlite);
    try {
      for (final chunk in _chunkIds(installedIds.toList(), 400)) {
        final placeholders = List.filled(chunk.length, '?').join(',');
        final rows = db.select(
          '''
          SELECT b.category_id AS id, COUNT(*) AS cnt
          FROM books b
          WHERE b.book_id IN ($placeholders)
          GROUP BY b.category_id
          ''',
          chunk,
        );
        for (final r in rows) {
          final id = r['id'] as int;
          counts[id] = (counts[id] ?? 0) + (r['cnt'] as int);
        }
      }
      if (counts.isEmpty) return const [];
      final catIds = counts.keys.toList();
      final out = <({Category category, int count})>[];
      for (final chunk in _chunkIds(catIds, 400)) {
        final placeholders = List.filled(chunk.length, '?').join(',');
        final rows = db.select(
          '''
          SELECT id, name, position FROM categories
          WHERE id IN ($placeholders)
          ORDER BY position, id
          ''',
          chunk,
        );
        for (final r in rows) {
          final id = r['id'] as int;
          out.add((
            category: Category(
              id: id,
              name: r['name'] as String,
              position: r['position'] as int,
            ),
            count: counts[id] ?? 0,
          ));
        }
      }
      out.sort((a, b) => a.category.position.compareTo(b.category.position));
      return out;
    } finally {
      db.dispose();
    }
  }

  /// Authors that have at least one of [installedIds], with counts.
  List<({Author author, int count})> authorsForInstalled(
    Set<int> installedIds,
  ) {
    if (installedIds.isEmpty) return const [];
    final counts = <int, int>{};
    final db = openReadonlySqlite(paths.catalogSqlite);
    try {
      for (final chunk in _chunkIds(installedIds.toList(), 400)) {
        final placeholders = List.filled(chunk.length, '?').join(',');
        final rows = db.select(
          '''
          SELECT b.author_id AS id, COUNT(*) AS cnt
          FROM books b
          WHERE b.book_id IN ($placeholders) AND b.author_id IS NOT NULL
          GROUP BY b.author_id
          ''',
          chunk,
        );
        for (final r in rows) {
          final id = r['id'] as int;
          counts[id] = (counts[id] ?? 0) + (r['cnt'] as int);
        }
      }
      if (counts.isEmpty) return const [];
      final out = <({Author author, int count})>[];
      for (final chunk in _chunkIds(counts.keys.toList(), 400)) {
        final placeholders = List.filled(chunk.length, '?').join(',');
        final rows = db.select(
          '''
          SELECT id, name, death_year_hijri FROM authors
          WHERE id IN ($placeholders)
          ORDER BY name
          ''',
          chunk,
        );
        for (final r in rows) {
          final id = r['id'] as int;
          out.add((
            author: Author(
              id: id,
              name: r['name'] as String,
              deathYearHijri: r['death_year_hijri'] as int?,
            ),
            count: counts[id] ?? 0,
          ));
        }
      }
      out.sort((a, b) => a.author.name.compareTo(b.author.name));
      return out;
    } finally {
      db.dispose();
    }
  }

  /// Installed books in one category (single query).
  List<Book> installedBooksByCategory(int categoryId, Set<int> installedIds) {
    if (installedIds.isEmpty) return const [];
    final out = <Book>[];
    final db = openReadonlySqlite(paths.catalogSqlite);
    try {
      for (final chunk in _chunkIds(installedIds.toList(), 400)) {
        final placeholders = List.filled(chunk.length, '?').join(',');
        final rows = db.select(
          '''
          SELECT b.*, a.name AS author_name, a.death_year_hijri AS author_death_year, c.name AS category_name
          FROM books b
          LEFT JOIN authors a ON a.id = b.author_id
          JOIN categories c ON c.id = b.category_id
          WHERE b.category_id = ? AND b.book_id IN ($placeholders)
          ORDER BY b.title
          ''',
          [categoryId, ...chunk],
        );
        out.addAll(rows.map(_bookFromRow));
      }
    } finally {
      db.dispose();
    }
    return out;
  }

  /// Installed books by one author (single query).
  List<Book> installedBooksByAuthor(int authorId, Set<int> installedIds) {
    if (installedIds.isEmpty) return const [];
    final out = <Book>[];
    final db = openReadonlySqlite(paths.catalogSqlite);
    try {
      for (final chunk in _chunkIds(installedIds.toList(), 400)) {
        final placeholders = List.filled(chunk.length, '?').join(',');
        final rows = db.select(
          '''
          SELECT b.*, a.name AS author_name, a.death_year_hijri AS author_death_year, c.name AS category_name
          FROM books b
          LEFT JOIN authors a ON a.id = b.author_id
          JOIN categories c ON c.id = b.category_id
          WHERE b.author_id = ? AND b.book_id IN ($placeholders)
          ORDER BY b.title
          ''',
          [authorId, ...chunk],
        );
        out.addAll(rows.map(_bookFromRow));
      }
    } finally {
      db.dispose();
    }
    return out;
  }

  static Iterable<List<int>> _chunkIds(List<int> ids, int size) sync* {
    for (var i = 0; i < ids.length; i += size) {
      yield ids.sublist(i, i + size > ids.length ? ids.length : i + size);
    }
  }

  List<Book> search(String query) {
    return scopedSearch(query, chipScope: CatalogSearchScope.books).books;
  }

  /// SPEC-009 scoped catalog search (books / authors / categories / all).
  CatalogSearchResults scopedSearch(
    String rawQuery, {
    CatalogSearchScope chipScope = CatalogSearchScope.all,
    int limitPerSection = 50,
  }) {
    final parsed = parseCatalogSearchQuery(rawQuery, chipScope: chipScope);
    final q = normalize(parsed.query);
    if (q.isEmpty) return CatalogSearchResults();
    final match = buildCatalogFtsMatch(q);
    if (match.isEmpty) return CatalogSearchResults();

    final db = openReadonlySqlite(paths.catalogSqlite);
    try {
      List<Book> books = const [];
      List<Author> authors = const [];
      List<Category> categories = const [];

      if (parsed.scope == CatalogSearchScope.all ||
          parsed.scope == CatalogSearchScope.books) {
        try {
          books = db
              .select(
                '''
                SELECT b.*, a.name AS author_name, a.death_year_hijri AS author_death_year, c.name AS category_name
                FROM books_fts
                JOIN books b ON b.book_id = books_fts.rowid
                LEFT JOIN authors a ON a.id = b.author_id
                JOIN categories c ON c.id = b.category_id
                WHERE books_fts MATCH ?
                ORDER BY b.title
                LIMIT ?
                ''',
                [match, limitPerSection],
              )
              .map(_bookFromRow)
              .toList();
        } on SqliteException {
          books = const [];
        }
      }
      if (parsed.scope == CatalogSearchScope.all ||
          parsed.scope == CatalogSearchScope.authors) {
        try {
          authors = db
              .select(
                '''
                SELECT a.id, a.name, a.death_year_hijri
                FROM authors_fts
                JOIN authors a ON a.id = authors_fts.rowid
                WHERE authors_fts MATCH ?
                ORDER BY a.name
                LIMIT ?
                ''',
                [match, limitPerSection],
              )
              .map(
                (r) => Author(
                  id: r['id'] as int,
                  name: r['name'] as String,
                  deathYearHijri: r['death_year_hijri'] as int?,
                ),
              )
              .toList();
        } on SqliteException {
          authors = const [];
        }
      }
      if (parsed.scope == CatalogSearchScope.all ||
          parsed.scope == CatalogSearchScope.categories) {
        try {
          categories = db
              .select(
                '''
                SELECT c.id, c.name, c.position
                FROM categories_fts
                JOIN categories c ON c.id = categories_fts.rowid
                WHERE categories_fts MATCH ?
                ORDER BY c.position, c.id
                LIMIT ?
                ''',
                [match, limitPerSection],
              )
              .map(
                (r) => Category(
                  id: r['id'] as int,
                  name: r['name'] as String,
                  position: r['position'] as int,
                ),
              )
              .toList();
        } on SqliteException {
          categories = const [];
        }
      }
      return CatalogSearchResults(
        books: books,
        authors: authors,
        categories: categories,
      );
    } finally {
      db.dispose();
    }
  }

  Book _bookFromRow(Map<String, Object?> r) {
    return Book(
      bookId: r['book_id'] as int,
      title: r['title'] as String,
      authorId: r['author_id'] as int?,
      authorName: r['author_name'] as String?,
      authorDeathYearHijri: r['author_death_year'] as int?,
      categoryId: r['category_id'] as int,
      categoryName: r['category_name'] as String?,
      pageCount: r['page_count'] as int,
      volumeCount: r['volume_count'] as int?,
      isbBytes: r['isb_bytes'] as int,
      sqliteBytes: r['sqlite_bytes'] as int,
      sha256: r['sha256'] as String,
      filename: r['filename'] as String,
      sourcePagesPath: r['source_pages_path'] as String?,
      betakaText: r['betaka_text'] as String?,
    );
  }
}

/// Quote FTS5 tokens so user input like `AND` / `*` cannot break MATCH.
/// Trailing `*` enables prefix match for partial titles/authors.
String buildCatalogFtsMatch(String normalizedQuery) {
  final parts = <String>[];
  for (final raw in normalizedQuery.split(RegExp(r'\s+'))) {
    if (raw.isEmpty) continue;
    final cleaned = raw.replaceAll('"', ' ').replaceAll('*', ' ').trim();
    if (cleaned.isEmpty) continue;
    final escaped = cleaned.replaceAll('"', '""');
    parts.add('"$escaped"*');
  }
  return parts.join(' ');
}

enum CatalogSearchScope { all, books, authors, categories }

class CatalogSearchResults {
  CatalogSearchResults({
    this.books = const [],
    this.authors = const [],
    this.categories = const [],
  });

  final List<Book> books;
  final List<Author> authors;
  final List<Category> categories;

  bool get isEmpty =>
      books.isEmpty && authors.isEmpty && categories.isEmpty;
}

/// Parse optional `كتاب:` / `مؤلف:` / `قسم:` prefixes (SPEC-009).
({CatalogSearchScope scope, String query}) parseCatalogSearchQuery(
  String raw, {
  CatalogSearchScope chipScope = CatalogSearchScope.all,
}) {
  final trimmed = raw.trim();
  final lower = trimmed; // Arabic prefixes are exact
  const prefixes = <String, CatalogSearchScope>{
    'كتاب:': CatalogSearchScope.books,
    'مؤلف:': CatalogSearchScope.authors,
    'قسم:': CatalogSearchScope.categories,
  };
  for (final e in prefixes.entries) {
    if (lower.startsWith(e.key)) {
      return (scope: e.value, query: trimmed.substring(e.key.length).trim());
    }
  }
  return (scope: chipScope, query: trimmed);
}

String sha256Bytes(Uint8List bytes) => sha256.convert(bytes).toString();

Map<String, dynamic> decodeJsonMap(String raw) =>
    jsonDecode(raw) as Map<String, dynamic>;
