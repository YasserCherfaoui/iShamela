import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ishamela/core/compress/zstd.dart';
import 'package:ishamela/core/config.dart';
import 'package:ishamela/core/db/paths.dart';
import 'package:ishamela/core/db/state_database.dart';
import 'package:ishamela/core/net/net.dart';
import 'package:ishamela/features/catalog/catalog_service.dart';
import 'package:ishamela/features/downloads/download_service.dart';

final appPathsProvider = FutureProvider<AppPaths>((ref) => AppPaths.resolve());

final dioProvider = Provider<Dio>((ref) => createAppDio());

final catalogClientProvider = Provider<CatalogClient>((ref) {
  return CatalogClient(ref.watch(dioProvider), baseUrl: catalogBaseUrl);
});

final bundleDownloaderProvider = Provider<BundleDownloader>((ref) {
  return BundleDownloader(ref.watch(dioProvider));
});

final zstdProvider = Provider<ZstdDecompressor>(
  (ref) => PluginZstdDecompressor(),
);

final stateDatabaseProvider = FutureProvider<StateDatabase>((ref) async {
  final paths = await ref.watch(appPathsProvider.future);
  return StateDatabase.open(paths);
});

final catalogSyncProvider = FutureProvider<CatalogSync>((ref) async {
  final paths = await ref.watch(appPathsProvider.future);
  return CatalogSync(
    client: ref.watch(catalogClientProvider),
    paths: paths,
    zstd: ref.watch(zstdProvider),
  );
});

/// Runs catalog sync, then exposes a repository (so the UI sees a just-installed DB).
final catalogRepositoryProvider = FutureProvider<CatalogRepository>((ref) async {
  await ref.watch(catalogSyncTickProvider.future);
  final paths = await ref.watch(appPathsProvider.future);
  return CatalogRepository(paths);
});

final downloadServiceProvider = FutureProvider<DownloadService>((ref) async {
  final paths = await ref.watch(appPathsProvider.future);
  final state = await ref.watch(stateDatabaseProvider.future);
  final catalog = await ref.watch(catalogRepositoryProvider.future);
  final booksBase = () {
    if (catalogBaseUrl.endsWith('/')) {
      return '${catalogBaseUrl}books/';
    }
    return '$catalogBaseUrl/books/';
  }();
  final service = DownloadService(
    downloader: ref.watch(bundleDownloaderProvider),
    paths: paths,
    state: state,
    catalog: catalog,
    zstd: ref.watch(zstdProvider),
    booksBaseUrl: booksBase,
  );
  service.recoverQueue();
  return service;
});

final catalogSyncTickProvider = FutureProvider<void>((ref) async {
  final sync = await ref.watch(catalogSyncProvider.future);
  await sync.sync();
});
