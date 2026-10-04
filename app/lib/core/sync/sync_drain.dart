/// Outbox drain (SPEC-028 §6). Beacons, then push, then pull.
library;

class OutboxItem {
  const OutboxItem({
    required this.id,
    required this.kind,
    required this.payload,
    required this.createdAt,
    this.tableName,
    this.recordKey,
    this.attempts = 0,
    this.lastError,
  });

  final int id;
  final String kind;
  final Map<String, Object?> payload;
  final String? tableName;
  final String? recordKey;
  final int attempts;
  final String? lastError;

  /// Milliseconds. After a failure this is the time of that attempt.
  final int createdAt;
}

class PushBatchResult {
  const PushBatchResult({
    required this.appliedKeys,
    required this.staleKeys,
    required this.rejected,
  });

  final Set<String> appliedKeys;
  final Set<String> staleKeys;
  final Map<String, String> rejected;
}

class PulledChange {
  const PulledChange({required this.table, required this.record});

  final String table;
  final Map<String, Object?> record;
}

class PullBatch {
  const PullBatch({
    required this.changes,
    required this.nextCursor,
    required this.hasMore,
  });

  final List<PulledChange> changes;
  final int nextCursor;
  final bool hasMore;
}

abstract class SyncTransport {
  Future<void> postProgress(
    List<Map<String, Object?>> items, {
    required Duration timeout,
  });

  Future<PushBatchResult> push(
    List<Map<String, Object?>> changes, {
    required Duration timeout,
  });

  Future<PullBatch> pull({required int since, required Duration timeout});

  String get progressUrl;
}

class OutboxFailure {
  const OutboxFailure({
    required this.id,
    required this.attempts,
    required this.error,
  });

  final int id;
  final int attempts;
  final String error;
}

class DrainEffects {
  const DrainEffects({
    required this.deleteIds,
    required this.failures,
    required this.cursor,
    required this.pulled,
    required this.syncIssues,
    required this.pullCompleted,
  });

  final List<int> deleteIds;
  final List<OutboxFailure> failures;
  final int cursor;
  final List<PulledChange> pulled;
  final bool syncIssues;
  final bool pullCompleted;
}

bool isDeviceUuid(String? value) =>
    value != null && _deviceUuid.hasMatch(value);

final _deviceUuid = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
);

const int beaconBatch = 50;
const int changeBatch = 500;
const int maxOutboxAttempts = 10;

/// 1s, 2s, 4s, … capped at 256s.
Duration backoffForAttempts(int attempts) {
  if (attempts <= 0) return Duration.zero;
  final shift = (attempts - 1).clamp(0, 8);
  return Duration(seconds: 1 << shift);
}

bool outboxDue(OutboxItem item, DateTime now) {
  if (item.attempts >= maxOutboxAttempts) return false;
  if (item.attempts <= 0) return true;
  final failedAt = DateTime.fromMillisecondsSinceEpoch(item.createdAt);
  return !now.isBefore(failedAt.add(backoffForAttempts(item.attempts)));
}

/// Newer remote timestamp wins. Equal timestamps stay local.
bool remoteWins({required int incoming, required int? local}) {
  if (local == null) return true;
  return incoming > local;
}

String changeKey(String? table, String? recordKey) => '$table|$recordKey';

class SyncDrainer {
  const SyncDrainer();

  Future<DrainEffects> drain({
    required List<OutboxItem> outbox,
    required int cursor,
    required SyncTransport transport,
    required Duration timeout,
    DateTime? now,
  }) async {
    final clock = now ?? DateTime.now();
    final deleteIds = <int>[];
    final failures = <OutboxFailure>[];
    final pulled = <PulledChange>[];
    var nextCursor = cursor;
    var syncIssues = outbox.any((row) => row.attempts >= maxOutboxAttempts);
    var pullCompleted = false;

    final beacons = outbox
        .where(
          (row) =>
              row.kind == 'beacon' &&
              outboxDue(row, clock) &&
              isDeviceUuid(row.payload['deviceId'] as String?),
        )
        .toList();
    for (var i = 0; i < beacons.length; i += beaconBatch) {
      final batch = beacons.skip(i).take(beaconBatch).toList();
      try {
        await transport.postProgress(
          batch.map((row) => row.payload).toList(),
          timeout: timeout,
        );
      } catch (_) {
        return DrainEffects(
          deleteIds: deleteIds,
          failures: failures,
          cursor: nextCursor,
          pulled: pulled,
          syncIssues: syncIssues,
          pullCompleted: pullCompleted,
        );
      }
      deleteIds.addAll(batch.map((row) => row.id));
    }

    final changes = outbox
        .where((row) => row.kind == 'change' && outboxDue(row, clock))
        .toList();
    for (var i = 0; i < changes.length; i += changeBatch) {
      final batch = changes.skip(i).take(changeBatch).toList();
      final PushBatchResult result;
      try {
        result = await transport.push([
          for (final row in batch)
            {'table': row.tableName, 'record': row.payload},
        ], timeout: timeout);
      } catch (_) {
        return DrainEffects(
          deleteIds: deleteIds,
          failures: failures,
          cursor: nextCursor,
          pulled: pulled,
          syncIssues: syncIssues,
          pullCompleted: pullCompleted,
        );
      }
      for (final row in batch) {
        final key = changeKey(row.tableName, row.recordKey);
        if (result.appliedKeys.contains(key) ||
            result.staleKeys.contains(key)) {
          deleteIds.add(row.id);
          continue;
        }
        final attempts = row.attempts + 1;
        if (attempts >= maxOutboxAttempts) syncIssues = true;
        failures.add(
          OutboxFailure(
            id: row.id,
            attempts: attempts,
            error: result.rejected[key] ?? 'REJECTED',
          ),
        );
      }
    }

    while (true) {
      final PullBatch page;
      try {
        page = await transport.pull(since: nextCursor, timeout: timeout);
        pullCompleted = true;
      } catch (_) {
        break;
      }
      pulled.addAll(page.changes);
      nextCursor = page.nextCursor;
      if (!page.hasMore) break;
    }

    return DrainEffects(
      deleteIds: deleteIds,
      failures: failures,
      cursor: nextCursor,
      pulled: pulled,
      syncIssues: syncIssues,
      pullCompleted: pullCompleted,
    );
  }
}
