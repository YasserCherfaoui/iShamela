import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

import 'package:ishamela/core/compress/zstd.dart';
import 'package:ishamela/core/db/paths.dart';
import 'package:ishamela/core/db/state_database.dart';
import 'package:ishamela/core/models/models.dart';
import 'package:ishamela/core/net/bundle_downloader.dart';
import 'package:ishamela/core/net/catalog_client.dart';
import 'package:ishamela/core/search/normalizer.dart';
import 'package:ishamela/features/catalog/catalog_service.dart';
import 'package:ishamela/features/downloads/download_service.dart';

final _fixtures = Directory('test/fixtures');

Uint8List _read(String name) =>
    File(p.join(_fixtures.path, name)).readAsBytesSync();

String _readText(String name) =>
    File(p.join(_fixtures.path, name)).readAsStringSync().trim();

Uint8List _decompressFixture(String isbName, String plainName) {
  final plainPath = File(p.join(_fixtures.path, plainName));
  if (plainPath.existsSync()) {
    return plainPath.readAsBytesSync();
  }
  final tmp = File(p.join(_fixtures.path, '.$plainName.tmp'));
  final r = Process.runSync('zstd', [
    '-d',
    '-f',
    '-o',
    tmp.path,
    p.join(_fixtures.path, isbName),
  ]);
  expect(r.exitCode, 0, reason: '${r.stderr}');
  final bytes = tmp.readAsBytesSync();
  plainPath.writeAsBytesSync(bytes);
  tmp.deleteSync();
  return bytes;
}

