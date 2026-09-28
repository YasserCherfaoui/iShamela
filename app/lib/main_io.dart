import 'dart:ffi';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqlite3/open.dart';
import 'package:sqlite3_flutter_libs/sqlite3_flutter_libs.dart';

import 'package:ishamela/app.dart';
import 'package:ishamela/core/auth/firebase_bootstrap.dart';

/// Native / desktop / mobile entry (SPEC-004).
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _useSqliteAlreadyInProcess();
  await applyWorkaroundToOpenSqlite3OnOldAndroidVersions();
  await initFirebaseBestEffort();
  runApp(const ProviderScope(child: IshamelaApp()));
}

/// sqlite3_flutter_libs already links `sqlite3.framework`. Opening that
/// framework again maps the same binary twice and ObjC reports
/// `PodsDummy_sqlite3` in both copies.
void _useSqliteAlreadyInProcess() {
  if (!Platform.isMacOS) return;
  open.overrideFor(OperatingSystem.macOS, () {
    final loaded = DynamicLibrary.process();
    if (loaded.providesSymbol('sqlite3_version')) return loaded;
    return DynamicLibrary.open('sqlite3.framework/sqlite3');
  });
}
