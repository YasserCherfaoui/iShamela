import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:ishamela/core/compress/zstd.dart';
import 'package:ishamela/core/db/open_readonly.dart';
import 'package:ishamela/core/db/paths.dart';
import 'package:ishamela/core/db/state_database.dart';
import 'package:ishamela/core/models/models.dart';
import 'package:ishamela/core/net/bundle_downloader.dart';
import 'package:ishamela/core/net/catalog_client.dart';
import 'package:ishamela/core/search/normalizer.dart';
import 'package:ishamela/features/catalog/catalog_service.dart';
import 'package:ishamela/features/downloads/bundle_installer.dart';
import 'package:ishamela/features/downloads/download_service.dart';

final _fixtures = Directory('test/fixtures');

Uint8List _read(String name) =>
    File(p.join(_fixtures.path, name)).readAsBytesSync();

ZstdDecompressor fixtureZstd() {
  final catalogZst = _read('catalog.sqlite.zst');
  final catalogPlain = _read('catalog.sqlite');

  return FakeZstdDecompressor((input) async {
    if (_same(input, catalogZst)) return catalogPlain;
    throw StateError('unknown zstd payload len=${input.length}');
  });
}

bool _same(Uint8List a, Uint8List b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

class _MemoryAdapter implements HttpClientAdapter {
  _MemoryAdapter(this.handlers);
  final Map<String, List<int> Function(RequestOptions)> handlers;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final handler = handlers[options.uri.toString()];
    if (handler == null) {
      return ResponseBody.fromString('missing ${options.uri}', 404);
    }
    final range = options.headers['Range']?.toString();
    var bytes = handler(options);
    var status = 200;
    if (range != null && range.startsWith('bytes=')) {
      final start = int.parse(range.substring(6, range.indexOf('-')));
      bytes = bytes.sublist(start);
      status = 206;
    }
    return ResponseBody.fromBytes(
      bytes,
      status,
      headers: {
        Headers.contentTypeHeader: ['application/octet-stream'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Future<AppPaths> _tempPaths() async {
  final dir = await Directory.systemTemp.createTemp('ishamela-test-');
  final paths = AppPaths(Directory(p.join(dir.path, 'ishamela')));
  await paths.ensureLayout();
  return paths;
}

DownloadService _svc({
  required AppPaths paths,
  required StateDatabase state,
  required CatalogRepository catalog,
  required Dio dio,
  String pagesBaseUrl = 'https://example.test/pages/',
}) {
  return DownloadService(
    downloader: BundleDownloader(dio),
    paths: paths,
    state: state,
    catalog: catalog,
    pagesBaseUrl: pagesBaseUrl,
    sourceRevision: 'test-rev',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('catalog search with and without diacritics', () async {
    final paths = await _tempPaths();
    await File(p.join(_fixtures.path, 'catalog.sqlite'))
        .copy(paths.catalogSqlite.path);
    final repo = CatalogRepository(paths);
    final withMarks = repo.search('الْكِتَابُ الْمُبِينُ');
    final plain = repo.search(normalize('الْكِتَابُ الْمُبِينُ'));
    expect(withMarks.map((b) => b.bookId), [900001]);
    expect(plain.map((b) => b.bookId), [900001]);
    // Prefix on a title token
    expect(repo.search('المبين').map((b) => b.bookId), contains(900001));
    // FTS operators must not crash
    expect(repo.search('التوحيد AND'), isEmpty);
  });

  test('BundleInstaller tolerates duplicate sequence_num', () async {
    final paths = await _tempPaths();
    final pages = File(p.join(paths.tmpDir.path, 'dup.pages.jsonl'));
    await pages.writeAsString(
      '{"sequence_num":1,"page_num":1,"part":null,"body":"أول"}\n'
      '{"sequence_num":1,"page_num":2,"part":"1","body":"مكرر"}\n'
      '{"sequence_num":2,"page_num":3,"part":"1","body":"ثالث"}\n',
    );
    final book = Book(
      bookId: 42,
      title: 'dup',
      categoryId: 1,
      pageCount: 3,
      isbBytes: 0,
      sqliteBytes: 0,
      sha256: '0' * 64,
      filename: 'x.isb',
      sourcePagesPath: 'x/pages.jsonl',
    );
    final result = await const BundleInstaller().installFromPagesJsonl(
      pagesJsonl: pages,
      partFile: paths.bookSqlitePart(42),
      destFile: paths.bookSqlite(42),
      book: book,
      sourceRevision: 'test',
      builtBy: 'test',
    );
    expect(result.pageCount, 3);
    final db = openReadonlySqlite(paths.bookSqlite(42));
    try {
      final ids = db
          .select('SELECT id, body FROM pages ORDER BY id')
          .map((r) => r['id'] as int)
          .toList();
      expect(ids.toSet().length, 3);
      expect(ids.length, 3);
    } finally {
      db.dispose();
    }
  });

  test('catalog sync installs newer catalog', () async {
    final paths = await _tempPaths();
    final zstd = fixtureZstd();
    final dio = Dio();
    final zst = _read('catalog.sqlite.zst');
    dio.httpClientAdapter = _MemoryAdapter({
      'https://example.test/catalog/catalog.json': (_) =>
          File(p.join(_fixtures.path, 'catalog.json')).readAsBytesSync(),
      'https://example.test/catalog/catalog.sqlite.zst': (_) => zst,
    });

    final sync = CatalogSync(
      client: CatalogClient(dio, baseUrl: 'https://example.test/'),
      paths: paths,
      zstd: zstd,
    );
    final result = await sync.sync();
    expect(result, isNotNull);
    expect(paths.catalogSqlite.existsSync(), isTrue);
    expect(sync.localCatalogVersion(), 1);
  });

  test('catalog sync rejects sha256 mismatch silently', () async {
    final paths = await _tempPaths();
    final zstd = fixtureZstd();
    final dio = Dio();
    final badManifest =
        '{"book_count":1,"books_base_url":"https://example.test/pages/",'
        '"catalog_sqlite_zst":{"bytes":1,"path":"catalog/catalog.sqlite.zst",'
        '"sha256":"${'0' * 64}"},"catalog_version":2,'
        '"generated_at":"2026-09-17T00:00:00Z","min_app_version":"0.1.0",'
        '"norm_version":"1.0.0","schema_version":2}\n';
    dio.httpClientAdapter = _MemoryAdapter({
      'https://example.test/catalog/catalog.json': (_) =>
          badManifest.codeUnits,
      'https://example.test/catalog/catalog.sqlite.zst': (_) =>
          _read('catalog.sqlite.zst'),
    });
    final sync = CatalogSync(
      client: CatalogClient(dio, baseUrl: 'https://example.test/'),
      paths: paths,
      zstd: zstd,
    );
    final result = await sync.sync();
    expect(result, isNull);
    expect(paths.catalogSqlite.existsSync(), isFalse);
  });

  test('BundleInstaller builds SPEC-002 sqlite with FTS', () async {
    final paths = await _tempPaths();
    final pages = File(p.join(_fixtures.path, 'book_900001.pages.jsonl'));
    final book = Book(
      bookId: 900001,
      title: 'Fixture',
      categoryId: 1,
      categoryName: 'عقيدة',
      authorName: 'مؤلف',
      pageCount: 3,
      isbBytes: 0,
      sqliteBytes: 0,
      sha256: '0' * 64,
      filename: 'book_900001.isb',
      sourcePagesPath: 'book_900001/pages.jsonl',
    );
    final result = await const BundleInstaller().installFromPagesJsonl(
      pagesJsonl: pages,
      partFile: paths.bookSqlitePart(900001),
      destFile: paths.bookSqlite(900001),
      book: book,
      sourceRevision: 'test-rev',
      builtBy: 'ishamela/test',
    );
    expect(result.pageCount, 3);
    expect(result.schemaVersion, '1');
    expect(result.normVersion, normVersion);

    final db = openReadonlySqlite(paths.bookSqlite(900001));
    try {
      final meta = {
        for (final r in db.select('SELECT key, value FROM meta'))
          r['key'] as String: r['value'] as String,
      };
      expect(meta['page_count'], '3');
      expect(meta['source_revision'], 'test-rev');
      expect(meta['built_by'], 'ishamela/test');
      final body = db.select(
        'SELECT body FROM pages WHERE id = 1',
      ).first['body'] as String;
      expect(body, contains('بِسْمِ')); // verbatim with diacritics
      final hits = db.select(
        'SELECT rowid FROM pages_fts WHERE pages_fts MATCH ?',
        [normalize('الحمد')],
      );
      expect(hits, isNotEmpty);
    } finally {
      db.dispose();
    }
  });

  test('download happy path installs from pages.jsonl', () async {
    final paths = await _tempPaths();
    await File(p.join(_fixtures.path, 'catalog.sqlite'))
        .copy(paths.catalogSqlite.path);
    final state = await StateDatabase.open(paths);
    final catalog = CatalogRepository(paths);
    final pages = _read('book_900001.pages.jsonl');
    final dio = Dio();
    dio.httpClientAdapter = _MemoryAdapter({
      'https://example.test/pages/book_900001/pages.jsonl': (_) => pages,
    });
    final svc = _svc(
      paths: paths,
      state: state,
      catalog: catalog,
      dio: dio,
    );
    await svc.enqueue(900001);
    await _waitUntil(() => state.isInstalled(900001));
    expect(paths.bookSqlite(900001).existsSync(), isTrue);
    expect(paths.tmpPagesJsonl(900001).existsSync(), isFalse);

    final db = openReadonlySqlite(paths.bookSqlite(900001));
    try {
      final n = db.select('SELECT COUNT(*) AS c FROM pages').first['c'] as int;
      expect(n, 3);
      final hits = db.select(
        'SELECT rowid FROM pages_fts WHERE pages_fts MATCH ?',
        [normalize('التوحيد')],
      );
      expect(hits, isNotEmpty);
    } finally {
      db.dispose();
    }
  });

  test('cancel mid-download leaves no installed row or sqlite', () async {
    final paths = await _tempPaths();
    await File(p.join(_fixtures.path, 'catalog.sqlite'))
        .copy(paths.catalogSqlite.path);
    final state = await StateDatabase.open(paths);
    final catalog = CatalogRepository(paths);
    final pages = _read('book_900001.pages.jsonl');

    final started = Completer<void>();
    final release = Completer<void>();
    final dio = Dio();
    dio.httpClientAdapter = _BlockingAdapter(
      url: 'https://example.test/pages/book_900001/pages.jsonl',
      bytes: pages,
      onStart: () {
        if (!started.isCompleted) started.complete();
      },
      gate: release.future,
    );
    final svc = _svc(
      paths: paths,
      state: state,
      catalog: catalog,
      dio: dio,
    );
    unawaited(svc.enqueue(900001));
    await started.future;
    await svc.cancel(900001);
    release.complete();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(state.isInstalled(900001), isFalse);
    expect(paths.bookSqlite(900001).existsSync(), isFalse);
    expect(paths.tmpPagesJsonl(900001).existsSync(), isFalse);
    expect(svc.listTasks().where((t) => t.bookId == 900001), isEmpty);
  });

  test('airplane mode after install: book DB opens read-only', () async {
    final paths = await _tempPaths();
    await File(p.join(_fixtures.path, 'catalog.sqlite'))
        .copy(paths.catalogSqlite.path);
    final state = await StateDatabase.open(paths);
    final catalog = CatalogRepository(paths);
    final pages = _read('book_900001.pages.jsonl');
    final dio = Dio();
    dio.httpClientAdapter = _MemoryAdapter({
      'https://example.test/pages/book_900001/pages.jsonl': (_) => pages,
    });
    final svc = _svc(
      paths: paths,
      state: state,
      catalog: catalog,
      dio: dio,
    );
    await svc.enqueue(900001);
    await _waitUntil(() => state.isInstalled(900001));

    // Simulate offline: any further HTTP fails.
    dio.httpClientAdapter = _MemoryAdapter({});
    final db = openReadonlySqlite(paths.bookSqlite(900001));
    try {
      final rows = db.select('SELECT id, body FROM pages ORDER BY id');
      expect(rows.length, 3);
      expect(state.isInstalled(900001), isTrue);
    } finally {
      db.dispose();
    }
  });

  test('resume issues Range request for pages.jsonl', () async {
    final paths = await _tempPaths();
    await File(p.join(_fixtures.path, 'catalog.sqlite'))
        .copy(paths.catalogSqlite.path);
    final state = await StateDatabase.open(paths);
    final catalog = CatalogRepository(paths);
    final pages = _read('book_900001.pages.jsonl');
    final partial = pages.sublist(0, pages.length ~/ 2);
    await paths.tmpPagesJsonl(900001).writeAsBytes(partial);
    state.upsertDownload(
      bookId: 900001,
      status: DownloadStatus.queued.name,
      bytesDone: partial.length,
      bytesTotal: pages.length,
      updatedAt: 1,
    );

    String? seenRange;
    final dio = Dio();
    dio.httpClientAdapter = _MemoryAdapter({
      'https://example.test/pages/book_900001/pages.jsonl': (opts) {
        seenRange = opts.headers['Range']?.toString();
        return pages;
      },
    });
    final svc = _svc(
      paths: paths,
      state: state,
      catalog: catalog,
      dio: dio,
    );
    svc.recoverQueue();
    await _waitUntil(() => state.isInstalled(900001));
    expect(seenRange, 'bytes=${partial.length}-');
  });

  test('maxConcurrent is 2', () async {
    final paths = await _tempPaths();
    final state = await StateDatabase.open(paths);
    final catalog = CatalogRepository(paths);
    final svc = _svc(
      paths: paths,
      state: state,
      catalog: catalog,
      dio: Dio(),
    );
    expect(svc.maxConcurrent, 2);
  });

  test('enqueueMany queues missing books and skips installed', () async {
    final paths = await _tempPaths();
    await File(p.join(_fixtures.path, 'catalog.sqlite'))
        .copy(paths.catalogSqlite.path);
    final state = await StateDatabase.open(paths);
    final catalog = CatalogRepository(paths);
    state.upsertInstalled(
      bookId: 900001,
      schemaVersion: 1,
      normVersion: '1.0.0',
      sqliteBytes: 100,
      installedAt: 1,
    );
    final blocked = DownloadService(
      downloader: BundleDownloader(Dio()),
      paths: paths,
      state: state,
      catalog: catalog,
      pagesBaseUrl: 'https://example.test/pages/',
      maxConcurrent: 0,
    );
    final books = [
      catalog.bookById(900001)!,
      Book(
        bookId: 900002,
        title: 'b2',
        categoryId: 1,
        pageCount: 1,
        isbBytes: 10,
        sqliteBytes: 40,
        sha256: 'b' * 64,
        filename: 'book_900002.isb',
        sourcePagesPath: 'b2/pages.jsonl',
      ),
      Book(
        bookId: 900003,
        title: 'b3',
        categoryId: 1,
        pageCount: 1,
        isbBytes: 20,
        sqliteBytes: 80,
        sha256: 'c' * 64,
        filename: 'book_900003.isb',
        sourcePagesPath: 'b3/pages.jsonl',
      ),
    ];
    final plan = await blocked.enqueueMany(books);
    expect(plan.skippedInstalled, 1);
    expect(plan.missingCount, 2);
    final queued = blocked.listTasks().map((t) => t.bookId).toSet();
    expect(queued, {900002, 900003});
  });
}

/// Adapter that stalls until [gate] completes (for cancel tests).
class _BlockingAdapter implements HttpClientAdapter {
  _BlockingAdapter({
    required this.url,
    required this.bytes,
    required this.onStart,
    required this.gate,
  });

  final String url;
  final List<int> bytes;
  final void Function() onStart;
  final Future<void> gate;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.uri.toString() != url) {
      return ResponseBody.fromString('missing', 404);
    }
    onStart();
    if (cancelFuture != null) {
      final winner = await Future.any<String>([
        gate.then((_) => 'go'),
        cancelFuture.then((_) => 'cancel'),
      ]);
      if (winner == 'cancel') {
        throw DioException(
          requestOptions: options,
          type: DioExceptionType.cancel,
        );
      }
    } else {
      await gate;
    }
    return ResponseBody.fromBytes(
      bytes,
      200,
      headers: {
        Headers.contentTypeHeader: ['application/octet-stream'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Future<void> _waitUntil(
  bool Function() pred, {
  Duration timeout = const Duration(seconds: 5),
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    if (pred()) return;
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
  fail('condition not met within $timeout');
}
