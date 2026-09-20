import 'dart:convert';
import 'dart:typed_data';

import 'package:ishamela/core/db/sqlite_api_web.dart';
import 'package:ishamela/core/db/web_sqlite.dart';

AppDatabase openAppDatabase(String path, {bool readOnly = false}) {
  final sqlite = WebSqlite.require;
  return sqlite.open(
    path,
    mode: readOnly ? OpenMode.readOnly : OpenMode.readWriteCreate,
  );
}

bool appFileExistsSync(String path) => WebSqlite.vfs.xAccess(path, 0) != 0;

Future<void> writeAppFile(String path, Uint8List bytes) async {
  final fs = WebSqlite.vfs;
  const flags = SqlFlag.SQLITE_OPEN_READWRITE | SqlFlag.SQLITE_OPEN_CREATE;
  final opened = fs.xOpen(Sqlite3Filename(path), flags);
  final file = opened.file;
  try {
    file.xTruncate(bytes.length);
    const chunk = 256 * 1024;
    var offset = 0;
    while (offset < bytes.length) {
      final end = (offset + chunk < bytes.length) ? offset + chunk : bytes.length;
      file.xWrite(Uint8List.sublistView(bytes, offset, end), offset);
      offset = end;
    }
  } finally {
    file.xClose();
  }
  await fs.flush();
}

Future<bool> appFileExists(String path) async => appFileExistsSync(path);

Future<void> deleteAppFile(String path) async {
  if (WebSqlite.vfs.xAccess(path, 0) != 0) {
    WebSqlite.vfs.xDelete(path, 0);
    await WebSqlite.vfs.flush();
  }
}

Future<void> renameAppFile(String from, String to) async {
  final bytes = await readAppFile(from);
  await writeAppFile(to, bytes);
  await deleteAppFile(from);
}

Future<int> appFileLength(String path) async => appFileLengthSync(path);

int appFileLengthSync(String path) {
  if (WebSqlite.vfs.xAccess(path, 0) == 0) return 0;
  const flags = SqlFlag.SQLITE_OPEN_READONLY;
  final opened = WebSqlite.vfs.xOpen(Sqlite3Filename(path), flags);
  try {
    return opened.file.xFileSize();
  } finally {
    opened.file.xClose();
  }
}

Future<Uint8List> readAppFile(String path) async {
  const flags = SqlFlag.SQLITE_OPEN_READONLY;
  final opened = WebSqlite.vfs.xOpen(Sqlite3Filename(path), flags);
  final file = opened.file;
  try {
    final size = file.xFileSize();
    final out = Uint8List(size);
    if (size > 0) file.xRead(out, 0);
    return out;
  } finally {
    file.xClose();
  }
}

Future<void> ensureAppDir(String dirPath) async {
  // IndexedDB VFS is flat-file; directories are virtual.
}

/// Line stream for JSONL install (SPEC-008 / SPEC-021).
Stream<String> appFileLines(String path) async* {
  final bytes = await readAppFile(path);
  yield* Stream<List<int>>.value(bytes)
      .transform(utf8.decoder)
      .transform(const LineSplitter());
}

Future<void> flushAppFs() async {
  await WebSqlite.vfs.flush();
}
