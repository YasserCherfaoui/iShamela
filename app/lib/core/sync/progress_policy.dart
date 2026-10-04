/// When a viewport page becomes reading progress (SPEC-028 §3).
class ProgressPolicy {
  ProgressPolicy({DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  static const dwellSeconds = 8;
  static const consecutiveTurns = 2;

  final DateTime Function() _clock;

  int? bookId;
  int? ordinal;
  int? page;
  DateTime? _shownAt;
  bool foreground = true;
  DateTime? _backgroundedAt;
  Duration _paused = Duration.zero;
  int _streak = 0;
  int _direction = 0;
  bool _qualified = false;

  /// First paint of a page. Starts the dwell clock and does not qualify.
  void land({required int bookId, required int ordinal, required int page}) {
    this.bookId = bookId;
    this.ordinal = ordinal;
    this.page = page;
    _shownAt = _clock();
    _paused = Duration.zero;
    _backgroundedAt = foreground ? null : _clock();
    _streak = 0;
    _direction = 0;
    _qualified = false;
  }

  /// Pause the dwell clock while the app is backgrounded.
  void setForeground(bool value) {
    if (value == foreground) return;
    final now = _clock();
    if (!value) {
      _backgroundedAt = now;
    } else if (_backgroundedAt != null) {
      _paused += now.difference(_backgroundedAt!);
      _backgroundedAt = null;
    }
    foreground = value;
  }

  /// A page turn. Qualifies once two consecutive single steps share a
  /// direction, and on every further step in that direction.
  bool onTurn({required int bookId, required int ordinal, required int page}) {
    if (this.bookId != bookId || this.ordinal == null) {
      land(bookId: bookId, ordinal: ordinal, page: page);
      return false;
    }
    final delta = ordinal - this.ordinal!;
    if (delta == 0) return false;
    if (delta.abs() == 1 && (_direction == 0 || delta.sign == _direction)) {
      _direction = delta.sign;
      _streak += 1;
    } else if (delta.abs() == 1) {
      _direction = delta.sign;
      _streak = 1;
    } else {
      _direction = 0;
      _streak = 0;
    }
    this.ordinal = ordinal;
    this.page = page;
    _shownAt = _clock();
    _paused = Duration.zero;
    _backgroundedAt = foreground ? null : _clock();
    _qualified = _streak >= consecutiveTurns;
    return _qualified;
  }

  /// True the first time this page has been in the foreground for [dwellSeconds].
  bool checkDwell() {
    if (_qualified || _shownAt == null || page == null) return false;
    if (_elapsed(_clock()) < const Duration(seconds: dwellSeconds)) {
      return false;
    }
    _qualified = true;
    return true;
  }

  Duration _elapsed(DateTime now) {
    final end = foreground ? now : (_backgroundedAt ?? now);
    final elapsed = end.difference(_shownAt!) - _paused;
    if (elapsed.isNegative) return Duration.zero;
    return elapsed;
  }
}
