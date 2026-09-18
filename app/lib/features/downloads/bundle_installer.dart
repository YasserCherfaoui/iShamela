import 'dart:convert';
import 'dart:io';

import 'package:sqlite3/sqlite3.dart';

import 'package:ishamela/core/models/models.dart';
import 'package:ishamela/core/search/normalizer.dart';

/// Builds a SPEC-002 book SQLite+FTS5 database from `pages.jsonl` (SPEC-008).
class BundleInstaller {
  const BundleInstaller();

  static const String bookSchemaVersion = '1';
  static const String sourceDataset = 'AuthenticIlm/Shamela4_Full_DB';

  /// Streams [pagesJsonl] into a new SQLite file at [partFile], then atomically
  /// renames to [destFile]. Returns installed page count and meta versions.
  Future<BundleInstallResult> installFromPagesJsonl({
    required File pagesJsonl,
    required File partFile,
    required File destFile,
    required Book book,
    required String sourceRevision,
    required String builtBy,
    void Function(int pagesDone)? onProgress,
    bool Function()? isCancelled,
  }) async {
    if (partFile.existsSync()) {
      partFile.deleteSync();
    }
    if (destFile.existsSync()) {
      destFile.deleteSync();
    }

    final db = sqlite3.open(partFile.path);
    var pageCount = 0;
    try {
      db.execute('PRAGMA page_size = 4096');
      db.execute("PRAGMA encoding = 'UTF-8'");
      db.execute('PRAGMA journal_mode = OFF');
      db.execute('PRAGMA synchronous = OFF');
      db.execute('PRAGMA temp_store = MEMORY');
      db.execute('''
        CREATE TABLE meta (
          key TEXT PRIMARY KEY,
          value TEXT NOT NULL
        )
      ''');
      db.execute('''
        CREATE TABLE pages (
          id INTEGER PRIMARY KEY,
          part TEXT,
          page_number INTEGER,
          body TEXT NOT NULL
        )
      ''');
      db.execute('''
        CREATE VIRTUAL TABLE pages_fts USING fts5(
          body_norm,
          content='',
          tokenize='unicode61 remove_diacritics 0'
        )
      ''');

      final insertPage = db.prepare(
        'INSERT INTO pages (id, part, page_number, body) VALUES (?, ?, ?, ?)',
      );
      final insertFts = db.prepare(
        'INSERT INTO pages_fts (rowid, body_norm) VALUES (?, ?)',
      );
      try {
        // Upstream pages.jsonl can repeat sequence_num (e.g. book 8428).
        // Prefer sequence_num; on collision allocate the next free id so
        // PRIMARY KEY never fails (file order preserved).
        final usedIds = <int>{};
        var nextFreeId = 1;
        final lines = pagesJsonl
            .openRead()
            .transform(utf8.decoder)
            .transform(const LineSplitter());
        await for (final line in lines) {
          if (isCancelled?.call() == true) {
            throw const BundleInstallCancelled();
          }
          final trimmed = line.trim();
          if (trimmed.isEmpty) continue;
          final obj = jsonDecode(trimmed) as Map<String, dynamic>;
          var pageId = _requireInt(obj, 'sequence_num');
          if (usedIds.contains(pageId)) {
            while (usedIds.contains(nextFreeId)) {
              nextFreeId++;
            }
            pageId = nextFreeId;
          }
          usedIds.add(pageId);
          if (pageId >= nextFreeId) {
            nextFreeId = pageId + 1;
          }

          final body = obj['body'];
          if (body is! String) {
            throw StateError('page $pageId body is missing or not a string');
          }
          final partRaw = obj['part'];
          final String? part = partRaw == null
              ? null
              : partRaw is String
                  ? partRaw
                  : partRaw.toString();
          final pageNumRaw = obj['page_num'];
          final int? pageNumber = pageNumRaw == null
              ? null
              : pageNumRaw is int
                  ? pageNumRaw
                  : int.parse(pageNumRaw.toString());

          insertPage.execute([pageId, part, pageNumber, body]);
          final bodyNorm = normalize(body);
          if (bodyNorm.isNotEmpty) {
            insertFts.execute([pageId, bodyNorm]);
          }
          pageCount++;
          if (pageCount % 50 == 0) {
            onProgress?.call(pageCount);
          }
        }
      } finally {
        insertPage.dispose();
        insertFts.dispose();
      }
      onProgress?.call(pageCount);

      final author = book.authorName ?? '';
      final categoryName = book.categoryName ?? '';
      final meta = <String, String>{
        'schema_version': bookSchemaVersion,
        'norm_version': normVersion,
        'book_id': '${book.bookId}',
        'title': book.title,
        'author': author,
        'category_id': '${book.categoryId}',
        'category_name': categoryName,
        'source_dataset': sourceDataset,
        'source_revision': sourceRevision,
        'page_count': '$pageCount',
        'built_by': builtBy,
      };
      final insertMeta = db.prepare(
        'INSERT INTO meta (key, value) VALUES (?, ?)',
      );
      try {
        final entries = meta.entries.toList()
          ..sort((a, b) => a.key.compareTo(b.key));
        for (final e in entries) {
          insertMeta.execute([e.key, e.value]);
        }
      } finally {
        insertMeta.dispose();
      }

      db.execute('VACUUM');
    } catch (e) {
      db.dispose();
      if (partFile.existsSync()) {
        partFile.deleteSync();
      }
      rethrow;
    }
    db.dispose();

    partFile.renameSync(destFile.path);
    return BundleInstallResult(
      pageCount: pageCount,
      schemaVersion: bookSchemaVersion,
      normVersion: normVersion,
    );
  }
}

class BundleInstallResult {
  BundleInstallResult({
    required this.pageCount,
    required this.schemaVersion,
    required this.normVersion,
  });

  final int pageCount;
  final String schemaVersion;
  final String normVersion;
}

class BundleInstallCancelled implements Exception {
  const BundleInstallCancelled();
}

int _requireInt(Map<String, dynamic> obj, String key) {
  final v = obj[key];
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.parse(v);
  throw StateError('page missing valid $key');
}
