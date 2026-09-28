import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ishamela/core/auth/auth_controller.dart';
import 'package:ishamela/core/auth/auth_state.dart';
import 'package:ishamela/core/compress/zstd.dart';
import 'package:ishamela/core/config.dart';
import 'package:ishamela/core/db/paths.dart';
import 'package:ishamela/core/db/state_database.dart';
import 'package:ishamela/core/net/net.dart';
import 'package:ishamela/features/catalog/catalog_service.dart';
import 'package:ishamela/features/downloads/download_service.dart';
import 'package:ishamela/features/reader/reader_styles.dart';
import 'package:ishamela/ui/glass/appearance_prefs.dart';
import 'package:ishamela/ui/glass/glass_capability.dart';
import 'package:ishamela/ui/glass/glass_governor.dart';
import 'package:ishamela/ui/glass/interface_style.dart';
import 'package:ishamela/ui/glass/native/native_glass_channel.dart';
import 'package:ishamela/ui/theme/reader_theme_tokens.dart';

/// SPEC-022 auth session (guest when Firebase is unavailable).
final authProvider = NotifierProvider<AuthController, AuthStatus>(
  AuthController.new,
);

/// Root navigator — snack overlays sit outside the route tree (SPEC-020).
final appNavigatorKey = GlobalKey<NavigatorState>();

/// Bumped after a reading-progress pull so Home and Library rebuild.
/// [stateDatabaseProvider] does not notify when SQLite rows change.
final readingSyncRevisionProvider =
    NotifierProvider<ReadingSyncRevisionNotifier, int>(
      ReadingSyncRevisionNotifier.new,
    );

class ReadingSyncRevisionNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state++;
}

/// Bumped whenever the download queue / install registry changes so catalog
/// and library rows rebuild (FutureProviders alone do not).
final downloadRevisionProvider =
    NotifierProvider<DownloadRevisionNotifier, int>(
      DownloadRevisionNotifier.new,
    );

class DownloadRevisionNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state++;
}

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
final catalogRepositoryProvider = FutureProvider<CatalogRepository>((
  ref,
) async {
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
  void onQueueChanged() {
    if (!ref.mounted) return;
    ref.read(downloadRevisionProvider.notifier).bump();
  }

  service.addListener(onQueueChanged);
  ref.onDispose(() => service.removeListener(onQueueChanged));
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

/// Shell tab indices — Home · Library · Catalog · Settings (SPEC-023).
abstract final class HomeTabs {
  static const home = 0;
  static const library = 1;
  static const catalog = 2;
  static const settings = 3;
}

/// Shell tab index (0 home … 3 settings) — for cross-tab empty CTAs.
final homeTabIndexProvider = NotifierProvider<HomeTabIndexNotifier, int>(
  HomeTabIndexNotifier.new,
);

/// Bumped when the user re-taps the Home tab so [HomePage] scrolls to top.
final homeScrollToTopTickProvider =
    NotifierProvider<HomeScrollToTopNotifier, int>(HomeScrollToTopNotifier.new);

class CatalogPendingQueryNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void set(String? query) => state = query;
  void clear() => state = null;
}

class HomeTabIndexNotifier extends Notifier<int> {
  @override
  int build() => HomeTabs.home;

  void go(int index) => state = index.clamp(HomeTabs.home, HomeTabs.settings);
}

class HomeScrollToTopNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state++;
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

class GlassSheetDepthNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void enter() => state++;

  void leave() {
    if (state > 0) state--;
  }
}

final glassSheetDepthProvider = NotifierProvider<GlassSheetDepthNotifier, int>(
  GlassSheetDepthNotifier.new,
);

class GlassGovernorSnapshot {
  const GlassGovernorSnapshot({
    this.tripped = false,
    this.noticeVisible = false,
  });

  final bool tripped;
  final bool noticeVisible;
}

class GlassGovernorNotifier extends Notifier<GlassGovernorSnapshot> {
  final GlassFrameGovernor _governor = GlassFrameGovernor();

