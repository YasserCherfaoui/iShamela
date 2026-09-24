import 'package:flutter_test/flutter_test.dart';
import 'package:ishamela/core/library/library_plan.dart';

LibraryDoc _doc(
  int id, {
  LibraryStatus status = LibraryStatus.installed,
  int size = 1024,
  int updatedAt = 1,
  int catalogVersion = 1,
  String title = 'كتاب',
}) {
  return LibraryDoc(
    bookId: id,
    title: title,
    sizeBytes: size,
    catalogVersion: catalogVersion,
    status: status,
    installedAt: updatedAt,
    updatedAt: updatedAt,
  );
}

CatalogShelfBook _book({int version = 1, int size = 1024}) {
  return CatalogShelfBook(
    title: 'كتاب',
    sizeBytes: size,
    catalogVersion: version,
    installable: true,
  );
}

LibrarySyncRequest _req({
  bool signedIn = true,
  bool autoDownload = true,
  bool cellularAllowed = true,
  LibraryLink link = LibraryLink.wifi,
  bool setupDone = true,
  int? freeBytes = 1 << 30,
  Set<int> installed = const {},
  Set<int> excluded = const {},
  Set<int> deferred = const {},
  Set<int> held = const {},
  Set<int> queued = const {},
  List<LibraryDoc> remote = const [],
  Map<int, CatalogShelfBook?>? catalog,
  List<LocalShelfInstall> localInstalls = const [],
  int nowMs = 50,
}) {
  final ids = {
    ...remote.map((d) => d.bookId),
    ...localInstalls.map((d) => d.bookId),
  };
  return LibrarySyncRequest(
    signedIn: signedIn,
    autoDownload: autoDownload,
    cellularAllowed: cellularAllowed,
    link: link,
    setupDone: setupDone,
    freeBytes: freeBytes,
    installed: installed,
    excluded: excluded,
    deferred: deferred,
    held: held,
    queued: queued,
    remote: remote,
    catalog: catalog ?? {for (final id in ids) id: _book()},
    localInstalls: localInstalls,
    nowMs: nowMs,
  );
}

