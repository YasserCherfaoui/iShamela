import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import 'package:ishamela/core/compress/zstd.dart';
import 'package:ishamela/core/config.dart';
import 'package:ishamela/core/db/paths.dart';
import 'package:ishamela/core/db/state_database.dart';
import 'package:ishamela/core/models/models.dart';
import 'package:ishamela/features/catalog/catalog_service.dart';

typedef NowMs = int Function();

/// Download queue: max 2 concurrent, resumable Range GETs (SPEC-004).
class DownloadService {
  DownloadService({
    required this.dio,
    required this.paths,
    required this.state,
    required this.catalog,
    required this.zstd,
    required this.booksBaseUrl,
    this.nowMs = _defaultNow,
    this.maxConcurrent = 2,
  });

  final Dio dio;
  final AppPaths paths;
  final StateDatabase state;
  final CatalogRepository catalog;
  final ZstdDecompressor zstd;
  final String booksBaseUrl;
  final NowMs nowMs;
  final int maxConcurrent;

  final _active = <int, CancelToken>{};
  final _controllers = <void Function()>[];
  bool _pumping = false;

  static int _defaultNow() => DateTime.now().millisecondsSinceEpoch;

  void addListener(void Function() listener) => _controllers.add(listener);
  void removeListener(void Function() listener) => _controllers.remove(listener);
  void _notify() {
    for (final l in List.of(_controllers)) {
      l();
    }
  }

  List<DownloadTask> listTasks() {
    return state.listDownloads().map((r) {
      return DownloadTask(
        bookId: r['book_id'] as int,
        status: DownloadStatus.parse(r['status'] as String),
        bytesDone: r['bytes_done'] as int,
        bytesTotal: r['bytes_total'] as int?,
        error: r['error'] as String?,
        updatedAt: r['updated_at'] as int,
      );
    }).toList();
  }

  /// Rebuild queue after restart: re-queue interrupted downloads.
  void recoverQueue() {
    for (final row in state.listDownloads()) {
      final status = DownloadStatus.parse(row['status'] as String);
      final bookId = row['book_id'] as int;
      if (status == DownloadStatus.downloading ||
          status == DownloadStatus.verifying ||
          status == DownloadStatus.installing) {
        state.upsertDownload(
          bookId: bookId,
          status: DownloadStatus.queued.name,
          bytesDone: row['bytes_done'] as int,
          bytesTotal: row['bytes_total'] as int?,
          updatedAt: nowMs(),
        );
      }
    }
    unawaited(_pump());
  }

  Future<void> enqueue(int bookId) async {
    final book = catalog.bookById(bookId);
    if (book == null) {
      throw StateError('book $bookId not in catalog');
    }
    if (state.isInstalled(bookId)) return;
    state.upsertDownload(
      bookId: bookId,
      status: DownloadStatus.queued.name,
      bytesDone: 0,
      bytesTotal: book.isbBytes,
      updatedAt: nowMs(),
    );
    _notify();
    await _pump();
  }

  Future<void> pause(int bookId) async {
    final token = _active.remove(bookId);
    token?.cancel('paused');
    final rows = state.listDownloads().where((r) => r['book_id'] == bookId);
    final row = rows.isEmpty ? null : rows.first;
    state.upsertDownload(
      bookId: bookId,
      status: DownloadStatus.paused.name,
      bytesDone: row?['bytes_done'] as int? ?? 0,
      bytesTotal: row?['bytes_total'] as int?,
      updatedAt: nowMs(),
    );
    _notify();
    await _pump();
  }

  Future<void> resume(int bookId) async {
    final rows = state.listDownloads().where((r) => r['book_id'] == bookId);
    final row = rows.isEmpty ? null : rows.first;
    state.upsertDownload(
      bookId: bookId,
      status: DownloadStatus.queued.name,
      bytesDone: row?['bytes_done'] as int? ?? 0,
      bytesTotal: row?['bytes_total'] as int?,
      updatedAt: nowMs(),
    );
    _notify();
    await _pump();
  }

  Future<void> cancel(int bookId) async {
    final token = _active.remove(bookId);
    token?.cancel('cancelled');
    state.deleteDownload(bookId);
    final tmp = paths.tmpIsb(bookId);
    if (tmp.existsSync()) await tmp.delete();
    final part = paths.bookSqlitePart(bookId);
    if (part.existsSync()) await part.delete();
    _notify();
    await _pump();
  }

  Future<void> deleteInstalled(int bookId) async {
    await cancel(bookId);
    state.deleteInstalled(bookId);
    final file = paths.bookSqlite(bookId);
    if (file.existsSync()) await file.delete();
    _notify();
  }

  Future<void> _pump() async {
    if (_pumping) return;
    _pumping = true;
    try {
      while (_active.length < maxConcurrent) {
        final next = state.listDownloads().where(
          (r) =>
              r['status'] == DownloadStatus.queued.name &&
              !_active.containsKey(r['book_id'] as int),
        );
        if (next.isEmpty) break;
        final bookId = next.first['book_id'] as int;
        _active[bookId] = CancelToken();
        unawaited(_runOne(bookId));
      }
    } finally {
      _pumping = false;
    }
  }

