import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:ishamela/core/db/paths.dart';

Future<AppPaths> resolveAppPaths() async {
  final support = await getApplicationSupportDirectory();
  final root = p.join(support.path, 'ishamela');
  final paths = AppPaths(root);
  await paths.ensureLayout();
  return paths;
}
