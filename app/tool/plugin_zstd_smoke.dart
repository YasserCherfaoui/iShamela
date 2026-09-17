import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:path/path.dart' as p;

import 'package:ishamela/core/compress/zstd.dart';
import 'package:ishamela/core/db/paths.dart';
import 'package:ishamela/core/net/catalog_client.dart';
import 'package:ishamela/features/catalog/catalog_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final base = const String.fromEnvironment(
    'CATALOG_BASE_URL',
    defaultValue: 'http://127.0.0.1:8000/',
  );
  final root = Directory.systemTemp.createTempSync('sync_smoke');
  final paths = AppPaths(Directory(p.join(root.path, 'ishamela')));
  await paths.ensureLayout();
  stdout.writeln('baseUrl=$base');
  try {
    final sync = CatalogSync(
      client: CatalogClient(Dio(), baseUrl: base),
      paths: paths,
      zstd: PluginZstdDecompressor(),
    );
    final m = await sync.sync();
    stdout.writeln(
      'sync manifest=${m?.catalogVersion} has=${paths.catalogSqlite.existsSync()} '
      'bytes=${paths.catalogSqlite.existsSync() ? paths.catalogSqlite.lengthSync() : 0}',
    );
    exit(m != null && paths.catalogSqlite.existsSync() ? 0 : 1);
  } catch (e, st) {
    stdout.writeln('FAIL $e\n$st');
    exit(1);
  }
}
