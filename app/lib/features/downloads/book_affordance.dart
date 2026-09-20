import 'package:ishamela/core/models/models.dart';

/// Derived trailing affordance for a book row (SPEC-020 DL-01).
enum BookAffordanceKind {
  installed,
  progress,
  paused,
  download,
  unavailable,
}

class BookAffordance {
  const BookAffordance({
    required this.kind,
    this.status,
    this.progress,
  });

  final BookAffordanceKind kind;
  final DownloadStatus? status;

  /// 0–1 when known; null → indeterminate ring.
  final double? progress;
}

/// Maps install registry + queue status → affordance (SPEC-020 DL-01).
BookAffordance mapBookAffordance({
  required bool installed,
  required bool canInstallOnDevice,
  DownloadStatus? status,
  int bytesDone = 0,
  int? bytesTotal,
}) {
  // `done` means install finished; treat as installed even if a stale
  // rebuild races the registry read.
  if (installed || status == DownloadStatus.done) {
    return const BookAffordance(kind: BookAffordanceKind.installed);
  }
  if (!canInstallOnDevice) {
    return const BookAffordance(kind: BookAffordanceKind.unavailable);
  }
  if (status == DownloadStatus.paused) {
    final p = _progress(bytesDone, bytesTotal);
    return BookAffordance(
      kind: BookAffordanceKind.paused,
      status: status,
      progress: p,
    );
  }
  if (status == DownloadStatus.queued ||
      status == DownloadStatus.downloading ||
      status == DownloadStatus.verifying ||
      status == DownloadStatus.installing) {
    final indeterminate = status == DownloadStatus.queued ||
        status == DownloadStatus.verifying ||
        bytesTotal == null ||
        bytesTotal <= 0;
    return BookAffordance(
      kind: BookAffordanceKind.progress,
      status: status,
      progress: indeterminate ? null : _progress(bytesDone, bytesTotal),
    );
  }
  return const BookAffordance(kind: BookAffordanceKind.download);
}

double? _progress(int done, int? total) {
  if (total == null || total <= 0) return null;
  return (done / total).clamp(0.0, 1.0);
}

/// Bulk target set at confirm/execution time (SPEC-020 DL-06).
List<Book> downloadableNotInstalledNotQueued({
  required List<Book> books,
  required bool Function(int bookId) isInstalled,
  required DownloadStatus? Function(int bookId) downloadStatus,
}) {
  return books.where((b) {
    if (!b.canInstallOnDevice) return false;
    if (isInstalled(b.bookId)) return false;
    final s = downloadStatus(b.bookId);
    if (s == DownloadStatus.queued ||
        s == DownloadStatus.downloading ||
        s == DownloadStatus.verifying ||
        s == DownloadStatus.installing ||
        s == DownloadStatus.paused) {
      return false;
    }
    return true;
  }).toList();
}
