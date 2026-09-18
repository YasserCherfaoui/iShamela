import 'package:ishamela/core/models/models.dart';

/// Downloads page tabs (SPEC-013).
enum DownloadsTab { active, failed, completed }

bool isActiveDownloadStatus(DownloadStatus s) {
  switch (s) {
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

bool showDownloadProgress(DownloadStatus s) => isActiveDownloadStatus(s);

List<DownloadTask> filterDownloadTasks(
  List<DownloadTask> tasks,
  DownloadsTab tab,
) {
  switch (tab) {
    case DownloadsTab.active:
      return tasks.where((t) => isActiveDownloadStatus(t.status)).toList();
    case DownloadsTab.failed:
      return tasks.where((t) => t.status == DownloadStatus.error).toList();
    case DownloadsTab.completed:
      return tasks.where((t) => t.status == DownloadStatus.done).toList();
  }
}