void main() {
  test('guest plan is empty', () {
    final plan = planLibrarySync(
      _req(
        signedIn: false,
        remote: [_doc(1), _doc(2)],
        localInstalls: [
          const LocalShelfInstall(
            bookId: 9,
            title: 'محلي',
            sizeBytes: 10,
            catalogVersion: 1,
            installedAt: 3,
          ),
        ],
      ),
    );
    expect(plan.isEmpty, isTrue);
    expect(plan.upserts, isEmpty);
    expect(plan.deleteLocal, isEmpty);
    expect(plan.enqueue, isEmpty);
  });

  test('signed-in device enqueues account books missing locally', () {
    final plan = planLibrarySync(
      _req(remote: [_doc(1), _doc(2), _doc(3)], installed: {1}),
    );
    expect(plan.enqueue, {2, 3});
    expect(plan.hold, isEmpty);
    expect(plan.showSetupSheet, isFalse);
  });

  test('local install upserts a library doc for other devices', () {
    final plan = planLibrarySync(
      _req(
        installed: {7},
        localInstalls: [
          const LocalShelfInstall(
            bookId: 7,
            title: 'الرسالة',
            sizeBytes: 400,
            catalogVersion: 2,
            installedAt: 9,
          ),
        ],
        catalog: {7: _book(version: 2, size: 400)},
      ),
    );
    expect(plan.upserts, hasLength(1));
    expect(plan.upserts.single.bookId, 7);
    expect(plan.upserts.single.status, LibraryStatus.installed);
    expect(plan.upserts.single.title, 'الرسالة');
  });

  test('shelf over 150 MB on first sign-in shows the setup sheet', () {
    final big = kLibrarySetupBytes + 1;
    final remote = List.generate(12, (i) => _doc(i + 1, size: big ~/ 12 + 1));
    final plan = planLibrarySync(
      _req(remote: remote, setupDone: false, catalog: {
        for (final d in remote) d.bookId: _book(size: d.sizeBytes),
      }),
    );
    expect(plan.showSetupSheet, isTrue);
    expect(plan.setupBookIds, hasLength(12));
    expect(plan.enqueue, isEmpty);
  });

  test('later defers the shelf; a later single book still auto-downloads', () {
    final big = kLibrarySetupBytes + 1000;
    final remote = [_doc(1, size: big), _doc(2, size: 100)];
    final later = planAfterSetup(
      req: _req(
        remote: remote,
        setupDone: false,
        catalog: {
          1: _book(size: big),
          2: _book(size: 100),
        },
      ),
      choice: LibrarySetupChoice.later,
    );
    expect(later.defer, {1, 2});
    expect(later.enqueue, isEmpty);

    final next = planLibrarySync(
      _req(
        remote: [...remote, _doc(3, size: 50)],
        deferred: later.defer,
        catalog: {
          1: _book(size: big),
          2: _book(size: 100),
          3: _book(size: 50),
        },
      ),
    );
    expect(next.enqueue, {3});
    expect(next.manual, {1, 2});
  });

  test('download all enqueues when under the storage cap', () {
    final plan = planAfterSetup(
      req: _req(
        remote: [_doc(1, size: 10), _doc(2, size: 10)],
        setupDone: false,
      ),
      choice: LibrarySetupChoice.all,
    );
    expect(plan.enqueue, {1, 2});
  });

  test('cellular with data sync off holds the queue', () {
    final plan = planLibrarySync(
      _req(
        remote: [_doc(1)],
        link: LibraryLink.cellular,
        cellularAllowed: false,
      ),
    );
    expect(plan.enqueue, isEmpty);
    expect(plan.hold, {1});
  });

  test('wifi clears a held queue', () {
    final plan = planLibrarySync(
      _req(
        remote: [_doc(1)],
        held: {1},
        queued: {1},
        link: LibraryLink.wifi,
      ),
    );
    expect(plan.enqueue, isEmpty);
    expect(plan.clearHolds, {1});
  });

  test('finished and in-progress downloads are not resumed', () {
    final plan = planLibrarySync(
      _req(
        remote: [_doc(1), _doc(2)],
        installed: {1},
        queued: {1, 2},
        link: LibraryLink.wifi,
      ),
    );
    expect(plan.clearHolds, isEmpty);
    expect(plan.enqueue, isEmpty);
  });

  test('insufficient space shows the selection sheet and does not enqueue', () {
    final plan = planLibrarySync(
      _req(remote: [_doc(1, size: 500), _doc(2, size: 500)], freeBytes: 100),
    );
    expect(plan.showStorageSheet, isTrue);
    expect(plan.requiredBytes, 1000);
    expect(plan.enqueue, isEmpty);
  });

  test('per-device exclusion is not re-downloaded and is not a tombstone', () {
    final plan = planLibrarySync(
      _req(remote: [_doc(1), _doc(2)], excluded: {1}),
    );
    expect(plan.enqueue, {2});
    expect(plan.deleteLocal, isEmpty);
    expect(plan.upserts.where((d) => d.bookId == 1), isEmpty);
  });

  test('tombstone deletes local files and clears the exclusion', () {
    final plan = planLibrarySync(
      _req(
        remote: [_doc(4, status: LibraryStatus.removed, updatedAt: 20)],
        installed: {4},
        excluded: {4},
      ),
    );
    expect(plan.deleteLocal, {4});
    expect(plan.clearExclusions, {4});
    expect(plan.enqueue, isEmpty);
  });

  test('reinstall after a tombstone flips the doc back to installed', () {
    final plan = planLibrarySync(
      _req(
        remote: [_doc(4, status: LibraryStatus.removed, updatedAt: 5)],
        installed: {4},
        localInstalls: [
          const LocalShelfInstall(
            bookId: 4,
            title: 'عاد',
            sizeBytes: 8,
            catalogVersion: 1,
            installedAt: 30,
          ),
        ],
      ),
    );
    expect(plan.deleteLocal, isEmpty);
    expect(plan.upserts.single.status, LibraryStatus.installed);
    expect(plan.upserts.single.updatedAt, 30);
  });

  test('missing catalog book is unavailable and not retried', () {
    final plan = planLibrarySync(
      _req(
        remote: [_doc(8)],
        catalog: {8: null},
      ),
    );
    expect(plan.unavailable, {8});
    expect(plan.enqueue, isEmpty);
  });

  test('catalog version drift downloads the current edition and updates the doc', () {
    final plan = planLibrarySync(
      _req(
        remote: [_doc(3, catalogVersion: 1, size: 10)],
        catalog: {
          3: const CatalogShelfBook(
            title: 'طبعة جديدة',
            sizeBytes: 12,
            catalogVersion: 4,
            installable: true,
          ),
        },
        nowMs: 80,
      ),
    );
    expect(plan.enqueue, {3});
    expect(plan.upserts.single.catalogVersion, 4);
    expect(plan.upserts.single.title, 'طبعة جديدة');
    expect(plan.upserts.single.updatedAt, 80);
  });

  test('library union is commutative under per-doc LWW', () {
    final a = [_doc(1, updatedAt: 1, title: 'أ'), _doc(2, updatedAt: 5)];
    final b = [_doc(1, updatedAt: 9, title: 'ب'), _doc(3, updatedAt: 2)];
    final left = unionLibraryDocs(a, b);
    final right = unionLibraryDocs(b, a);
    expect(left.map((d) => d.bookId).toList(), right.map((d) => d.bookId).toList());
    expect(left.firstWhere((d) => d.bookId == 1).title, 'ب');
    expect(left.map((d) => d.bookId), [1, 2, 3]);
  });

  test('auto-download off keeps the manifest but does not enqueue', () {
    final plan = planLibrarySync(
      _req(remote: [_doc(1)], autoDownload: false),
    );
    expect(plan.enqueue, isEmpty);
    expect(plan.manual, {1});
  });
}