  Future<void> _runOne(int bookId) async {
    final token = _active[bookId] ?? CancelToken();
    _active[bookId] = token;
    try {
      final book = catalog.bookById(bookId);
      if (book == null) {
        throw StateError('book missing from catalog');
      }
      await _download(book, token);
      if (token.isCancelled) return;
      await _verify(book);
      if (token.isCancelled) return;
      await _install(book);
      state.upsertDownload(
        bookId: bookId,
        status: DownloadStatus.done.name,
        bytesDone: book.isbBytes,
        bytesTotal: book.isbBytes,
        updatedAt: nowMs(),
      );
    } on DioException catch (e) {
      if (CancelToken.isCancel(e) || token.isCancelled) {
        // paused/cancelled — status already set by pause/cancel
      } else {
        _fail(bookId, e.message ?? e.toString());
      }
    } catch (e) {
      if (!token.isCancelled) {
        _fail(bookId, e.toString());
      }
    } finally {
      _active.remove(bookId);
      _notify();
      await _pump();
    }
  }

  void _fail(int bookId, String message) {
    final tmp = paths.tmpIsb(bookId);
    if (tmp.existsSync()) tmp.deleteSync();
    final part = paths.bookSqlitePart(bookId);
    if (part.existsSync()) part.deleteSync();
    final dest = paths.bookSqlite(bookId);
    if (dest.existsSync()) dest.deleteSync();
    state.upsertDownload(
      bookId: bookId,
      status: DownloadStatus.error.name,
      bytesDone: 0,
      error: message,
      updatedAt: nowMs(),
    );
  }

  Future<void> _download(Book book, CancelToken token) async {
    final dest = paths.tmpIsb(book.bookId);
    var existing = 0;
    if (dest.existsSync()) {
      existing = dest.lengthSync();
    }
    state.upsertDownload(
      bookId: book.bookId,
      status: DownloadStatus.downloading.name,
      bytesDone: existing,
      bytesTotal: book.isbBytes,
      updatedAt: nowMs(),
    );
    _notify();

    final url = catalogUrl(booksBaseUrl, book.filename);
    final headers = <String, dynamic>{};
    if (existing > 0) {
      headers['Range'] = 'bytes=$existing-';
    }
    final response = await dio.get<ResponseBody>(
      url,
      options: Options(
        responseType: ResponseType.stream,
        headers: headers,
        // 206 Partial Content or 200 OK both acceptable
        validateStatus: (s) => s != null && (s == 200 || s == 206),
      ),
      cancelToken: token,
    );
    final sink = dest.openWrite(
      mode: response.statusCode == 206 ? FileMode.append : FileMode.write,
    );
    var done = response.statusCode == 206 ? existing : 0;
    try {
      await for (final chunk in response.data!.stream) {
        sink.add(chunk);
        done += chunk.length;
        state.upsertDownload(
          bookId: book.bookId,
          status: DownloadStatus.downloading.name,
          bytesDone: done,
          bytesTotal: book.isbBytes,
          updatedAt: nowMs(),
        );
        _notify();
      }
    } finally {
      await sink.close();
    }
  }

  Future<void> _verify(Book book) async {
    state.upsertDownload(
      bookId: book.bookId,
      status: DownloadStatus.verifying.name,
      bytesDone: book.isbBytes,
      bytesTotal: book.isbBytes,
      updatedAt: nowMs(),
    );
    _notify();
    final file = paths.tmpIsb(book.bookId);
    final digest = sha256File(file);
    if (digest != book.sha256) {
      await file.delete();
      throw StateError('sha256 mismatch for book ${book.bookId}');
    }
  }

  Future<void> _install(Book book) async {
    state.upsertDownload(
      bookId: book.bookId,
      status: DownloadStatus.installing.name,
      bytesDone: book.isbBytes,
      bytesTotal: book.isbBytes,
      updatedAt: nowMs(),
    );
    _notify();

    final isb = paths.tmpIsb(book.bookId);
    final compressed = await isb.readAsBytes();
    final plain = await zstd.decompress(Uint8List.fromList(compressed));
    final part = paths.bookSqlitePart(book.bookId);
    await part.writeAsBytes(plain, flush: true);

    final db = openReadonlySqlite(part);
    late final String schemaVersion;
    late final String normVersion;
    try {
      final schemaRows = db.select(
        "SELECT value FROM meta WHERE key = 'schema_version' LIMIT 1",
      );
      final normRows = db.select(
        "SELECT value FROM meta WHERE key = 'norm_version' LIMIT 1",
      );
      if (schemaRows.isEmpty || normRows.isEmpty) {
        throw StateError('bundle missing meta keys');
      }
      schemaVersion = schemaRows.first['value'] as String;
      normVersion = normRows.first['value'] as String;
    } finally {
      db.dispose();
    }

    if (!supportedBookSchemaVersions.contains(schemaVersion)) {
      await part.delete();
      await isb.delete();
      throw StateError('unsupported schema_version $schemaVersion');
    }
    final catalogNorm = catalog.normVersion;
    if (catalogNorm != null && normVersion != catalogNorm) {
      await part.delete();
      await isb.delete();
      throw StateError(
        'norm_version mismatch: bundle=$normVersion catalog=$catalogNorm',
      );
    }

    final dest = paths.bookSqlite(book.bookId);
    if (dest.existsSync()) await dest.delete();
    await part.rename(dest.path);
    await isb.delete();

    state.upsertInstalled(
      bookId: book.bookId,
      schemaVersion: int.parse(schemaVersion),
      normVersion: normVersion,
      sqliteBytes: dest.lengthSync(),
      installedAt: nowMs(),
    );
  }
}
