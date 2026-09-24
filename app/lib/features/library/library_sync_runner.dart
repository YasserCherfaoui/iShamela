import 'package:ishamela/core/db/state_database.dart';
import 'package:ishamela/core/library/library_plan.dart';
import 'package:ishamela/core/models/models.dart';
import 'package:ishamela/features/catalog/catalog_service.dart';
import 'package:ishamela/features/downloads/download_service.dart';

/// Applies a [LibrarySyncPlan] to local flags and the download queue.
Future<void> applyLibraryPlan({
  required StateDatabase state,
  required DownloadService downloads,
  required LibrarySyncPlan plan,
}) async {
  for (final id in plan.clearExclusions) {
    state.clearLibraryExclusion(id);
  }
  for (final id in plan.clearDeferred) {
    state.markLibraryDeferred(id, on: false);
  }
  for (final id in plan.defer) {
    state.markLibraryDeferred(id, on: true);
  }
  for (final id in plan.clearUnavailable) {
    state.markLibraryUnavailable(id, on: false);
  }
  for (final id in plan.unavailable) {
    state.markLibraryUnavailable(id, on: true);
  }
  for (final id in plan.clearHolds) {
    state.markLibraryHeld(id, on: false);
    if (state.isInstalled(id)) continue;
    final rows = state.listDownloads().where((r) => r['book_id'] == id);
    if (rows.isEmpty) continue;
    final status = DownloadStatus.parse(rows.first['status'] as String);
    if (status == DownloadStatus.paused) {
      await downloads.resume(id);
    }
  }
  for (final id in plan.deleteLocal) {
    await downloads.deleteInstalled(id);
    state.clearLibraryExclusion(id);
    state.markLibraryDeferred(id, on: false);
    state.markLibraryHeld(id, on: false);
  }
  for (final id in plan.hold) {
    state.markLibraryHeld(id, on: true);
    state.markLibraryAuto(id, on: true);
    await downloads.enqueuePaused(id);
  }
  for (final id in plan.enqueue) {
    state.markLibraryHeld(id, on: false);
    state.markLibraryDeferred(id, on: false);
    state.markLibraryAuto(id, on: true);
    await downloads.enqueue(id);
  }
}

LibrarySyncRequest librarySyncRequest({
  required StateDatabase state,
  required CatalogRepository catalog,
  required List<LibraryDoc> remote,
  required LibraryLink link,
  required int? freeBytes,
  required bool signedIn,
}) {
  final version = catalog.catalogVersion ?? 0;
  final installed = state.installedBookIds().toSet();
  final localInstalls = <LocalShelfInstall>[];
  for (final id in installed) {
    final book = catalog.bookById(id);
    localInstalls.add(
      LocalShelfInstall(
        bookId: id,
        title: book?.title ?? '',
        sizeBytes: state.installedSizeBytes(id) ?? book?.sqliteBytes ?? 0,
        catalogVersion: version,
        installedAt: state.installedAt(id) ?? 0,
      ),
    );
  }
  final ids = {...remote.map((d) => d.bookId), ...installed};
  final catalogHits = <int, CatalogShelfBook?>{};
  for (final id in ids) {
    final book = catalog.bookById(id);
    if (book == null) {
      catalogHits[id] = null;
    } else {
      catalogHits[id] = CatalogShelfBook(
        title: book.title,
        sizeBytes: book.sqliteBytes,
        catalogVersion: version,
        installable: book.canInstallOnDevice,
      );
    }
  }
  final queued = state
      .listDownloads()
      .map((r) => r['book_id'] as int)
      .toSet();
  final sync = state.getSyncState();
  return LibrarySyncRequest(
    signedIn: signedIn,
    autoDownload: sync.autoDownload,
    cellularAllowed: sync.cellularAllowed,
    link: link,
    setupDone: state.librarySetupDone,
    freeBytes: freeBytes,
    installed: installed,
    excluded: state.libraryExclusionIds(),
    deferred: state.libraryDeferredIds(),
    held: state.libraryHeldIds(),
    queued: queued,
    remote: remote,
    catalog: catalogHits,
    localInstalls: localInstalls,
    nowMs: DateTime.now().millisecondsSinceEpoch,
  );
}
