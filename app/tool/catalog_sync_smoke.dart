// ignore_for_file: avoid_print
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:ishamela/core/compress/zstd.dart';
import 'package:ishamela/core/db/paths.dart';
import 'package:ishamela/features/catalog/catalog_service.dart';
import 'package:path/path.dart' as p;

Future<void> main(List<String> args) async {
  final base = args.isNotEmpty ? args.first : 'http://127.0.0.1:8000/';
  final root = Directory.systemTemp.createTempSync('ishamela_sync_smoke_');
  final paths = AppPaths(root: root);
  await paths.ensureLayout();
  print('baseUrl=$base');
  print('root=${root.path}');
  print('manifest=${catalogUrl(base, 'catalog/catalog.json')}');
  try {
    final sync = CatalogSync(
      dio: Dio(),
      paths: paths,
      zstd: PluginZstdDecompressor(),
      baseUrl: base,
    );
    final manifest = await sync.sync();
    print('manifest=${manifest?.catalogVersion}');
    print('hasCatalog=${paths.catalogSqlite.existsSync()}');
    if (paths.catalogSqlite.existsSync()) {
      print('catalogBytes=${paths.catalogSqlite.lengthSync()}');
    }
  } catch (e, st) {
    print('ERROR $e');
    print(st);
  } finally {
    root.deleteSync(recursive: true);
  }
}
