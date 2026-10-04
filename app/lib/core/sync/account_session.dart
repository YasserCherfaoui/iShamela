import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:ishamela/core/config.dart';
import 'package:ishamela/core/db/state_database.dart';
import 'package:ishamela/core/sync/api_client.dart';
import 'package:ishamela/core/sync/token_store.dart';

/// Sign-in replay, sign-out, and account deletion (SPEC-028 §7).
class AccountSession {
  AccountSession({
    required this.database,
    required this.tokens,
    required this.api,
    required this.flush,
  });

  final Future<StateDatabase> Function() database;
  final TokenStore tokens;
  final IshamelaApi api;
  final Future<void> Function() flush;

  Future<void> signInWithGoogle(String idToken) async {
    final db = await database();
    final session = await api.signInGoogle(
      idToken: idToken,
      device: await _device(db),
    );
    await adopt(session);
  }

  Future<void> signInWithEmailCode({
    required String email,
    required String code,
  }) async {
    final db = await database();
    final session = await api.verifyOtp(
      email: email,
      code: code,
      device: await _device(db),
    );
    await adopt(session);
  }

  Future<void> registerDevice() async {
    final access = await tokens.readAccess();
    if (access == null || access.isEmpty) return;
    final db = await database();
    final device = await _device(db);
    await api.registerDevice(
      platform: device['platform'] as String? ?? 'unknown',
      appVersion: device['appVersion'] as String? ?? '0',
    );
  }

  Future<void> signInWithApple({
    required String identityToken,
    String? authorizationCode,
  }) async {
    final db = await database();
    final session = await api.signInApple(
      identityToken: identityToken,
      authorizationCode: authorizationCode,
      device: await _device(db),
    );
    await adopt(session);
  }

  Future<void> adopt(ProjectSession session) async {
    await tokens.write(
      access: session.accessToken,
      refresh: session.refreshToken,
    );
    final db = await database();
    db.prepareSignInReplay(
      deviceId: session.deviceId,
      nowMs: DateTime.now().millisecondsSinceEpoch,
    );
    await flush();
  }

  /// Either way the session, outbox, and cursor are cleared.
  Future<void> signOut({required bool keepData}) async {
    final refresh = await tokens.readRefresh();
    if (refresh != null && refresh.isNotEmpty) {
      try {
        await api.logout(refresh);
      } catch (_) {}
    }
    await tokens.clear();
    final db = await database();
    if (keepData) {
      db.clearSyncSession();
    } else {
      db.wipeAccountLocal();
    }
  }

  Future<void> deleteAccount() async {
    await api.deleteMe();
    await tokens.clear();
    final db = await database();
    db.wipeAccountLocal();
  }

  Future<Map<String, Object?>> _device(StateDatabase db) async {
    var version = appBuiltBy;
    try {
      final info = await PackageInfo.fromPlatform();
      if (info.version.isNotEmpty) version = info.version;
    } catch (_) {}
    return {
      'id': db.ensureDeviceId(),
      'platform': kIsWeb ? 'web' : defaultTargetPlatform.name,
      'appVersion': version,
    };
  }
}
