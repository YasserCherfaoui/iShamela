import 'package:ishamela/core/models/models.dart';

/// Which download rows count as "already in the queue" for batch enqueue (SPEC-007).
bool isDownloadInFlight(DownloadStatus? status) {
  if (status == null) return false;
  switch (status) {
    case DownloadStatus.queued:
    case DownloadStatus.downloading:
    case DownloadStatus.verifying:
    case DownloadStatus.installing:
    case DownloadStatus.paused:
      return true;
    case DownloadStatus.done:
    case DownloadStatus.error:
      return false;
  }
}

/// Plan a batch download: skip installed and in-flight books; sum sizes.
class DownloadBatchPlan {
  const DownloadBatchPlan({
    required this.toEnqueue,
    required this.isbBytesTotal,
    required this.sqliteBytesTotal,
    required this.skippedInstalled,
    required this.skippedInFlight,
  });

  final List<Book> toEnqueue;
  final int isbBytesTotal;
  final int sqliteBytesTotal;
  final int skippedInstalled;
  final int skippedInFlight;

  int get missingCount => toEnqueue.length;
}

DownloadBatchPlan planBatchDownload({
  required List<Book> books,
  required bool Function(int bookId) isInstalled,
  required DownloadStatus? Function(int bookId) downloadStatus,
}) {
  final toEnqueue = <Book>[];
  var skippedInstalled = 0;
  var skippedInFlight = 0;
  var isb = 0;
  var sqlite = 0;

  for (final book in books) {
    if (!book.canInstallOnDevice) {
      continue;
    }
    if (isInstalled(book.bookId)) {
      skippedInstalled++;
      continue;
    }
    if (isDownloadInFlight(downloadStatus(book.bookId))) {
      skippedInFlight++;
      continue;
    }
    toEnqueue.add(book);
    isb += book.isbBytes;
    sqlite += book.sqliteBytes;
  }

  return DownloadBatchPlan(
    toEnqueue: toEnqueue,
    isbBytesTotal: isb,
    sqliteBytesTotal: sqlite,
    skippedInstalled: skippedInstalled,
    skippedInFlight: skippedInFlight,
  );
}
