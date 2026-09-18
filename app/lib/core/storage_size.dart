import 'dart:io';

import 'package:ishamela/core/db/paths.dart';
import 'package:ishamela/core/db/state_database.dart';

/// SPEC-015: one-shot size backfill for installed books missing sizes.
Future<void> backfillInstalledSizes(AppPaths paths, StateDatabase state) async {
  for (final id in state.installedBookIdsMissingSize()) {
    final f = paths.bookSqlite(id);
    if (!f.existsSync()) continue;
    try {
      state.setInstalledSizeBytes(id, f.lengthSync());
    } catch (_) {}
  }
}

/// Best-effort free disk bytes; null on failure (SPEC-015 ST-04).
Future<int?> deviceFreeBytes(AppPaths paths) async {
  try {
    if (Platform.isMacOS || Platform.isLinux) {
      final r = await Process.run('df', ['-k', paths.root.path]);
      if (r.exitCode != 0) return null;
      final lines = (r.stdout as String).trim().split('\n');
      if (lines.length < 2) return null;
      final parts = lines.last.trim().split(RegExp(r'\s+'));
      // df -k: Filesystem 1K-blocks Used Available …
      if (parts.length < 4) return null;
      final availK = int.tryParse(parts[3]);
      if (availK == null) return null;
      return availK * 1024;
    }
  } catch (_) {}
  return null;
}
