import 'dart:convert';

import 'package:ishamela/core/db/state_database.dart';
import 'package:ishamela/core/sync/send_beacon.dart';
import 'package:ishamela/core/sync/sync_drain.dart';
import 'package:ishamela/core/sync/token_store.dart';

/// Drains the local outbox when a session exists. Guests are pruned, not uploaded.
class SyncEngine {
  SyncEngine({
    required this.database,
    required this.transport,
    required this.tokens,
  });

  final StateDatabase database;
  final SyncTransport transport;
  final TokenStore tokens;

  Future<void> drain(Duration timeout) async {
    final String? access;
    try {
      access = await tokens.readAccess();
    } catch (_) {
      return;
    }
    if (access == null || access.isEmpty) {
      database.pruneOutbox();
      return;
    }
    final cursor = int.tryParse(database.syncMeta('cursor') ?? '') ?? 0;
    final effects = await const SyncDrainer().drain(
      outbox: database.listOutbox(),
      cursor: cursor,
      transport: transport,
      timeout: timeout,
    );
    database.deleteOutbox(effects.deleteIds);
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final failure in effects.failures) {
      database.markOutboxFailure(
        id: failure.id,
        attempts: failure.attempts,
        lastError: failure.error,
        nowMs: now,
      );
    }
    for (final change in effects.pulled) {
      database.applyPulledChange(table: change.table, record: change.record);
    }
    database.setSyncMeta('cursor', '${effects.cursor}');
    if (effects.pullCompleted) {
      database.setSyncMeta('last_pull_at', '$now');
    }
  }

  /// Web tab close. Queues the beacon payload and drops those outbox rows.
  Future<void> flushPageHide() async {
    final String? access;
    try {
      access = await tokens.readAccess();
    } catch (_) {
      return;
    }
    if (access == null || access.isEmpty) {
      database.pruneOutbox();
      return;
    }
    final beacons = database
        .listOutbox()
        .where(
          (row) =>
              row.kind == 'beacon' &&
              isDeviceUuid(row.payload['deviceId'] as String?),
        )
        .take(beaconBatch)
        .toList();
    if (beacons.isEmpty) return;
    final body = jsonEncode([for (final row in beacons) row.payload]);
    final queued = sendBeacon(transport.progressUrl, body, bearer: access);
    if (queued) {
      database.deleteOutbox([for (final row in beacons) row.id]);
    }
  }
}
