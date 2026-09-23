import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:ishamela/core/auth/firebase_bootstrap.dart';
import 'package:ishamela/core/auth/merge_local_data.dart';

/// ARB key shown while merge/sync runs (SPEC-022 §6 / SPEC-020 snack style).
const kSyncProgressMessageKey = 'authSyncInProgress';

/// ARB key when sync fails non-fatally.
const kSyncFailedMessageKey = 'authSyncFailed';

/// Best-effort LWW sync of guest local data → Firestore `users/{uid}/…`.
///
/// Skeleton: batches ≤500; failures are swallowed (retry on next tick).
class SyncService {
  SyncService({FirebaseFirestore? firestore}) : _firestore = firestore;

  FirebaseFirestore? _firestore;

  FirebaseFirestore? get _db {
    if (!firebaseReady) return null;
    return _firestore ??= FirebaseFirestore.instance;
  }

  /// Merges [local] into `users/{uid}/{subcollection}` with per-doc LWW on
  /// `updatedAt`. Returns true when a write was attempted successfully.
  Future<bool> mergeLocalData({
    required String uid,
    required LocalUserDataSnapshot local,
    void Function(String messageKey)? onProgress,
    void Function(String messageKey)? onFailure,
  }) async {
    final db = _db;
    if (db == null || local.isEmpty) return false;
    onProgress?.call(kSyncProgressMessageKey);
    try {
      await _upsertCollection(
        db.collection('users').doc(uid).collection('history'),
        local.history,
        idKey: 'id',
      );
      await _upsertCollection(
        db.collection('users').doc(uid).collection('bookmarks'),
        local.bookmarks,
        idKey: 'id',
      );
      await _upsertCollection(
        db.collection('users').doc(uid).collection('notes'),
        local.notes,
        idKey: 'id',
      );
      await _upsertCollection(
        db.collection('users').doc(uid).collection('progress'),
        local.progress,
        idKey: 'book_id',
      );
      return true;
    } catch (_) {
      onFailure?.call(kSyncFailedMessageKey);
      return false;
    }
  }

  Future<void> _upsertCollection(
    CollectionReference<Map<String, dynamic>> col,
    List<Map<String, Object?>> rows, {
    required String idKey,
  }) async {
    const batchLimit = 500;
    for (var i = 0; i < rows.length; i += batchLimit) {
      final slice = rows.skip(i).take(batchLimit);
      final batch = col.firestore.batch();
      for (final row in slice) {
        final id = '${row[idKey]}';
        final ref = col.doc(id);
        final remote = await ref.get();
        final localUpdated = _asInt(row['updatedAt']) ?? 0;
        if (remote.exists) {
          final remoteUpdated = _asInt(remote.data()?['updatedAt']) ?? 0;
          if (remoteUpdated >= localUpdated) continue;
        }
        batch.set(ref, {
          ...row.map((k, v) => MapEntry(k, v)),
          'updatedAt': localUpdated,
        }, SetOptions(merge: true));
      }
      await batch.commit();
    }
  }

  int? _asInt(Object? v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return null;
  }
}
