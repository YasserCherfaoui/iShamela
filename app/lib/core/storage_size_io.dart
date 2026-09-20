import 'dart:io';

import 'package:ishamela/core/db/paths.dart';

Future<int?> deviceFreeBytes(AppPaths paths) async {
  try {
    if (Platform.isMacOS || Platform.isLinux) {
      final r = await Process.run('df', ['-k', paths.root]);
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
