import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqlite3_flutter_libs/sqlite3_flutter_libs.dart';

import 'package:ishamela/app.dart';
import 'package:ishamela/core/auth/firebase_bootstrap.dart';

/// Native / desktop / mobile entry (SPEC-004).
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await applyWorkaroundToOpenSqlite3OnOldAndroidVersions();
  await initFirebaseBestEffort();
  runApp(const ProviderScope(child: IshamelaApp()));
}
