import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ishamela/core/providers.dart';
import 'package:ishamela/core/sync/send_beacon.dart';
import 'package:ishamela/core/sync/sync_scheduler.dart';

/// Background sync (SPEC-028 §6). No screen waits on this widget.
class ProgressSyncHost extends ConsumerStatefulWidget {
  const ProgressSyncHost({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<ProgressSyncHost> createState() => _ProgressSyncHostState();
}

class _ProgressSyncHostState extends ConsumerState<ProgressSyncHost>
    with WidgetsBindingObserver {
  StreamSubscription<List<ConnectivityResult>>? _link;
  bool _offline = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    bindPageHide(_flushLifecycle);
    _link = Connectivity().onConnectivityChanged.listen((results) {
      final offline = _isOffline(results);
      final restored = _offline && !offline;
      _offline = offline;
      if (restored) unawaited(_flush());
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_flush()));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_link?.cancel());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_flush());
      return;
    }
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _flushLifecycle();
    }
  }

  void _flushLifecycle() {
    if (kIsWeb) {
      ref.read(syncSchedulerProvider).hidePage();
      return;
    }
    unawaited(_flush(SyncScheduler.lifecycleTimeout));
  }

  Future<void> _flush([Duration timeout = SyncScheduler.httpTimeout]) {
    return ref.read(syncSchedulerProvider).flush(timeout: timeout);
  }

  bool _isOffline(List<ConnectivityResult> results) =>
      results.isEmpty || results.every((r) => r == ConnectivityResult.none);

  @override
  Widget build(BuildContext context) => widget.child;
}
