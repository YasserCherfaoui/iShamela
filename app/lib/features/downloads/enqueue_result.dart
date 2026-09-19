import 'package:ishamela/core/models/models.dart';

/// Result of [DownloadService.enqueue] (SPEC-020 DL-03/04).
enum EnqueueResult {
  /// New queue task created (or error→re-queued).
  started,

  /// Already installed — no-op; UI should show already-installed snackbar.
  alreadyInstalled,

  /// Already queued / in-flight / paused — no-op.
  alreadyQueued,

  /// Book missing or not downloadable.
  rejected,
}

bool isActiveOrQueued(DownloadStatus? status) {
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
