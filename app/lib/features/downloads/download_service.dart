import 'dart:async';
import 'dart:developer' as developer;

import 'package:dio/dio.dart';

import 'package:ishamela/core/config.dart';
import 'package:ishamela/core/db/open_readonly.dart';
import 'package:ishamela/core/db/paths.dart';
import 'package:ishamela/core/db/state_database.dart';
import 'package:ishamela/core/models/models.dart';
import 'package:ishamela/core/net/bundle_downloader.dart';
import 'package:ishamela/features/catalog/catalog_service.dart';
import 'package:ishamela/features/downloads/batch_plan.dart';
import 'package:ishamela/features/downloads/bundle_installer.dart';

export 'package:ishamela/features/downloads/batch_plan.dart';

typedef NowMs = int Function();

/// Download queue: max 2 concurrent, pages.jsonl → on-device SQLite (SPEC-008).
class DownloadService {
  DownloadService({
    required BundleDownloader downloader,
    required this.paths,
    required this.state,
    required this.catalog,
    required this.pagesBaseUrl,
    this.sourceRevision = shamela4Revision,
    this.builtBy = appBuiltBy,
    this.installer = const BundleInstaller(),
    this.nowMs = _defaultNow,
    this.maxConcurrent = 2,
  }) : _downloader = downloader;

