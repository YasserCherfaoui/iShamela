import 'dart:convert';
import 'dart:io';

import 'package:sqlite3/sqlite3.dart';

import 'package:ishamela/core/models/models.dart';
import 'package:ishamela/core/search/normalizer.dart';

/// Builds a SPEC-002/009 book SQLite+FTS5 database from `pages.jsonl` (+ TOC).
class BundleInstaller {
  const BundleInstaller();

  static const String bookSchemaVersion = '2';
  static const String sourceDataset = 'AuthenticIlm/Shamela4_Full_DB';

  Future<BundleInstallResult> installFromPagesJsonl({
    required File pagesJsonl,
    required File partFile,
    required File destFile,
    required Book book,
    required String sourceRevision,
    required String builtBy,
    File? tocJsonl,
    void Function(int pagesDone)? onProgress,
    bool Function()? isCancelled,
  }) async {
    if (partFile.existsSync()) partFile.deleteSync();
    if (destFile.existsSync()) destFile.deleteSync();

    final db = sqlite3.open(partFile.path);
    var pageCount = 0;
    final sourceToId = <int, int>{};
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
          body TEXT NOT NULL,
          source_page_id INTEGER
        )
      ''');
      db.execute('''
        CREATE VIRTUAL TABLE pages_fts USING fts5(
          body_norm,
          content='',
          tokenize='unicode61 remove_diacritics 0'
        )
      ''');
      db.execute('''
        CREATE TABLE toc (
          id INTEGER PRIMARY KEY,
          parent_id INTEGER,
          title TEXT NOT NULL,
          page_id INTEGER NOT NULL,
          position INTEGER NOT NULL
        )
      ''');

      final insertPage = db.prepare(
        'INSERT INTO pages (id, part, page_number, body, source_page_id) '
        'VALUES (?, ?, ?, ?, ?)',
      );
      final insertFts = db.prepare(
        'INSERT INTO pages_fts (rowid, body_norm) VALUES (?, ?)',
      );
      final usedIds = <int>{};
      var nextFreeId = 1;
      try {
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
          if (pageId >= nextFreeId) nextFreeId = pageId + 1;

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
          int? sourcePageId;
          final sp = obj['page_id'];
          if (sp != null) {
            sourcePageId = sp is int ? sp : int.parse(sp.toString());
            sourceToId[sourcePageId] = pageId;
          }

          insertPage.execute([pageId, part, pageNumber, body, sourcePageId]);
          final bodyNorm = normalize(body);
          if (bodyNorm.isNotEmpty) {
            insertFts.execute([pageId, bodyNorm]);
          }
          pageCount++;
          if (pageCount % 50 == 0) onProgress?.call(pageCount);
        }
      } finally {
        insertPage.dispose();
        insertFts.dispose();
      }
      onProgress?.call(pageCount);

      if (tocJsonl != null && tocJsonl.existsSync()) {
        await _insertToc(db, tocJsonl, sourceToId, isCancelled);
      }

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
      if (book.betakaText != null && book.betakaText!.isNotEmpty) {
        meta['betaka'] = book.betakaText!;
      }
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
      if (partFile.existsSync()) partFile.deleteSync();
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

  Future<void> _insertToc(
    Database db,
    File tocJsonl,
    Map<int, int> sourceToId,
    bool Function()? isCancelled,
  ) async {
    final insert = db.prepare(
      'INSERT INTO toc (id, parent_id, title, page_id, position) '
      'VALUES (?, ?, ?, ?, ?)',
    );
    try {
      final lines = tocJsonl
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
        final titleId = _tryInt(obj['title_id']);
        final upstreamPage = _tryInt(obj['page_id']);
        final titleRaw = obj['title_text'];
        if (titleId == null || upstreamPage == null || titleRaw == null) {
          continue;
        }
        final pageId = sourceToId[upstreamPage];
        if (pageId == null) continue;
        final title = titleRaw is String ? titleRaw : titleRaw.toString();
        final parentId = _tryInt(obj['parent_id']);
        final position = _tryInt(obj['shamela_title_id']) ?? titleId;
        insert.execute([titleId, parentId, title, pageId, position]);
      }
    } finally {
      insert.dispose();
    }
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

int? _tryInt(Object? v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v);
  return null;
}
