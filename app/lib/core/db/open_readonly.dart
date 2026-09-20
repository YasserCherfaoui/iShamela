import 'package:ishamela/core/db/app_fs.dart';
import 'package:ishamela/core/db/sqlite_api.dart';

/// Opens [path] read-only (SPEC-004 catalog / book DBs).
AppDatabase openReadonlySqlite(String path) {
  return openAppDatabase(path, readOnly: true);
}
