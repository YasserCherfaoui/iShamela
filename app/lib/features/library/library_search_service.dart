import 'dart:async';
import 'dart:collection';
import 'dart:isolate';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:ishamela/core/db/app_fs.dart';
import 'package:ishamela/core/db/paths.dart';
import 'package:ishamela/core/db/state_database.dart';
import 'package:ishamela/core/search/normalizer.dart';
import 'package:ishamela/features/catalog/catalog_service.dart';
import 'package:ishamela/features/reader/book_database.dart';

/// One book's streamed FTS hits (SPEC-017).
class LibraryTextSearchGroup {
  LibraryTextSearchGroup({
    required this.bookId,
    required this.title,
    required this.categoryId,
    this.authorName,
    this.authorId,
    required this.hits,
    required this.totalHits,
    required this.capped,
  });

  final int bookId;
  final String title;
  final int categoryId;
  final String? authorName;
  final int? authorId;
  final List<BookSearchHit> hits;

  /// True hit count for chip (capped display separately).
  final int totalHits;
  final bool capped;
}

class CancellationToken {
  bool _cancelled = false;
  bool get isCancelled => _cancelled;
  void cancel() => _cancelled = true;
}

/// SPEC-017 library-wide full-text search over installed bundles.
class LibrarySearchService {
  LibrarySearchService({
    required this.paths,
    required this.state,
    required this.catalog,
    this.concurrency = 2,
    this.hitCap = 50,
    this.countCap = 200,
  });

  final AppPaths paths;
  final StateDatabase state;
  final CatalogRepository catalog;
  final int concurrency;
  final int hitCap;
  final int countCap;

  /// Installed book ids: history-first, then remaining by title.
  List<int> orderedInstalledBookIds({Set<int>? scopeBookIds}) {
    var installed = state.installedBookIds().toSet();
    if (scopeBookIds != null) {
      installed = installed.intersection(scopeBookIds);
    }
    final seen = <int>{};
    final ordered = <int>[];
    for (final e in state.listReadingHistory()) {
      if (installed.contains(e.bookId) && seen.add(e.bookId)) {
        ordered.add(e.bookId);
      }
    }
    final rest = installed.difference(seen).toList()
      ..sort((a, b) {
        final ta = catalog.bookById(a)?.title ?? '';
        final tb = catalog.bookById(b)?.title ?? '';
        return ta.compareTo(tb);
      });
    ordered.addAll(rest);
    return ordered;
  }

  /// Streams groups as each book finishes. Empty query / short norm → no events.
  Stream<LibraryTextSearchGroup> search({
    required String query,
    bool exactPhrase = false,
    Set<int>? scopeBookIds,
    void Function(int completed, int total)? onProgress,
    required CancellationToken token,
  }) {
    final q = normalize(query);
    if (q.length < 2) {
      return const Stream.empty();
    }
    final ids = orderedInstalledBookIds(scopeBookIds: scopeBookIds);
    if (ids.isEmpty) return const Stream.empty();

    late final StreamController<LibraryTextSearchGroup> controller;
    controller = StreamController<LibraryTextSearchGroup>(
      onListen: () {
        unawaited(
          _run(ids, q, exactPhrase, token, controller, onProgress: onProgress),
        );
      },
    );
    return controller.stream;
  }

  Future<void> _run(
    List<int> ids,
    String normalizedQuery,
    bool exactPhrase,
    CancellationToken token,
    StreamController<LibraryTextSearchGroup> controller, {
    void Function(int completed, int total)? onProgress,
  }) async {
    final queue = Queue<int>.from(ids);
    var active = 0;
    var completed = 0;
    var failures = 0;
    final completer = Completer<void>();

    void maybeFinish() {
      if (completed >= ids.length && !completer.isCompleted) {
        completer.complete();
      }
    }

    Future<void> spawn() async {
      while (!token.isCancelled && queue.isNotEmpty && active < concurrency) {
        final bookId = queue.removeFirst();
        active++;
        unawaited(() async {
          try {
            if (token.isCancelled) return;
            final result = await _searchBookAsync(
              bookId,
              normalizedQuery,
              exactPhrase,
            );
            if (result == null) {
              failures++;
            } else if (result.hits.isNotEmpty && !token.isCancelled) {
              final book = catalog.bookById(bookId);
              final group = LibraryTextSearchGroup(
                bookId: bookId,
                title: book?.title ?? 'book_$bookId',
                categoryId: book?.categoryId ?? 0,
                authorName: book?.authorName,
                authorId: book?.authorId,
                hits: result.hits,
                totalHits: result.totalHits,
                capped: result.capped,
              );
              if (!controller.isClosed) controller.add(group);
            }
          } catch (_) {
            failures++;
          } finally {
            active--;
            completed++;
            if (!token.isCancelled) {
              onProgress?.call(completed, ids.length);
            }
            maybeFinish();
            if (!token.isCancelled) await spawn();
          }
        }());
      }
      if (queue.isEmpty && active == 0) maybeFinish();
    }

    await spawn();
    await completer.future;
    if (!controller.isClosed) {
      if (failures >= ids.length && ids.isNotEmpty) {
        controller.addError(StateError('all bundles failed'));
      }
      await controller.close();
    }
  }

  Future<({List<BookSearchHit> hits, int totalHits, bool capped})?>
  _searchBookAsync(int bookId, String normalizedQuery, bool exactPhrase) async {
    final root = paths.root;
    final hCap = hitCap;
    final cCap = countCap;
    if (kIsWeb) {
      await Future<void>.delayed(Duration.zero);
      return _searchBookSync(root, bookId, normalizedQuery, exactPhrase, hCap, cCap);
    }
    return Isolate.run(
      () => _searchBookSync(
        root,
        bookId,
        normalizedQuery,
        exactPhrase,
        hCap,
        cCap,
      ),
    );
  }
}

({List<BookSearchHit> hits, int totalHits, bool capped})? _searchBookSync(
  String root,
  int bookId,
  String normalizedQuery,
  bool exactPhrase,
  int hitCap,
  int countCap,
) {
  final paths = AppPaths(root);
  final path = paths.bookSqlite(bookId);
  if (!appFileExistsSync(path)) return null;
  BookDatabase? db;
  try {
    db = BookDatabase.open(paths, bookId);
    return db.searchInBookCapped(
      normalizedQuery,
      exactPhrase: exactPhrase,
      hitCap: hitCap,
      countCap: countCap,
    );
  } catch (_) {
    return null;
  } finally {
    db?.close();
  }
}
