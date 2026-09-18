import 'package:flutter_test/flutter_test.dart';

import 'package:ishamela/core/models/models.dart';
import 'package:ishamela/features/downloads/download_tabs.dart';

DownloadTask _task(int id, DownloadStatus status) => DownloadTask(
      bookId: id,
      status: status,
      bytesDone: 0,
      bytesTotal: 100,
      updatedAt: 1,
    );

void main() {
  test('filterDownloadTasks by tab', () {
    final tasks = [
      _task(1, DownloadStatus.downloading),
      _task(2, DownloadStatus.queued),
      _task(3, DownloadStatus.error),
      _task(4, DownloadStatus.done),
      _task(5, DownloadStatus.paused),
    ];
    expect(
      filterDownloadTasks(tasks, DownloadsTab.active).map((t) => t.bookId),
      [1, 2, 5],
    );
    expect(
      filterDownloadTasks(tasks, DownloadsTab.failed).map((t) => t.bookId),
      [3],
    );
    expect(
      filterDownloadTasks(tasks, DownloadsTab.completed).map((t) => t.bookId),
      [4],
    );
  });

  test('showDownloadProgress only for active statuses', () {
    expect(showDownloadProgress(DownloadStatus.downloading), isTrue);
    expect(showDownloadProgress(DownloadStatus.done), isFalse);
    expect(showDownloadProgress(DownloadStatus.error), isFalse);
  });
}
