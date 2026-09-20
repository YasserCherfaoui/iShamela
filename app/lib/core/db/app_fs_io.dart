import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:ishamela/core/db/sqlite_api_io.dart';

AppDatabase openAppDatabase(String path, {bool readOnly = false}) {
  return sqlite3.open(
    path,
    mode: readOnly ? OpenMode.readOnly : OpenMode.readWriteCreate,
  );
}

bool appFileExistsSync(String path) => File(path).existsSync();

Future<void> writeAppFile(String path, Uint8List bytes) async {
  final f = File(path);
  await f.parent.create(recursive: true);
  await f.writeAsBytes(bytes, flush: true);
}

Future<bool> appFileExists(String path) async => appFileExistsSync(path);

Future<void> deleteAppFile(String path) async {
  final f = File(path);
  if (f.existsSync()) await f.delete();
}

Future<void> renameAppFile(String from, String to) async {
  final dest = File(to);
  if (dest.existsSync()) await dest.delete();
  await File(from).rename(to);
}

Future<int> appFileLength(String path) async {
  final f = File(path);
  if (!f.existsSync()) return 0;
  return f.lengthSync();
}

int appFileLengthSync(String path) {
  final f = File(path);
  if (!f.existsSync()) return 0;
  return f.lengthSync();
}

Future<Uint8List> readAppFile(String path) => File(path).readAsBytes();

Future<void> ensureAppDir(String dirPath) async {
  await Directory(dirPath).create(recursive: true);
}

/// Line stream for JSONL install (SPEC-008 / SPEC-021).
Stream<String> appFileLines(String path) {
  return File(path)
      .openRead()
      .transform(utf8.decoder)
      .transform(const LineSplitter());
}
