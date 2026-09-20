import 'package:ishamela/core/db/app_fs.dart';
import 'package:ishamela/core/db/paths_resolve.dart';

/// Filesystem layout under the app support directory (SPEC-004).
///
/// Paths are plain strings so the same API works on IO and web (WASM VFS).
class AppPaths {
  AppPaths(this.root);

  /// Root directory path (`…/ishamela` or `/ishamela` on web).
  final String root;

  String get catalogDir => '$root/catalog';
  String get catalogSqlite => '$catalogDir/catalog.sqlite';
  String get catalogSqlitePart => '$catalogDir/catalog.sqlite.part';
  String get stateSqlite => '$root/state.sqlite';
  String get tmpDir => '$root/tmp';
  String get booksDir => '$root/books';

  String tmpIsb(int bookId) => '$tmpDir/book_$bookId.isb';
  String tmpPagesJsonl(int bookId) => '$tmpDir/book_$bookId.pages.jsonl';
  String tmpTocJsonl(int bookId) => '$tmpDir/book_$bookId.toc.jsonl';
  String bookSqlite(int bookId) => '$booksDir/book_$bookId.sqlite';
  String bookSqlitePart(int bookId) => '$booksDir/book_$bookId.sqlite.part';

  Future<void> ensureLayout() async {
    await ensureAppDir(catalogDir);
    await ensureAppDir(tmpDir);
    await ensureAppDir(booksDir);
  }

  static Future<AppPaths> resolve() => resolveAppPaths();
}
