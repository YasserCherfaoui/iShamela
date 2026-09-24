/// How a book's saved page differs between this device and the account.
enum ReadingDiffKind { localOnly, remoteOnly, localNewer, remoteNewer }

/// One book whose reading position is not the same locally and remotely.
class ReadingProgressDiff {
  const ReadingProgressDiff({
    required this.bookId,
    required this.kind,
    this.localPageId,
    this.remotePageId,
  });

  final int bookId;
  final ReadingDiffKind kind;
  final int? localPageId;
  final int? remotePageId;
}

/// Books with the same [pageId] on both sides are omitted.
List<ReadingProgressDiff> diffReadingProgress({
  required Iterable<({int bookId, int pageId, int updatedAt})> local,
  required Iterable<Map<String, dynamic>> remote,
}) {
  final localById = {for (final row in local) row.bookId: row};
  final remoteById = <int, ({int pageId, int updatedAt})>{};
  for (final row in remote) {
    final bookId = _asInt(row['book_id']) ?? _asInt(row['id']);
    final pageId = _asInt(row['page_id']);
    final updated = _asInt(row['updatedAt']);
    if (bookId == null || pageId == null || updated == null) continue;
    remoteById[bookId] = (pageId: pageId, updatedAt: updated);
  }

  final ids = {...localById.keys, ...remoteById.keys}.toList()..sort();
  final diffs = <ReadingProgressDiff>[];
  for (final id in ids) {
    final here = localById[id];
    final there = remoteById[id];
    if (here != null && there == null) {
      diffs.add(
        ReadingProgressDiff(
          bookId: id,
          kind: ReadingDiffKind.localOnly,
          localPageId: here.pageId,
        ),
      );
    } else if (here == null && there != null) {
      diffs.add(
        ReadingProgressDiff(
          bookId: id,
          kind: ReadingDiffKind.remoteOnly,
          remotePageId: there.pageId,
        ),
      );
    } else if (here != null && there != null && here.pageId != there.pageId) {
      final localWins = here.updatedAt >= there.updatedAt;
      diffs.add(
        ReadingProgressDiff(
          bookId: id,
          kind: localWins
              ? ReadingDiffKind.localNewer
              : ReadingDiffKind.remoteNewer,
          localPageId: here.pageId,
          remotePageId: there.pageId,
        ),
      );
    }
  }
  return diffs;
}

int? _asInt(Object? v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v);
  return null;
}
