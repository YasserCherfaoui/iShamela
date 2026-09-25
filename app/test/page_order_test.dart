import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

import 'package:ishamela/core/db/paths.dart';
import 'package:ishamela/features/reader/book_database.dart';

void main() {
  test('pages follow part, print page, then sequence id', () async {
    final dir = await Directory.systemTemp.createTemp('ishamela-pages-');
    final paths = AppPaths(p.join(dir.path, 'ishamela'));
    await paths.ensureLayout();
    final db = sqlite3.open(paths.bookSqlite(9));
    db.execute('''
      CREATE TABLE pages (
        id INTEGER PRIMARY KEY,
        part TEXT,
        page_number INTEGER,
        body TEXT NOT NULL
      )
    ''');
    // sequence ids are intentionally not the reading order.
    db.execute('''
      INSERT INTO pages (id, part, page_number, body) VALUES
        (1, '2', 1, 'vol2-p1'),
        (2, '1', 10, 'vol1-p10'),
        (3, '1', 2, 'vol1-p2'),
        (4, NULL, NULL, 'front'),
        (5, '10', 1, 'vol10'),
        (6, '1', 2, 'vol1-p2-later')
    ''');
    db.dispose();

    final book = BookDatabase.open(paths, 9);
    expect(book.pageIds(), [4, 3, 6, 2, 1, 5]);
    expect(book.pageByPrintNumber(2)?.body, 'vol1-p2');
    book.close();
  });
}