ZstdDecompressor fixtureZstd() {
  final catalogZst = _read('catalog.sqlite.zst');
  final catalogPlain = _read('catalog.sqlite');
  final bookIsb = _read('book_900001.isb');
  final bookPlain = _decompressFixture('book_900001.isb', 'book_900001.sqlite');
  final badNormIsb = _read('book_900001_bad_norm.isb');
  final badNormPlain = _decompressFixture(
    'book_900001_bad_norm.isb',
    'book_900001_bad_norm.sqlite',
  );

  return FakeZstdDecompressor((input) async {
    if (_same(input, catalogZst)) return catalogPlain;
    if (_same(input, bookIsb)) return bookPlain;
    if (_same(input, badNormIsb)) return badNormPlain;
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
        '{"book_count":1,"books_base_url":"https://example.test/books/",'
        '"catalog_sqlite_zst":{"bytes":1,"path":"catalog/catalog.sqlite.zst",'
        '"sha256":"${'0' * 64}"},"catalog_version":2,'
        '"generated_at":"2026-09-17T00:00:00Z","min_app_version":"0.1.0",'
        '"norm_version":"1.0.0","schema_version":1}\n';
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

  test('download happy path verifies and installs', () async {
    final paths = await _tempPaths();
    await File(p.join(_fixtures.path, 'catalog.sqlite'))
        .copy(paths.catalogSqlite.path);
    final state = await StateDatabase.open(paths);
    final catalog = CatalogRepository(paths);
    final zstd = fixtureZstd();
    final isb = _read('book_900001.isb');
    final dio = Dio();
    dio.httpClientAdapter = _MemoryAdapter({
      'https://example.test/books/book_900001.isb': (_) => isb,
    });
    final svc = DownloadService(
      downloader: BundleDownloader(dio),
      paths: paths,
      state: state,
      catalog: catalog,
      zstd: zstd,
      booksBaseUrl: 'https://example.test/books/',
    );
    await svc.enqueue(900001);
    await _waitUntil(() => state.isInstalled(900001));
    expect(paths.bookSqlite(900001).existsSync(), isTrue);
    expect(paths.tmpIsb(900001).existsSync(), isFalse);
  });

  test('corrupt isb rejected at verifying with no leftovers', () async {
    final paths = await _tempPaths();
    await File(p.join(_fixtures.path, 'catalog.sqlite'))
        .copy(paths.catalogSqlite.path);
    final state = await StateDatabase.open(paths);
    final catalog = CatalogRepository(paths);
    final zstd = fixtureZstd();
    final corrupt = _read('book_900001_corrupt.isb');
    final dio = Dio();
    dio.httpClientAdapter = _MemoryAdapter({
      'https://example.test/books/book_900001.isb': (_) => corrupt,
    });
    final svc = DownloadService(
      downloader: BundleDownloader(dio),
      paths: paths,
      state: state,
      catalog: catalog,
      zstd: zstd,
      booksBaseUrl: 'https://example.test/books/',
    );
    await svc.enqueue(900001);
    await _waitUntil(() {
      final t = svc.listTasks().where((t) => t.bookId == 900001);
      return t.isNotEmpty && t.first.status == DownloadStatus.error;
    });
    expect(state.isInstalled(900001), isFalse);
    expect(paths.tmpIsb(900001).existsSync(), isFalse);
    expect(paths.bookSqlite(900001).existsSync(), isFalse);
  });

  test('norm_version mismatch rejected at installing', () async {
    final paths = await _tempPaths();
    await File(p.join(_fixtures.path, 'catalog.sqlite'))
        .copy(paths.catalogSqlite.path);
    final badSha = _readText('book_900001_bad_norm.sha256');
    final rw = sqlite3.open(paths.catalogSqlite.path);
    rw.execute(
      'UPDATE books SET sha256 = ?, isb_bytes = ? WHERE book_id = 900001',
      [badSha, _read('book_900001_bad_norm.isb').length],
    );
    rw.dispose();

    final state = await StateDatabase.open(paths);
    final catalog = CatalogRepository(paths);
    final zstd = fixtureZstd();
    final badIsb = _read('book_900001_bad_norm.isb');
    final dio = Dio();
    dio.httpClientAdapter = _MemoryAdapter({
      'https://example.test/books/book_900001.isb': (_) => badIsb,
    });
    final svc = DownloadService(
      downloader: BundleDownloader(dio),
      paths: paths,
      state: state,
      catalog: catalog,
      zstd: zstd,
      booksBaseUrl: 'https://example.test/books/',
    );
    await svc.enqueue(900001);
    await _waitUntil(() {
      final t = svc.listTasks().where((t) => t.bookId == 900001);
      return t.isNotEmpty && t.first.status == DownloadStatus.error;
    });
    expect(state.isInstalled(900001), isFalse);
    expect(paths.bookSqlite(900001).existsSync(), isFalse);
    final err = svc.listTasks().firstWhere((t) => t.bookId == 900001).error;
    expect(err, contains('norm_version'));
  });

  test('resume issues Range request', () async {
    final paths = await _tempPaths();
    await File(p.join(_fixtures.path, 'catalog.sqlite'))
        .copy(paths.catalogSqlite.path);
    final state = await StateDatabase.open(paths);
    final catalog = CatalogRepository(paths);
    final zstd = fixtureZstd();
    final isb = _read('book_900001.isb');
    final partial = isb.sublist(0, isb.length ~/ 2);
    await paths.tmpIsb(900001).writeAsBytes(partial);
    state.upsertDownload(
      bookId: 900001,
      status: DownloadStatus.queued.name,
      bytesDone: partial.length,
      bytesTotal: isb.length,
      updatedAt: 1,
    );

    String? seenRange;
    final dio = Dio();
    dio.httpClientAdapter = _MemoryAdapter({
      'https://example.test/books/book_900001.isb': (opts) {
        seenRange = opts.headers['Range']?.toString();
        return isb;
      },
    });
    final svc = DownloadService(
      downloader: BundleDownloader(dio),
      paths: paths,
      state: state,
      catalog: catalog,
      zstd: zstd,
      booksBaseUrl: 'https://example.test/books/',
    );
    svc.recoverQueue();
    await _waitUntil(() => state.isInstalled(900001));
    expect(seenRange, 'bytes=${partial.length}-');
  });

  test('maxConcurrent is 2', () async {
    final paths = await _tempPaths();
    final state = await StateDatabase.open(paths);
    final catalog = CatalogRepository(paths);
    final svc = DownloadService(
      downloader: BundleDownloader(Dio()),
      paths: paths,
      state: state,
      catalog: catalog,
      zstd: fixtureZstd(),
      booksBaseUrl: 'https://example.test/books/',
    );
    expect(svc.maxConcurrent, 2);
  });
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
