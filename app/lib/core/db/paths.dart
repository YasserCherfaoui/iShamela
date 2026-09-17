import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Filesystem layout under the app support directory (SPEC-004).
class AppPaths {
  AppPaths(this.root);

  final Directory root;

  Directory get catalogDir => Directory(p.join(root.path, 'catalog'));
  File get catalogSqlite => File(p.join(catalogDir.path, 'catalog.sqlite'));
  File get catalogSqlitePart =>
      File(p.join(catalogDir.path, 'catalog.sqlite.part'));
  File get stateSqlite => File(p.join(root.path, 'state.sqlite'));
  Directory get tmpDir => Directory(p.join(root.path, 'tmp'));
  Directory get booksDir => Directory(p.join(root.path, 'books'));

  File tmpIsb(int bookId) => File(p.join(tmpDir.path, 'book_$bookId.isb'));
  File bookSqlite(int bookId) =>
      File(p.join(booksDir.path, 'book_$bookId.sqlite'));
  File bookSqlitePart(int bookId) =>
      File(p.join(booksDir.path, 'book_$bookId.sqlite.part'));

  Future<void> ensureLayout() async {
    await catalogDir.create(recursive: true);
    await tmpDir.create(recursive: true);
    await booksDir.create(recursive: true);
  }

  static Future<AppPaths> resolve() async {
    final support = await getApplicationSupportDirectory();
    final root = Directory(p.join(support.path, 'ishamela'));
    final paths = AppPaths(root);
    await paths.ensureLayout();
    return paths;
  }
}
