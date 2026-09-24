import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ishamela/core/auth/auth_state.dart';
import 'package:ishamela/core/library/library_plan.dart';
import 'package:ishamela/core/providers.dart';
import 'package:ishamela/core/storage_size.dart';
import 'package:ishamela/features/library/library_sync_runner.dart';
import 'package:ishamela/features/library/library_sync_sheets.dart';
import 'package:ishamela/features/settings/storage_page.dart';

/// Runs SPEC-025 after sign-in, on foreground, and when the network changes.
class LibrarySyncHost extends ConsumerStatefulWidget {
  const LibrarySyncHost({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<LibrarySyncHost> createState() => _LibrarySyncHostState();
}

class _LibrarySyncHostState extends ConsumerState<LibrarySyncHost>
    with WidgetsBindingObserver {
  StreamSubscription<List<ConnectivityResult>>? _linkSub;
  Timer? _debounce;
  bool _busy = false;
  bool _sheet = false;
  int? _storagePromptBytes;
  Set<int> _knownInstalled = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _linkSub = Connectivity().onConnectivityChanged.listen((_) {
      unawaited(_tick());
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _tick());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _debounce?.cancel();
    unawaited(_linkSub?.cancel());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_tick());
  }

  Future<LibraryLink> _link() async {
    final results = await Connectivity().checkConnectivity();
    if (results.contains(ConnectivityResult.wifi) ||
        results.contains(ConnectivityResult.ethernet)) {
      return LibraryLink.wifi;
    }
    if (results.contains(ConnectivityResult.mobile)) {
      return LibraryLink.cellular;
    }
    if (results.isEmpty || results.contains(ConnectivityResult.none)) {
      return LibraryLink.offline;
    }
    return LibraryLink.wifi;
  }

  Future<void> _tick() async {
    if (_busy || _sheet || !mounted) return;
    if (!ref.read(authProvider).isVerified) return;
    _busy = true;
    try {
      final db = await ref.read(stateDatabaseProvider.future);
      final catalog = await ref.read(catalogRepositoryProvider.future);
      final downloads = await ref.read(downloadServiceProvider.future);
      final paths = await ref.read(appPathsProvider.future);
      final installed = db.installedBookIds().toSet();
      if (_knownInstalled.isEmpty) {
        _knownInstalled = installed;
      } else {
        for (final id in installed.difference(_knownInstalled)) {
          db.clearLibraryExclusion(id);
          db.markLibraryDeferred(id, on: false);
        }
        _knownInstalled = installed;
      }
      final auth = ref.read(authProvider.notifier);
      // Retry a close-book upload that failed offline, then pull other devices.
      await auth.pushReading(db);
      await auth.pullReading(db);
      ref.read(readingSyncRevisionProvider.notifier).bump();
      final remote = await auth.pullLibrary();
      final link = await _link();
      final free = await deviceFreeBytes(paths);
      final req = librarySyncRequest(
        state: db,
        catalog: catalog,
        remote: remote,
        link: link,
        freeBytes: free,
        signedIn: true,
      );
      final plan = planLibrarySync(req);
      await auth.pushLibrary(plan.upserts);
      await applyLibraryPlan(state: db, downloads: downloads, plan: plan);
      if (!mounted) return;
      final nav = appNavigatorKey.currentContext;
      if (nav == null || !nav.mounted) return;
      if (plan.showSetupSheet) {
        _sheet = true;
        final result = await showLibrarySetupSheet(
          nav,
          bookCount: plan.setupBookIds.length,
          bytes: plan.setupBytes,
          bookIds: plan.setupBookIds,
          titleOf: (id) => catalog.bookById(id)?.title ?? '$id',
        );
        _sheet = false;
        if (result != null) {
          db.setLibrarySetupDone(true);
          final follow = planAfterSetup(
            req: req,
            choice: result.choice,
            selected: result.choice == LibrarySetupChoice.later
                ? const {}
                : result.selected,
          );
          await auth.pushLibrary(follow.upserts);
          await applyLibraryPlan(state: db, downloads: downloads, plan: follow);
        }
      } else if (plan.showStorageSheet &&
          plan.requiredBytes != _storagePromptBytes) {
        _storagePromptBytes = plan.requiredBytes;
        _sheet = true;
        final picked = await showLibraryStorageSheet(
          nav,
          requiredBytes: plan.requiredBytes,
          bookIds: plan.storageBookIds,
          titleOf: (id) => catalog.bookById(id)?.title ?? '$id',
          onManageStorage: () {
            final ctx = appNavigatorKey.currentContext;
            if (ctx != null) StoragePage.open(ctx);
          },
        );
        _sheet = false;
        if (picked != null && picked.isNotEmpty) {
          for (final id in picked) {
            db.markLibraryDeferred(id, on: false);
            await downloads.enqueue(id);
          }
          for (final id in plan.storageBookIds.where(
            (id) => !picked.contains(id),
          )) {
            db.markLibraryDeferred(id, on: true);
          }
        }
      }
    } catch (_) {
      // Next foreground / sync tick retries (SPEC-022 §6).
    } finally {
      _busy = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authProvider, (prev, next) {
      if (next.isVerified && prev?.isVerified != true) unawaited(_tick());
    });
    ref.listen(downloadRevisionProvider, (prev, next) {
      if (prev == next) return;
      _debounce?.cancel();
      _debounce = Timer(const Duration(seconds: 8), () {
        unawaited(_tick());
      });
    });
    return widget.child;
  }
}
