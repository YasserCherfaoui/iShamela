// SPEC-025 library manifest planning. Pure: no Firestore, no downloads.

/// First-sign-in sheet threshold (SPEC-025 §3.4).
const int kLibrarySetupBytes = 150 * 1024 * 1024;

enum LibraryLink { wifi, cellular, offline }

enum LibraryStatus { installed, removed }

class LibraryDoc {
  const LibraryDoc({
    required this.bookId,
    required this.title,
    required this.sizeBytes,
    required this.catalogVersion,
    required this.status,
    required this.installedAt,
    required this.updatedAt,
  });

  final int bookId;
  final String title;
  final int sizeBytes;
  final int catalogVersion;
  final LibraryStatus status;
  final int installedAt;
  final int updatedAt;

  LibraryDoc copyWith({
    String? title,
    int? sizeBytes,
    int? catalogVersion,
    LibraryStatus? status,
    int? installedAt,
    int? updatedAt,
  }) {
    return LibraryDoc(
      bookId: bookId,
      title: title ?? this.title,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      catalogVersion: catalogVersion ?? this.catalogVersion,
      status: status ?? this.status,
      installedAt: installedAt ?? this.installedAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toMap() => {
        'title': title,
        'sizeBytes': sizeBytes,
        'catalogVersion': catalogVersion,
        'status': status.name,
        'installedAt': installedAt,
        'updatedAt': updatedAt,
      };

  static LibraryDoc? parse(String id, Map<String, dynamic> data) {
    final bookId = int.tryParse(id);
    if (bookId == null) return null;
    final statusName = data['status'] as String?;
    final status = LibraryStatus.values.where((s) => s.name == statusName);
    if (status.isEmpty) return null;
    return LibraryDoc(
      bookId: bookId,
      title: (data['title'] as String?) ?? '',
      sizeBytes: _asInt(data['sizeBytes']) ?? 0,
      catalogVersion: _asInt(data['catalogVersion']) ?? 0,
      status: status.first,
      installedAt: _asInt(data['installedAt']) ?? 0,
      updatedAt: _asInt(data['updatedAt']) ?? 0,
    );
  }
}

class CatalogShelfBook {
  const CatalogShelfBook({
    required this.title,
    required this.sizeBytes,
    required this.catalogVersion,
    required this.installable,
  });

  final String title;
  final int sizeBytes;
  final int catalogVersion;
  final bool installable;
}

class LocalShelfInstall {
  const LocalShelfInstall({
    required this.bookId,
    required this.title,
    required this.sizeBytes,
    required this.catalogVersion,
    required this.installedAt,
  });

  final int bookId;
  final String title;
  final int sizeBytes;
  final int catalogVersion;
  final int installedAt;
}

class LibrarySyncRequest {
  const LibrarySyncRequest({
    required this.signedIn,
    required this.autoDownload,
    required this.cellularAllowed,
    required this.link,
    required this.setupDone,
    required this.freeBytes,
    required this.installed,
    required this.excluded,
    required this.deferred,
    required this.queued,
    required this.remote,
    required this.catalog,
    required this.localInstalls,
    required this.nowMs,
  });

  final bool signedIn;
  final bool autoDownload;
  final bool cellularAllowed;
  final LibraryLink link;
  final bool setupDone;
  final int? freeBytes;
  final Set<int> installed;
  final Set<int> excluded;
  final Set<int> deferred;
  final Set<int> queued;
  final List<LibraryDoc> remote;

  /// `null` value means the book is gone from the catalog.
  final Map<int, CatalogShelfBook?> catalog;
  final List<LocalShelfInstall> localInstalls;
  final int nowMs;
}

class LibrarySyncPlan {
  const LibrarySyncPlan({
    this.upserts = const [],
    this.deleteLocal = const {},
    this.clearExclusions = const {},
    this.defer = const {},
    this.clearDeferred = const {},
    this.enqueue = const {},
    this.hold = const {},
    this.clearHolds = const {},
    this.unavailable = const {},
    this.clearUnavailable = const {},
    this.showSetupSheet = false,
    this.setupBookIds = const [],
    this.setupBytes = 0,
    this.showStorageSheet = false,
    this.storageBookIds = const [],
    this.requiredBytes = 0,
    this.manual = const {},
  });

  final List<LibraryDoc> upserts;
  final Set<int> deleteLocal;
  final Set<int> clearExclusions;
  final Set<int> defer;
  final Set<int> clearDeferred;
  final Set<int> enqueue;
  final Set<int> hold;
  final Set<int> clearHolds;
  final Set<int> unavailable;
  final Set<int> clearUnavailable;
  final bool showSetupSheet;
  final List<int> setupBookIds;
  final int setupBytes;
  final bool showStorageSheet;
  final List<int> storageBookIds;
  final int requiredBytes;

  /// Missing books the user must tap to install (auto-download off, or deferred).
  final Set<int> manual;

  bool get isEmpty =>
      upserts.isEmpty &&
      deleteLocal.isEmpty &&
      enqueue.isEmpty &&
      hold.isEmpty &&
      !showSetupSheet &&
      !showStorageSheet;
}

enum LibrarySetupChoice { all, later }

/// Per-doc LWW union. Order of [a] and [b] does not change the result.
List<LibraryDoc> unionLibraryDocs(List<LibraryDoc> a, List<LibraryDoc> b) {
  final byId = <int, LibraryDoc>{};
  void take(LibraryDoc doc) {
    final prev = byId[doc.bookId];
    if (prev == null || doc.updatedAt >= prev.updatedAt) {
      byId[doc.bookId] = doc;
    }
  }

  for (final doc in a) {
    take(doc);
  }
  for (final doc in b) {
    take(doc);
  }
  final ids = byId.keys.toList()..sort();
  return [for (final id in ids) byId[id]!];
}

LibrarySyncPlan planLibrarySync(LibrarySyncRequest req) {
  if (!req.signedIn) {
    return const LibrarySyncPlan();
  }

  final remote = <int, LibraryDoc>{};
  for (final doc in req.remote) {
    final prev = remote[doc.bookId];
    if (prev == null || doc.updatedAt >= prev.updatedAt) {
      remote[doc.bookId] = doc;
    }
  }

  final upserts = <LibraryDoc>[];
  final deleteLocal = <int>{};
  final clearExclusions = <int>{};
  final clearDeferred = <int>{};
  final unavailable = <int>{};
  final clearUnavailable = <int>{};
  final missing = <int, int>{}; // bookId → sizeBytes

  for (final install in req.localInstalls) {
    if (req.excluded.contains(install.bookId)) continue;
    final existing = remote[install.bookId];
    if (existing != null &&
        existing.status == LibraryStatus.removed &&
        existing.updatedAt >= install.installedAt) {
      continue;
    }
    if (existing == null ||
        existing.updatedAt < install.installedAt ||
        existing.status != LibraryStatus.installed) {
      final doc = LibraryDoc(
        bookId: install.bookId,
        title: install.title,
        sizeBytes: install.sizeBytes,
        catalogVersion: install.catalogVersion,
        status: LibraryStatus.installed,
        installedAt: install.installedAt,
        updatedAt: install.installedAt,
      );
      upserts.add(doc);
      remote[install.bookId] = doc;
    }
  }

  for (final doc in remote.values) {
    if (doc.status == LibraryStatus.removed) {
      if (req.installed.contains(doc.bookId)) deleteLocal.add(doc.bookId);
      clearExclusions.add(doc.bookId);
      clearDeferred.add(doc.bookId);
      clearUnavailable.add(doc.bookId);
      continue;
    }
    if (req.excluded.contains(doc.bookId)) continue;

    final catalog = req.catalog[doc.bookId];
    if (!req.catalog.containsKey(doc.bookId) ||
        catalog == null ||
        !catalog.installable) {
      unavailable.add(doc.bookId);
      continue;
    }
    clearUnavailable.add(doc.bookId);

    var effective = doc;
    if (catalog.catalogVersion != doc.catalogVersion) {
      effective = doc.copyWith(
        title: catalog.title,
        sizeBytes: catalog.sizeBytes,
        catalogVersion: catalog.catalogVersion,
        updatedAt: req.nowMs,
      );
      upserts.add(effective);
      remote[doc.bookId] = effective;
    }

    if (req.installed.contains(doc.bookId)) {
      clearDeferred.add(doc.bookId);
      continue;
    }
    missing[doc.bookId] = effective.sizeBytes;
  }

  final desiredBytes = remote.values
      .where((d) =>
          d.status == LibraryStatus.installed &&
          !req.excluded.contains(d.bookId))
      .fold<int>(0, (sum, d) => sum + d.sizeBytes);

  final manual = <int>{};
  final enqueue = <int>{};
  final hold = <int>{};
  final clearHolds = <int>{};
  var showSetup = false;
  var showStorage = false;
  final setupIds = <int>[];
  var setupBytes = 0;
  final storageIds = <int>[];
  var requiredBytes = 0;

  final needsDownload = missing.keys
      .where((id) => !req.queued.contains(id) && !req.deferred.contains(id))
      .toList();
  for (final id in missing.keys) {
    if (req.deferred.contains(id)) manual.add(id);
  }

  final blockedByNetwork =
      req.link == LibraryLink.offline ||
      (req.link == LibraryLink.cellular && !req.cellularAllowed);

  if (!req.autoDownload) {
    manual.addAll(needsDownload);
  } else if (!req.setupDone &&
      desiredBytes > kLibrarySetupBytes &&
      missing.isNotEmpty) {
    showSetup = true;
    setupIds.addAll(missing.keys);
    setupBytes = desiredBytes;
  } else {
    final pendingBytes =
        needsDownload.fold<int>(0, (sum, id) => sum + (missing[id] ?? 0));
    if (req.freeBytes != null && pendingBytes > req.freeBytes!) {
      showStorage = true;
      storageIds.addAll(needsDownload);
      requiredBytes = pendingBytes;
    } else if (blockedByNetwork) {
      hold.addAll(needsDownload);
    } else {
      enqueue.addAll(needsDownload);
      clearHolds.addAll(req.queued);
    }
  }

  if (!blockedByNetwork && req.autoDownload) {
    clearHolds.addAll(
      req.queued.where((id) => missing.containsKey(id) || req.installed.contains(id)),
    );
  } else if (blockedByNetwork) {
    hold.addAll(req.queued.where(missing.containsKey));
  }

  return LibrarySyncPlan(
    upserts: upserts,
    deleteLocal: deleteLocal,
    clearExclusions: clearExclusions,
    clearDeferred: clearDeferred,
    enqueue: enqueue,
    hold: hold,
    clearHolds: clearHolds.difference(hold),
    unavailable: unavailable,
    clearUnavailable: clearUnavailable.difference(unavailable),
    showSetupSheet: showSetup,
    setupBookIds: setupIds,
    setupBytes: setupBytes,
    showStorageSheet: showStorage,
    storageBookIds: storageIds,
    requiredBytes: requiredBytes,
    manual: manual,
  );
}

/// After the first-setup sheet.
///
/// [LibrarySetupChoice.all] with an empty [selected] downloads every missing
/// book. A non-empty [selected] downloads that subset and defers the rest.
/// [LibrarySetupChoice.later] defers the whole missing set (CTA on tap).
LibrarySyncPlan planAfterSetup({
  required LibrarySyncRequest req,
  required LibrarySetupChoice choice,
  Set<int> selected = const {},
}) {
  final base = planLibrarySync(req.copyWith(setupDone: true));
  final missing = <int>{
    for (final doc in req.remote)
      if (doc.status == LibraryStatus.installed &&
          !req.installed.contains(doc.bookId) &&
          !req.excluded.contains(doc.bookId) &&
          !base.unavailable.contains(doc.bookId))
        doc.bookId,
  };
  if (choice == LibrarySetupChoice.later) {
    return LibrarySyncPlan(
      upserts: base.upserts,
      deleteLocal: base.deleteLocal,
      clearExclusions: base.clearExclusions,
      defer: missing,
      clearDeferred: base.clearDeferred.difference(missing),
      unavailable: base.unavailable,
      clearUnavailable: base.clearUnavailable,
      manual: missing,
    );
  }
  if (selected.isEmpty) return base;
  final keep = selected.intersection(missing);
  final defer = missing.difference(keep);
  return LibrarySyncPlan(
    upserts: base.upserts,
    deleteLocal: base.deleteLocal,
    clearExclusions: base.clearExclusions,
    defer: defer,
    clearDeferred: base.clearDeferred.difference(defer),
    enqueue: base.enqueue.intersection(keep),
    hold: base.hold.intersection(keep),
    clearHolds: base.clearHolds,
    unavailable: base.unavailable,
    clearUnavailable: base.clearUnavailable,
    showStorageSheet: base.showStorageSheet,
    storageBookIds: base.storageBookIds.where(keep.contains).toList(),
    requiredBytes: base.requiredBytes,
    manual: defer,
  );
}

extension on LibrarySyncRequest {
  LibrarySyncRequest copyWith({bool? setupDone}) {
    return LibrarySyncRequest(
      signedIn: signedIn,
      autoDownload: autoDownload,
      cellularAllowed: cellularAllowed,
      link: link,
      setupDone: setupDone ?? this.setupDone,
      freeBytes: freeBytes,
      installed: installed,
      excluded: excluded,
      deferred: deferred,
      queued: queued,
      remote: remote,
      catalog: catalog,
      localInstalls: localInstalls,
      nowMs: nowMs,
    );
  }
}

int? _asInt(Object? v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  return null;
}