  @override
  GlassGovernorSnapshot build() => const GlassGovernorSnapshot();

  bool record(Duration frame, {required bool highRefreshRate}) {
    if (state.tripped) return false;
    final tripped = _governor.record(
      frame,
      budget: GlassFrameGovernor.budgetFor(highRefreshRate: highRefreshRate),
    );
    if (tripped) {
      state = const GlassGovernorSnapshot(tripped: true, noticeVisible: true);
    }
    return tripped;
  }

  void dismissNotice() {
    state = GlassGovernorSnapshot(tripped: state.tripped, noticeVisible: false);
  }

  void resetSession() {
    _governor.reset();
    state = const GlassGovernorSnapshot();
  }
}

final glassGovernorProvider =
    NotifierProvider<GlassGovernorNotifier, GlassGovernorSnapshot>(
  GlassGovernorNotifier.new,
);

final glassPlatformStatusProvider = FutureProvider<GlassPlatformStatus>((ref) {
  return NativeGlassChannel.instance.query();
});

final glassCapabilityProvider = Provider<GlassCapability>((ref) {
  final style = ref.watch(interfaceStyleProvider);
  final status = ref.watch(glassPlatformStatusProvider).maybeWhen(
        data: (value) => value,
        orElse: () => GlassPlatformStatus.unavailable,
      );
  final tripped = ref.watch(glassGovernorProvider).tripped;
  return resolveGlassCapability(
    GlassCapabilityInput(
      style: style,
      applePlatform: _applePlatform,
      nativeAvailable: status.available,
      reduceTransparency: status.reduceTransparency,
      batterySaver: status.powerSave,
      governorTripped: tripped,
    ),
  );
});

bool get _applePlatform {
  return defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.macOS;
}

class InterfaceStyleNotifier extends Notifier<InterfaceStyle> {
  int _updatedAt = 0;
  String? _syncedUid;

  @override
  InterfaceStyle build() {
    ref.listen(authProvider, (prev, next) {
      if (next is AuthSignedIn && prev is! AuthSignedIn) {
        _syncedUid = null;
        Future.microtask(syncWithAccount);
      }
    });
    final async = ref.watch(stateDatabaseProvider);
    if (!async.hasValue) return InterfaceStyle.manuscript;
    final db = async.requireValue;
    _updatedAt = int.tryParse(db.setting(InterfaceStyle.updatedAtKey) ?? '') ?? 0;
    final style = InterfaceStyle.fromId(db.setting(InterfaceStyle.settingsKey));
    final auth = ref.read(authProvider);
    if (auth is AuthSignedIn && _syncedUid != auth.profile.uid) {
      _syncedUid = auth.profile.uid;
      Future.microtask(syncWithAccount);
    }
    return style;
  }

  Future<void> save(InterfaceStyle style) async {
    final db = await ref.read(stateDatabaseProvider.future);
    _updatedAt = DateTime.now().millisecondsSinceEpoch;
    db.setSetting(InterfaceStyle.settingsKey, style.id);
    db.setSetting(InterfaceStyle.updatedAtKey, '$_updatedAt');
    state = style;
    ref.read(glassGovernorProvider.notifier).resetSession();
    await syncWithAccount();
  }

  /// Pulls the account appearance doc and keeps the newer `updatedAt`.
  Future<void> syncWithAccount() async {
    final local = AppearancePref(style: state, updatedAt: _updatedAt);
    final merged = await ref.read(authProvider.notifier).syncAppearance(local);
    if (merged.style == state && merged.updatedAt == _updatedAt) return;
    final db = await ref.read(stateDatabaseProvider.future);
    db.setSetting(InterfaceStyle.settingsKey, merged.style.id);
    db.setSetting(InterfaceStyle.updatedAtKey, '${merged.updatedAt}');
    _updatedAt = merged.updatedAt;
    state = merged.style;
  }
}

final interfaceStyleProvider =
    NotifierProvider<InterfaceStyleNotifier, InterfaceStyle>(
  InterfaceStyleNotifier.new,
);
