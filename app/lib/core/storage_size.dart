import 'package:ishamela/core/db/app_fs.dart';
import 'package:ishamela/core/db/paths.dart';
import 'package:ishamela/core/db/state_database.dart';
import 'package:ishamela/core/storage_size_io.dart'
    if (dart.library.html) 'package:ishamela/core/storage_size_web.dart'
    as impl;

/// SPEC-015: one-shot size backfill for installed books missing sizes.
Future<void> backfillInstalledSizes(AppPaths paths, StateDatabase state) async {
  for (final id in state.installedBookIdsMissingSize()) {
    final path = paths.bookSqlite(id);
    if (!appFileExistsSync(path)) continue;
    try {
      state.setInstalledSizeBytes(id, appFileLengthSync(path));
    } catch (_) {}
  }
}

/// Best-effort free disk bytes; null on failure / web (SPEC-015 ST-04).
Future<int?> deviceFreeBytes(AppPaths paths) => impl.deviceFreeBytes(paths);
