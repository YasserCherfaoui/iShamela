import 'package:flutter_test/flutter_test.dart';

import 'package:ishamela/core/config.dart';
import 'package:ishamela/core/format_bytes.dart';
import 'package:ishamela/core/models/models.dart';
import 'package:ishamela/core/search/normalizer.dart';
import 'package:ishamela/features/catalog/catalog_service.dart';
import 'package:ishamela/features/downloads/batch_plan.dart';

Book _book(
  int id, {
  int isb = 100,
  int sqlite = 400,
  String? path = 'x/pages.jsonl',
}) {
  return Book(
    bookId: id,
    title: 't$id',
    categoryId: 1,
    pageCount: 10,
    isbBytes: isb,
    sqliteBytes: sqlite,
    sha256: 'a' * 64,
    filename: 'book_$id.isb',
    sourcePagesPath: path,
  );
}

void main() {
  test('production default catalog URL is Shamela4_Full_DB CDN', () {
    expect(
      catalogBaseUrl,
      'https://huggingface.co/datasets/AuthenticIlm/Shamela4_Full_DB/resolve/main/',
    );
  });

  test('pages CDN uses pinned Shamela4 revision', () {
    expect(shamela4Revision, '07554bee488a12955dd5231d08487ae7ce767d1e');
    expect(
      pagesBaseUrl,
      'https://huggingface.co/datasets/AuthenticIlm/Shamela4_Full_DB/'
      'resolve/07554bee488a12955dd5231d08487ae7ce767d1e/',
    );
  });

  test('planBatchDownload skips installed and in-flight; sums bytes', () {
    final books = [
      _book(1, isb: 10, sqlite: 40),
      _book(2, isb: 20, sqlite: 80),
      _book(3, isb: 30, sqlite: 120),
    ];
    final plan = planBatchDownload(
      books: books,
      isInstalled: (id) => id == 1,
      downloadStatus: (id) => id == 2 ? DownloadStatus.queued : null,
    );
    expect(plan.missingCount, 1);
    expect(plan.toEnqueue.single.bookId, 3);
    expect(plan.isbBytesTotal, 30);
    expect(plan.sqliteBytesTotal, 120);
    expect(plan.skippedInstalled, 1);
    expect(plan.skippedInFlight, 1);
  });

  test('planBatchDownload skips books without source_pages_path', () {
    final books = [
      _book(1, path: null),
      _book(2),
    ];
    final plan = planBatchDownload(
      books: books,
      isInstalled: (_) => false,
      downloadStatus: (_) => null,
    );
    expect(plan.missingCount, 1);
    expect(plan.toEnqueue.single.bookId, 2);
  });

  test('planBatchDownload can select two missing books', () {
    final books = [_book(1), _book(2), _book(3)];
    final plan = planBatchDownload(
      books: books,
      isInstalled: (_) => false,
      downloadStatus: (_) => null,
    );
    expect(plan.missingCount, 3);
    expect(plan.isbBytesTotal, 300);
  });

  test('formatBytes scales', () {
    expect(formatBytes(500), '500 B');
    expect(formatBytes(2048), '2.0 KB');
    expect(formatBytes(5 * 1024 * 1024), '5.0 MB');
  });

  test('buildCatalogFtsMatch quotes tokens and adds prefix', () {
    expect(
      buildCatalogFtsMatch(normalize('ابن تيمية')),
      '"ابن"* "تيميه"*',
    );
    expect(buildCatalogFtsMatch('foo AND bar'), '"foo"* "AND"* "bar"*');
  });
}
