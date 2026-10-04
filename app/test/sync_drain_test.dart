import 'package:flutter_test/flutter_test.dart';

import 'package:ishamela/core/sync/sync_drain.dart';

const _deviceId = '11111111-1111-4111-8111-111111111111';

OutboxItem _row({
  required int id,
  required String kind,
  String? table,
  String? key,
  int attempts = 0,
  int createdAt = 0,
  Map<String, Object?>? payload,
}) {
  return OutboxItem(
    id: id,
    kind: kind,
    tableName: table,
    recordKey: key,
    payload: payload ?? const {},
    createdAt: createdAt,
    attempts: attempts,
  );
}

class _ScriptedTransport implements SyncTransport {
  final calls = <String>[];

  PushBatchResult pushResult = const PushBatchResult(
    appliedKeys: {},
    staleKeys: {},
    rejected: {},
  );

  var pullPage = const PullBatch(changes: [], nextCursor: 7, hasMore: false);

  @override
  String get progressUrl => 'https://example.test/v1/progress';

  @override
  Future<void> postProgress(
    List<Map<String, Object?>> items, {
    required Duration timeout,
  }) async {
    calls.add('progress');
  }

  @override
  Future<PushBatchResult> push(
    List<Map<String, Object?>> changes, {
    required Duration timeout,
  }) async {
    calls.add('push');
    return pushResult;
  }

  @override
  Future<PullBatch> pull({required int since, required Duration timeout}) async {
    calls.add('pull');
    return pullPage;
  }
}

void main() {
  const drainer = SyncDrainer();
  const timeout = Duration(seconds: 4);

  test('drain posts beacons, then pushes, then pulls', () async {
    final transport = _ScriptedTransport()
      ..pushResult = const PushBatchResult(
        appliedKeys: {'bookmarks|bm'},
        staleKeys: {},
        rejected: {},
      );
    final effects = await drainer.drain(
      outbox: [
        _row(
          id: 2,
          kind: 'change',
          table: 'bookmarks',
          key: 'bm',
          payload: const {'id': 'bm'},
        ),
        _row(
          id: 1,
          kind: 'beacon',
          payload: const {'deviceId': _deviceId, 'book_id': '3'},
        ),
      ],
      cursor: 0,
      transport: transport,
      timeout: timeout,
    );
    expect(transport.calls, ['progress', 'push', 'pull']);
    expect(effects.deleteIds, containsAll([1, 2]));
    expect(effects.cursor, 7);
    expect(effects.pullCompleted, isTrue);
  });

  test('a STALE push deletes the outbox row', () async {
    final transport = _ScriptedTransport()
      ..pushResult = const PushBatchResult(
        appliedKeys: {},
        staleKeys: {'bookmarks|bm'},
        rejected: {},
      );
    final effects = await drainer.drain(
      outbox: [
        _row(
          id: 4,
          kind: 'change',
          table: 'bookmarks',
          key: 'bm',
          payload: const {'id': 'bm'},
        ),
      ],
      cursor: 0,
      transport: transport,
      timeout: timeout,
    );
    expect(effects.deleteIds, [4]);
    expect(effects.failures, isEmpty);
  });

  test('backoff holds a failed row and gives up after ten attempts', () async {
    expect(backoffForAttempts(1), const Duration(seconds: 1));
    expect(backoffForAttempts(2), const Duration(seconds: 2));
    expect(backoffForAttempts(3), const Duration(seconds: 4));

    final failedAt = DateTime.utc(2026, 1, 1);
    final held = _row(
      id: 8,
      kind: 'change',
      table: 'notes',
      key: 'n',
      attempts: 1,
      createdAt: failedAt.millisecondsSinceEpoch,
    );
    expect(outboxDue(held, failedAt), isFalse);
    expect(outboxDue(held, failedAt.add(const Duration(seconds: 1))), isTrue);
    expect(
      outboxDue(
        _row(id: 9, kind: 'change', attempts: maxOutboxAttempts),
        failedAt.add(const Duration(days: 1)),
      ),
      isFalse,
    );

    final transport = _ScriptedTransport();
    final effects = await drainer.drain(
      outbox: [held],
      cursor: 3,
      transport: transport,
      timeout: timeout,
      now: failedAt,
    );
    expect(transport.calls, ['pull']);
    expect(effects.deleteIds, isEmpty);
    expect(effects.cursor, 7);
  });
}
