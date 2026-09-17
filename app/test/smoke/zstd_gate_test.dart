/// SPEC-004 Task 0 smoke: level-19 .isb ↔ SQLite via system zstd (macOS CI/dev).
///
/// Production app uses the `zstandard` Flutter plugin (see docs/ZSTD.md).
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('system zstd decompresses SPEC-002 level-19 book_1.isb', () {
    final isb = File('../data/dist/book_1.isb');
    if (!isb.existsSync()) {
      // Optional artifact from local SPEC-002 builds.
      return;
    }
    final out = File('${Directory.systemTemp.path}/ishamela_zstd_gate.sqlite');
    final r = Process.runSync('zstd', ['-d', '-f', '-o', out.path, isb.path]);
    expect(r.exitCode, 0, reason: '${r.stderr}');
    final header = out.openSync().readSync(15);
    expect(String.fromCharCodes(header), 'SQLite format 3');
    out.deleteSync();
  });
}
