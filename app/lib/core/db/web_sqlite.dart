import 'package:sqlite3/wasm.dart' show WasmSqlite3, IndexedDbFileSystem;

/// Holds the process-wide WASM sqlite3 + IndexedDB VFS (web only).
class WebSqlite {
  WebSqlite._(this.sqlite, this.fileSystem);

  final WasmSqlite3 sqlite;
  final IndexedDbFileSystem fileSystem;

  static WebSqlite? _instance;

  static WasmSqlite3 get require {
    final i = _instance;
    if (i == null) {
      throw StateError('WebSqlite.init() must run before opening databases');
    }
    return i.sqlite;
  }

  static IndexedDbFileSystem get vfs {
    final i = _instance;
    if (i == null) {
      throw StateError('WebSqlite.init() must run before opening databases');
    }
    return i.fileSystem;
  }

  /// Load `sqlite3.wasm` (same origin) and open persistent IndexedDB VFS.
  static Future<void> init({String wasmUrl = 'sqlite3.wasm'}) async {
    if (_instance != null) return;
    final sqlite = await WasmSqlite3.loadFromUrl(Uri.parse(wasmUrl));
    final fileSystem = await IndexedDbFileSystem.open(dbName: 'ishamela');
    sqlite.registerVirtualFileSystem(fileSystem, makeDefault: true);
    _instance = WebSqlite._(sqlite, fileSystem);
  }
}
