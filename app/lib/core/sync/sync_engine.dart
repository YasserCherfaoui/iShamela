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
    this.readFirebaseToken,
  });

  final StateDatabase database;
  final SyncTransport transport;
  final TokenStore tokens;

  /// SPEC-032. Google and Apple sessions have no project access token.
  final Future<String?> Function()? readFirebaseToken;

  Future<void> drain(Duration timeout) async {
    if (!await _signedIn()) {
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
    if (!await _signedIn()) {
      database.pruneOutbox();
      return;
    }
    final access = await _bearer();
    if (access == null) return;
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
    final queued = sendBeacon(
      transport.progressUrl,
      body,
      bearer: access,
      deviceId: database.ensureDeviceId(),
    );
    if (queued) {
      database.deleteOutbox([for (final row in beacons) row.id]);
    }
  }

  /// A project access token or a Firebase ID token. A failed token refresh
  /// still counts as signed in so the outbox is not deleted.
  Future<bool> _signedIn() async {
    if (await _projectAccess() != null) return true;
    final read = readFirebaseToken;
    if (read == null) return false;
    try {
      final token = await read();
      return token != null && token.isNotEmpty;
    } catch (_) {
      return true;
    }
  }

  Future<String?> _bearer() async {
    final read = readFirebaseToken;
    if (read != null) {
      try {
        final token = await read();
        if (token != null && token.isNotEmpty) return token;
      } catch (_) {
        return null;
      }
    }
    return _projectAccess();
  }

  Future<String?> _projectAccess() async {
    try {
      final access = await tokens.readAccess();
      if (access == null || access.isEmpty) return null;
      return access;
    } catch (_) {
      return null;
    }
  }
}