  final AppPaths paths;
  final StateDatabase state;
  final CatalogRepository catalog;
  final String pagesBaseUrl;
  final String sourceRevision;
  final String builtBy;
  final BundleInstaller installer;
  final NowMs nowMs;
  final int maxConcurrent;
  final BundleDownloader _downloader;

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
    if (!book.canInstallOnDevice) {
      throw StateError('book $bookId has no source_pages_path');
    }
    if (state.isInstalled(bookId)) return;
    final existing = state.listDownloads().where((r) => r['book_id'] == bookId);
    if (existing.isNotEmpty) {
      final status = DownloadStatus.parse(existing.first['status'] as String);
      if (isDownloadInFlight(status)) return;
    }
    state.upsertDownload(
      bookId: bookId,
      status: DownloadStatus.queued.name,
      bytesDone: 0,
      bytesTotal: null,
      updatedAt: nowMs(),
    );
    _notify();
    await _pump();
  }

  /// Enqueue many books; skips installed, in-flight, and uninstallable (SPEC-007/008).
  Future<DownloadBatchPlan> enqueueMany(List<Book> books) async {
    final statuses = <int, DownloadStatus?>{};
    for (final row in state.listDownloads()) {
      statuses[row['book_id'] as int] = DownloadStatus.parse(
        row['status'] as String,
      );
    }
    final plan = planBatchDownload(
      books: books,
      isInstalled: state.isInstalled,
      downloadStatus: (id) => statuses[id],
    );
    for (final book in plan.toEnqueue) {
      state.upsertDownload(
        bookId: book.bookId,
        status: DownloadStatus.queued.name,
        bytesDone: 0,
        bytesTotal: null,
        updatedAt: nowMs(),
      );
    }
    if (plan.toEnqueue.isNotEmpty) {
      _notify();
      await _pump();
    }
    return plan;
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
    await _deletePartials(bookId);
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

  /// Force a fresh on-device install (SPEC-013): uninstall if needed, then enqueue.
  Future<void> redownload(int bookId) async {
    if (state.isInstalled(bookId)) {
      await deleteInstalled(bookId);
    } else {
      await cancel(bookId);
    }
    await enqueue(bookId);
  }

  Future<void> redownloadMany(Iterable<int> bookIds) async {
    for (final id in bookIds) {
      await redownload(id);
    }
  }

  Future<void> deleteInstalledMany(Iterable<int> bookIds) async {
    for (final id in bookIds) {
      await deleteInstalled(id);
    }
  }

  Future<void> cancelMany(Iterable<int> bookIds) async {
    for (final id in bookIds) {
      await cancel(id);
    }
  }

  Future<void> pauseMany(Iterable<int> bookIds) async {
    for (final id in bookIds) {
      final rows = state.listDownloads().where((r) => r['book_id'] == id);
      if (rows.isEmpty) continue;
      final status = DownloadStatus.parse(rows.first['status'] as String);
      if (status == DownloadStatus.queued ||
          status == DownloadStatus.downloading ||
          status == DownloadStatus.verifying ||
          status == DownloadStatus.installing) {
        await pause(id);
      }
    }
  }

  Future<void> resumeMany(Iterable<int> bookIds) async {
    for (final id in bookIds) {
      final rows = state.listDownloads().where((r) => r['book_id'] == id);
      if (rows.isEmpty) continue;
      final status = DownloadStatus.parse(rows.first['status'] as String);
      if (status == DownloadStatus.paused || status == DownloadStatus.error) {
        await resume(id);
      }
    }
  }

  Future<void> _deletePartials(int bookId) async {
    for (final f in [
      paths.tmpPagesJsonl(bookId),
      paths.tmpTocJsonl(bookId),
      paths.tmpIsb(bookId),
      paths.bookSqlitePart(bookId),
    ]) {
      if (f.existsSync()) await f.delete();
    }
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
    developer.log('download start book=$bookId', name: 'DownloadService');
    try {
      final book = catalog.bookById(bookId);
      if (book == null) {
        throw StateError('book missing from catalog');
      }
      if (!book.canInstallOnDevice) {
        throw StateError('book $bookId has no source_pages_path');
      }
      await _downloadPages(book, token);
      if (token.isCancelled) return;
      developer.log('install start book=$bookId', name: 'DownloadService');
      await _install(book, token);
      if (token.isCancelled) return;
      final dest = paths.bookSqlite(bookId);
      state.upsertDownload(
        bookId: bookId,
        status: DownloadStatus.done.name,
        bytesDone: dest.existsSync() ? dest.lengthSync() : 0,
        bytesTotal: dest.existsSync() ? dest.lengthSync() : null,
        updatedAt: nowMs(),
      );
      developer.log(
        'download done book=$bookId bytes=${dest.lengthSync()}',
        name: 'DownloadService',
      );
    } on BundleInstallCancelled {
      developer.log('download cancelled book=$bookId', name: 'DownloadService');
      // cancelled — status already cleared by cancel()
    } on DioException catch (e) {
      if (CancelToken.isCancel(e) || token.isCancelled) {
        developer.log('download paused/cancelled book=$bookId', name: 'DownloadService');
        // paused/cancelled — status already set by pause/cancel
      } else {
        developer.log(
          'download network error book=$bookId: ${e.message}',
          name: 'DownloadService',
          error: e,
        );
        _fail(bookId, e.message ?? e.toString());
      }
    } catch (e, st) {
      if (!token.isCancelled) {
        developer.log(
          'download failed book=$bookId: $e',
          name: 'DownloadService',
          error: e,
          stackTrace: st,
        );
        _fail(bookId, _userFacingError(e));
      }
    } finally {
      _active.remove(bookId);
      _notify();
      await _pump();
    }
  }

  String _userFacingError(Object e) {
    final s = e.toString();
    if (s.contains('UNIQUE constraint failed')) {
      return 'تعذّر التثبيت: تعارض في أرقام الصفحات. أعد المحاولة بعد التحديث.';
    }
    if (s.contains('404') || s.contains('status code of 404')) {
      return 'الملف غير موجود على المصدر (404).';
    }
    // Keep short; full detail is in developer.log.
    if (s.length > 180) return '${s.substring(0, 180)}…';
    return s;
  }

  void _fail(int bookId, String message) {
    unawaited(_deletePartials(bookId));
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

  Future<void> _downloadPages(Book book, CancelToken token) async {
    final dest = paths.tmpPagesJsonl(book.bookId);
    var existing = 0;
    if (dest.existsSync()) {
      existing = dest.lengthSync();
    }
    state.upsertDownload(
      bookId: book.bookId,
      status: DownloadStatus.downloading.name,
      bytesDone: existing,
      bytesTotal: null,
      updatedAt: nowMs(),
    );
    _notify();

    final url = catalogUrl(pagesBaseUrl, book.sourcePagesPath!);
    await _downloader.downloadToFile(
      url: url,
      dest: dest,
      existingBytes: existing,
      cancelToken: token,
      onProgress: (done) {
        state.upsertDownload(
          bookId: book.bookId,
          status: DownloadStatus.downloading.name,
          bytesDone: done,
          bytesTotal: null,
          updatedAt: nowMs(),
        );
        _notify();
      },
    );

    // TOC is optional (SPEC-009); 404 is fine.
    final tocRel = book.sourcePagesPath!.replaceAll(
      RegExp(r'pages\.jsonl$'),
      'toc.jsonl',
    );
    if (tocRel != book.sourcePagesPath) {
      final tocDest = paths.tmpTocJsonl(book.bookId);
      try {
        await _downloader.downloadToFile(
          url: catalogUrl(pagesBaseUrl, tocRel),
          dest: tocDest,
          existingBytes: 0,
          cancelToken: token,
        );
      } on DioException catch (e) {
        if (e.response?.statusCode == 404) {
          if (tocDest.existsSync()) tocDest.deleteSync();
        } else if (!CancelToken.isCancel(e)) {
          rethrow;
        }
      }
    }
  }

  Future<void> _install(Book book, CancelToken token) async {
    state.upsertDownload(
      bookId: book.bookId,
      status: DownloadStatus.installing.name,
      bytesDone: 0,
      bytesTotal: book.pageCount,
      updatedAt: nowMs(),
    );
    _notify();

    final pages = paths.tmpPagesJsonl(book.bookId);
    if (!pages.existsSync()) {
      throw StateError('missing pages.jsonl for book ${book.bookId}');
    }

    final result = await installer.installFromPagesJsonl(
      pagesJsonl: pages,
      partFile: paths.bookSqlitePart(book.bookId),
      destFile: paths.bookSqlite(book.bookId),
      book: book,
      sourceRevision: sourceRevision,
      builtBy: builtBy,
      tocJsonl: paths.tmpTocJsonl(book.bookId),
      isCancelled: () => token.isCancelled,
      onProgress: (pagesDone) {
        state.upsertDownload(
          bookId: book.bookId,
          status: DownloadStatus.installing.name,
          bytesDone: pagesDone,
          bytesTotal: book.pageCount,
          updatedAt: nowMs(),
        );
        _notify();
      },
    );

    final catalogNorm = catalog.normVersion;
    if (catalogNorm != null && result.normVersion != catalogNorm) {
      final dest = paths.bookSqlite(book.bookId);
      if (dest.existsSync()) dest.deleteSync();
      await pages.delete();
      throw StateError(
        'norm_version mismatch: bundle=${result.normVersion} catalog=$catalogNorm',
      );
    }
    if (!supportedBookSchemaVersions.contains(result.schemaVersion)) {
      final dest = paths.bookSqlite(book.bookId);
      if (dest.existsSync()) dest.deleteSync();
      await pages.delete();
      throw StateError('unsupported schema_version ${result.schemaVersion}');
    }

    // Smoke-open read-only to ensure the file is a valid SQLite DB.
    final dest = paths.bookSqlite(book.bookId);
    final db = openReadonlySqlite(dest);
    try {
      final rows = db.select(
        "SELECT value FROM meta WHERE key = 'page_count' LIMIT 1",
      );
      if (rows.isEmpty) {
        throw StateError('installed bundle missing meta.page_count');
      }
    } finally {
      db.dispose();
    }

    await pages.delete();
    final toc = paths.tmpTocJsonl(book.bookId);
    if (toc.existsSync()) await toc.delete();

    final sizeBytes = dest.lengthSync();
    state.upsertInstalled(
      bookId: book.bookId,
      schemaVersion: int.parse(result.schemaVersion),
      normVersion: result.normVersion,
      sqliteBytes: sizeBytes,
      installedAt: nowMs(),
      pageCount: result.pageCount,
      installedSizeBytes: sizeBytes,
    );
  }
}
