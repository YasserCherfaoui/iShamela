import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:ishamela/core/db/paths.dart';
import 'package:ishamela/core/db/state_database.dart';
import 'package:ishamela/core/sync/sync_drain.dart';
import 'package:ishamela/core/sync/sync_engine.dart';
import 'package:ishamela/core/sync/token_store.dart';

Future<StateDatabase> _openTemp() async {
  final dir = await Directory.systemTemp.createTemp('ishamela-engine-');
  final paths = AppPaths(p.join(dir.path, 'ishamela'));
  await paths.ensureLayout();
  return StateDatabase.open(paths);
}

class _ScriptedTransport implements SyncTransport {
  final calls = <String>[];

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
    return const PushBatchResult(
      appliedKeys: {},
      staleKeys: {},
      rejected: {},
    );
  }

  @override
  Future<PullBatch> pull({
    required int since,
    required Duration timeout,
  }) async {
    calls.add('pull');
    return const PullBatch(changes: [], nextCursor: 1, hasMore: false);
  }
}

void main() {
  test('a Firebase session syncs without a project access token', () async {
    final state = await _openTemp();
    state.ensureDeviceId();
    state.commitQualifiedProgress(bookId: 1, page: 4, progressAt: 1_000);
    final transport = _ScriptedTransport();
    final engine = SyncEngine(
      database: state,
      transport: transport,
      tokens: MemoryTokenStore(),
      readFirebaseToken: () async => 'firebase-id-token',
    );

    await engine.drain(const Duration(seconds: 1));

    expect(transport.calls, ['progress', 'pull']);
    expect(state.listOutbox(), isEmpty);
    state.close();
  });

  test('a guest sync deletes the outbox and does not call the API', () async {
    final state = await _openTemp();
    state.ensureDeviceId();
    state.commitQualifiedProgress(bookId: 1, page: 4, progressAt: 1_000);
    final transport = _ScriptedTransport();
    final engine = SyncEngine(
      database: state,
      transport: transport,
      tokens: MemoryTokenStore(),
    );

    await engine.drain(const Duration(seconds: 1));

    expect(transport.calls, isEmpty);
    expect(state.listOutbox(), isEmpty);
    state.close();
  });
}
