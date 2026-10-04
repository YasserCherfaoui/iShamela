import 'dart:async';

/// Flush triggers for the outbox (SPEC-028 §6). Never awaited by UI actions.
class SyncScheduler {
  SyncScheduler({
    required this.drain,
    this.pageHide,
    this.debounce = const Duration(seconds: 3),
    this.bookPeriod = const Duration(seconds: 60),
  });

  final Future<void> Function(Duration timeout) drain;
  final Future<void> Function()? pageHide;
  final Duration debounce;
  final Duration bookPeriod;

  Timer? _debounceTimer;
  Timer? _bookTimer;
  bool _running = false;
  bool _queued = false;

  static const httpTimeout = Duration(seconds: 10);
  static const lifecycleTimeout = Duration(seconds: 4);

  /// Web `pagehide`: beacon via keepalive, not the full drain.
  void hidePage() {
    final hide = pageHide;
    if (hide == null) {
      unawaited(flush(timeout: lifecycleTimeout));
      return;
    }
    unawaited(hide());
  }

  /// Coalesce rapid writes.
  void nudge() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(debounce, () {
      unawaited(flush());
    });
  }

  /// Periodic flush while a book is open. Closing flushes immediately.
  void setBookOpen(bool open) {
    _bookTimer?.cancel();
    _bookTimer = null;
    if (!open) {
      unawaited(flush());
      return;
    }
    _bookTimer = Timer.periodic(bookPeriod, (_) {
      unawaited(flush());
    });
  }

  Future<void> flush({Duration timeout = httpTimeout}) async {
    if (_running) {
      _queued = true;
      return;
    }
    _running = true;
    try {
      await drain(timeout);
    } finally {
      _running = false;
      if (_queued) {
        _queued = false;
        await flush(timeout: timeout);
      }
    }
  }

  void dispose() {
    _debounceTimer?.cancel();
    _bookTimer?.cancel();
  }
}
