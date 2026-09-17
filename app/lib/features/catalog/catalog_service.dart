import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';

import 'package:ishamela/core/compress/zstd.dart';
import 'package:ishamela/core/config.dart';
import 'package:ishamela/core/db/paths.dart';
import 'package:ishamela/core/db/state_database.dart';
import 'package:ishamela/core/models/models.dart';
import 'package:ishamela/core/search/normalizer.dart';

/// Resolve [relative] against [baseUrl] (must end with `/` for directory bases).
String catalogUrl(String baseUrl, String relative) {
  final base = baseUrl.endsWith('/') ? baseUrl : '$baseUrl/';
  return Uri.parse(base).resolve(relative).toString();
}

/// Fetches and installs the remote catalog (SPEC-004).
class CatalogSync {
  CatalogSync({
    required this.dio,
    required this.paths,
    required this.zstd,
    this.baseUrl = catalogBaseUrl,
  });

  final Dio dio;
  final AppPaths paths;
  final ZstdDecompressor zstd;
  final String baseUrl;

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

  /// Fetch manifest; download/swap catalog DB if newer. Failures keep the old catalog.
  Future<CatalogManifest?> sync({Duration timeout = const Duration(seconds: 5)}) async {
    try {
      final manifestUrl = catalogUrl(baseUrl, 'catalog/catalog.json');
      developer.log('catalog sync GET $manifestUrl', name: 'CatalogSync');
      final response = await dio.get<List<int>>(
        manifestUrl,
        options: Options(
          responseType: ResponseType.bytes,
          receiveTimeout: timeout,
          sendTimeout: timeout,
        ),
      );
      final raw = response.data;
      if (raw == null) return null;
      final data = decodeJsonMap(utf8.decode(raw));
      final manifest = CatalogManifest.fromJson(data);
      final local = localCatalogVersion() ?? 0;
      if (manifest.catalogVersion <= local) {
        return manifest;
      }
      await _installCatalogDb(manifest);
      return manifest;
    } catch (e, st) {
      // SPEC: keep current catalog silently (log for diagnosis).
      developer.log(
        'catalog sync failed: $e',
        name: 'CatalogSync',
        error: e,
        stackTrace: st,
      );
      return null;
    }
  }

  Future<void> _installCatalogDb(CatalogManifest manifest) async {
    final zstUrl = catalogUrl(baseUrl, manifest.catalogSqliteZstPath);
    developer.log('catalog sync GET $zstUrl', name: 'CatalogSync');
    final response = await dio.get<List<int>>(
      zstUrl,
      options: Options(responseType: ResponseType.bytes),
    );
    final bytes = Uint8List.fromList(response.data ?? const []);
    final digest = sha256.convert(bytes).toString();
    if (digest != manifest.catalogSqliteZstSha256) {
      throw StateError('catalog.sqlite.zst sha256 mismatch');
    }
    final plain = await zstd.decompress(bytes);
    final part = paths.catalogSqlitePart;
    await part.writeAsBytes(plain, flush: true);
    // Validate schema before swap.
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
            [q],
          )
          .map(_bookFromRow)
          .toList();
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
    );
  }
}

String sha256File(File file) {
  final digest = sha256.convert(file.readAsBytesSync());
  return digest.toString();
}

String sha256Bytes(Uint8List bytes) => sha256.convert(bytes).toString();

Map<String, dynamic> decodeJsonMap(String raw) =>
    jsonDecode(raw) as Map<String, dynamic>;
