import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:sqlite3/sqlite3.dart' show SqliteException;

import 'package:ishamela/core/compress/zstd.dart';
import 'package:ishamela/core/config.dart';
import 'package:ishamela/core/db/open_readonly.dart';
import 'package:ishamela/core/db/paths.dart';
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
    final file = paths.catalogSqlite;
    if (!file.existsSync()) return null;
    final db = openReadonlySqlite(file);
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
    if (manifest.catalogVersion <= local && paths.catalogSqlite.existsSync()) {
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
    final part = paths.catalogSqlitePart;
    await part.writeAsBytes(plain, flush: true);
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
    final dest = paths.catalogSqlite;
    if (dest.existsSync()) {
      await dest.delete();
    }
    await part.rename(dest.path);
  }
}

/// Read-only catalog queries.
class CatalogRepository {
  CatalogRepository(this.paths);

  final AppPaths paths;

  bool get hasCatalog => paths.catalogSqlite.existsSync();

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

  /// True when catalog `generated_at` is older than [maxAge] (SPEC-007 stale hint).
  bool isCatalogStale({Duration maxAge = const Duration(days: 30)}) {
    final raw = generatedAt;
    if (raw == null) {
      if (!hasCatalog) return false;
      final mtime = paths.catalogSqlite.statSync().modified;
      return DateTime.now().toUtc().difference(mtime.toUtc()) > maxAge;
    }
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return false;
    return DateTime.now().toUtc().difference(parsed.toUtc()) > maxAge;
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
            SELECT b.*, a.name AS author_name, c.name AS category_name
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
            SELECT b.*, a.name AS author_name, c.name AS category_name
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
        SELECT b.*, a.name AS author_name, c.name AS category_name
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

  List<Book> search(String query) {
    final q = normalize(query);
    if (q.isEmpty) return const [];
    final match = buildCatalogFtsMatch(q);
    if (match.isEmpty) return const [];
    final db = openReadonlySqlite(paths.catalogSqlite);
    try {
      return db
          .select(
            '''
            SELECT b.*, a.name AS author_name, c.name AS category_name
            FROM books_fts
            JOIN books b ON b.book_id = books_fts.rowid
            LEFT JOIN authors a ON a.id = b.author_id
            JOIN categories c ON c.id = b.category_id
            WHERE books_fts MATCH ?
            ORDER BY b.title
            ''',
            [match],
          )
          .map(_bookFromRow)
          .toList();
    } on SqliteException {
      // Malformed MATCH (rare after quoting) — treat as no hits.
      return const [];
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
      categoryId: r['category_id'] as int,
      categoryName: r['category_name'] as String?,
      pageCount: r['page_count'] as int,
      volumeCount: r['volume_count'] as int?,
      isbBytes: r['isb_bytes'] as int,
      sqliteBytes: r['sqlite_bytes'] as int,
      sha256: r['sha256'] as String,
      filename: r['filename'] as String,
      sourcePagesPath: r['source_pages_path'] as String?,
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

String sha256File(File file) {
  final digest = sha256.convert(file.readAsBytesSync());
  return digest.toString();
}

String sha256Bytes(Uint8List bytes) => sha256.convert(bytes).toString();

Map<String, dynamic> decodeJsonMap(String raw) =>
    jsonDecode(raw) as Map<String, dynamic>;
