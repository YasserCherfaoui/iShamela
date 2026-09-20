import 'package:flutter_test/flutter_test.dart';
import 'package:ishamela/core/models/models.dart';
import 'package:ishamela/features/downloads/book_affordance.dart';
import 'package:ishamela/features/downloads/download_snack_state.dart';

Book _book(int id, {bool canInstall = true}) => Book(
      bookId: id,
      title: 't$id',
      categoryId: 1,
      pageCount: 10,
      isbBytes: 100,
      sqliteBytes: 200,
      sha256: 'a' * 64,
      filename: 'book_$id.isb',
      sourcePagesPath: canInstall ? 'pages/x' : null,
    );

void main() {
  group('mapBookAffordance', () {
    test('installed wins over queue status', () {
      final a = mapBookAffordance(
        installed: true,
        canInstallOnDevice: true,
        status: DownloadStatus.downloading,
      );
      expect(a.kind, BookAffordanceKind.installed);
    });

    test('unavailable when not installable', () {
      final a = mapBookAffordance(
        installed: false,
        canInstallOnDevice: false,
      );
      expect(a.kind, BookAffordanceKind.unavailable);
    });

    test('paused uses gold progress', () {
      final a = mapBookAffordance(
        installed: false,
        canInstallOnDevice: true,
        status: DownloadStatus.paused,
        bytesDone: 50,
        bytesTotal: 100,
      );
      expect(a.kind, BookAffordanceKind.paused);
      expect(a.progress, 0.5);
    });

    test('queued is indeterminate progress', () {
      final a = mapBookAffordance(
        installed: false,
        canInstallOnDevice: true,
        status: DownloadStatus.queued,
        bytesDone: 0,
        bytesTotal: 100,
      );
      expect(a.kind, BookAffordanceKind.progress);
      expect(a.progress, isNull);
    });

    test('downloading with total is determinate', () {
      final a = mapBookAffordance(
        installed: false,
        canInstallOnDevice: true,
        status: DownloadStatus.downloading,
        bytesDone: 25,
        bytesTotal: 100,
      );
      expect(a.kind, BookAffordanceKind.progress);
      expect(a.progress, 0.25);
    });

    test('download when idle', () {
      final a = mapBookAffordance(
        installed: false,
        canInstallOnDevice: true,
      );
      expect(a.kind, BookAffordanceKind.download);
    });

    test('done status shows as installed', () {
      final a = mapBookAffordance(
        installed: false,
        canInstallOnDevice: true,
        status: DownloadStatus.done,
      );
      expect(a.kind, BookAffordanceKind.installed);
    });
  });

  group('downloadableNotInstalledNotQueued', () {
    test('excludes installed, queued, and uninstallable', () {
      final books = [
        _book(1),
        _book(2),
        _book(3),
        _book(4, canInstall: false),
      ];
      final targets = downloadableNotInstalledNotQueued(
        books: books,
        isInstalled: (id) => id == 1,
        downloadStatus: (id) => id == 2 ? DownloadStatus.queued : null,
      );
      expect(targets.map((b) => b.bookId), [3]);
    });
  });

  group('snack coalesce', () {
    test('first enqueue creates progress snack', () {
      final s = coalesceEnqueue(current: null, bookId: 1, title: 'A');
      expect(s.phase, DownloadSnackPhase.progress);
      expect(s.count, 1);
      expect(s.primaryTitle, 'A');
    });

    test('second enqueue coalesces count', () {
      final first = coalesceEnqueue(current: null, bookId: 1, title: 'A');
      final second = coalesceEnqueue(current: first, bookId: 2, title: 'B');
      expect(second.count, 2);
      expect(second.primaryTitle, 'A');
    });

    test('duplicate id does not grow', () {
      final first = coalesceEnqueue(current: null, bookId: 1, title: 'A');
      final again = coalesceEnqueue(current: first, bookId: 1, title: 'A');
      expect(again.count, 1);
    });
  });
}
