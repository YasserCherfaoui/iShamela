import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ishamela/core/compress/zstd.dart';
import 'package:ishamela/core/config.dart';
import 'package:ishamela/core/db/paths.dart';
import 'package:ishamela/core/db/state_database.dart';
import 'package:ishamela/core/net/net.dart';
import 'package:ishamela/features/catalog/catalog_service.dart';
import 'package:ishamela/features/downloads/download_service.dart';
import 'package:ishamela/features/reader/reader_styles.dart';
import 'package:ishamela/ui/theme/reader_theme_tokens.dart';

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

final catalogSyncTickProvider = FutureProvider<void>((ref) async {
  final sync = await ref.watch(catalogSyncProvider.future);
  await sync.sync();
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
  final service = DownloadService(
    downloader: ref.watch(bundleDownloaderProvider),
    paths: paths,
    state: state,
    catalog: catalog,
    pagesBaseUrl: pagesBaseUrl,
  );
  service.recoverQueue();
  return service;
});

final readerTextStylesProvider =
    NotifierProvider<ReaderTextStylesNotifier, ReaderTextStyles>(
  ReaderTextStylesNotifier.new,
);

final readingAtmosphereProvider =
    NotifierProvider<ReadingAtmosphereNotifier, ReadingAtmosphere>(
  ReadingAtmosphereNotifier.new,
);

/// SPEC-016 persisted UI locale (`ar` | `en` | `fr`).
final appLocaleProvider = NotifierProvider<AppLocaleNotifier, Locale>(
  AppLocaleNotifier.new,
);

/// Pending catalog search query when jumping from Library text-search empty CTA.
final catalogPendingQueryProvider =
    NotifierProvider<CatalogPendingQueryNotifier, String?>(
  CatalogPendingQueryNotifier.new,
);

/// Shell tab index (0 catalog … 3 settings) — for cross-tab empty CTAs.
final homeTabIndexProvider = NotifierProvider<HomeTabIndexNotifier, int>(
  HomeTabIndexNotifier.new,
);

class CatalogPendingQueryNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void set(String? query) => state = query;
  void clear() => state = null;
}

class HomeTabIndexNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void go(int index) => state = index.clamp(0, 3);
}

class AppLocaleNotifier extends Notifier<Locale> {
  static const settingsKey = 'app_locale';

  @override
  Locale build() {
    final async = ref.watch(stateDatabaseProvider);
    return async.maybeWhen(
      data: (db) => _parse(db.setting(settingsKey)),
      orElse: () => const Locale('ar'),
    );
  }

  Future<void> save(Locale locale) async {
    final code = locale.languageCode;
    if (code != 'ar' && code != 'en' && code != 'fr') return;
    final db = await ref.read(stateDatabaseProvider.future);
    db.setSetting(settingsKey, code);
    state = Locale(code);
  }

  static Locale _parse(String? raw) {
    switch (raw) {
      case 'en':
        return const Locale('en');
      case 'fr':
        return const Locale('fr');
      default:
        return const Locale('ar');
    }
  }
}

class ReadingAtmosphereNotifier extends Notifier<ReadingAtmosphere> {
  @override
  ReadingAtmosphere build() {
    final async = ref.watch(stateDatabaseProvider);
    return async.maybeWhen(
      data: (db) =>
          ReadingAtmosphere.fromId(db.setting(ReadingAtmosphere.settingsKey)),
      orElse: () => ReadingAtmosphere.paper,
    );
  }

  Future<void> save(ReadingAtmosphere atmosphere) async {
    final db = await ref.read(stateDatabaseProvider.future);
    db.setSetting(ReadingAtmosphere.settingsKey, atmosphere.id);
    state = atmosphere;
  }
}

class ReaderTextStylesNotifier extends Notifier<ReaderTextStyles> {
  @override
  ReaderTextStyles build() {
    final async = ref.watch(stateDatabaseProvider);
    return async.maybeWhen(
      data: (db) => ReaderTextStyles.fromJsonString(
        db.setting(ReaderTextStyles.settingsKey),
      ),
      orElse: ReaderTextStyles.defaults,
    );
  }

  Future<void> save(ReaderTextStyles styles) async {
    final db = await ref.read(stateDatabaseProvider.future);
    db.setSetting(ReaderTextStyles.settingsKey, styles.toJsonString());
    state = styles;
  }

  Future<void> reset() => save(ReaderTextStyles.defaults());
}
