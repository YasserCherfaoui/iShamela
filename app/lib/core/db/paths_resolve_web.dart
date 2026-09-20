import 'package:ishamela/core/db/paths.dart';

Future<AppPaths> resolveAppPaths() async {
  const root = '/ishamela';
  final paths = AppPaths(root);
  await paths.ensureLayout();
  return paths;
}
