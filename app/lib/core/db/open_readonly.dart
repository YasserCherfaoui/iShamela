import 'dart:io';

import 'package:sqlite3/sqlite3.dart';

/// Open a catalog or book bundle SQLite file read-only (SPEC-004).
Database openReadonlySqlite(File path) {
  final db = sqlite3.open(path.path, mode: OpenMode.readOnly);
  db.execute('PRAGMA query_only = ON');
  return db;
}
