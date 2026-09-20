import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ishamela/app.dart';
import 'package:ishamela/core/db/web_sqlite.dart';

/// Web entry: WASM sqlite + IndexedDB VFS, then the real app shell.
/// Book downloads/installs are disabled (see [DownloadService] web stub).
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await WebSqlite.init();
  runApp(const ProviderScope(child: IshamelaApp()));
}
