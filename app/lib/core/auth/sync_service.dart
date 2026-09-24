import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:ishamela/core/auth/firebase_bootstrap.dart';
import 'package:ishamela/core/auth/merge_local_data.dart';
import 'package:ishamela/core/library/library_plan.dart';

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

  Future<List<LibraryDoc>> fetchLibrary(String uid) async {
    final rows = await _fetchMaps(uid, 'library');
    final docs = <LibraryDoc>[];
    for (final row in rows) {
      final id = '${row['id']}';
      final doc = LibraryDoc.parse(id, row);
      if (doc != null) docs.add(doc);
    }
    return docs;
  }

  Future<void> upsertLibrary(String uid, List<LibraryDoc> docs) async {
    final db = _db;
    if (db == null || docs.isEmpty) return;
    final col = db.collection('users').doc(uid).collection('library');
    const batchLimit = 500;
    for (var i = 0; i < docs.length; i += batchLimit) {
      final slice = docs.skip(i).take(batchLimit);
      final batch = col.firestore.batch();
      for (final doc in slice) {
        batch.set(col.doc('${doc.bookId}'), doc.toMap(), SetOptions(merge: true));
      }
      await batch.commit();
    }
  }

  Future<List<Map<String, dynamic>>> fetchHistory(String uid) =>
      _fetchMaps(uid, 'history');

  Future<List<Map<String, dynamic>>> fetchProgress(String uid) =>
      _fetchMaps(uid, 'progress');

  Future<List<Map<String, dynamic>>> _fetchMaps(
    String uid,
    String name,
  ) async {
    final db = _db;
    if (db == null) return const [];
    final snap =
        await db.collection('users').doc(uid).collection(name).get();
    return [
      for (final doc in snap.docs) {'id': doc.id, ...doc.data()},
    ];
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
