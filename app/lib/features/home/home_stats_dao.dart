import 'package:ishamela/core/db/state_database.dart';
import 'package:ishamela/core/models/models.dart';

/// Aggregate reading stats for the Home screen (SPEC-023 §2.3 / §4).
class HomeStats {
  const HomeStats({
    required this.streakDays,
    required this.weeklyMinutes,
    required this.weeklyPages,
    required this.lifetimeBooksStarted,
    required this.lifetimePages,
    required this.lifetimeMinutes,
    required this.longestStreak,
  });

  final int streakDays;
  final int weeklyMinutes;
  final int weeklyPages;
  final int lifetimeBooksStarted;
  final int lifetimePages;
  final int lifetimeMinutes;
  final int longestStreak;

  static const empty = HomeStats(
    streakDays: 0,
    weeklyMinutes: 0,
    weeklyPages: 0,
    lifetimeBooksStarted: 0,
    lifetimePages: 0,
    lifetimeMinutes: 0,
    longestStreak: 0,
  );
}

/// Local SQLite-derived home stats (device timezone).
class HomeStatsDao {
  HomeStatsDao(this.state, {this.clock});

  final StateDatabase state;

  /// Optional injectable clock (tests / future relative helpers).
  final DateTime? Function()? clock;

  HomeStats compute({required DateTime now}) {
    final entries = state.listReadingHistory();
    if (entries.isEmpty) return HomeStats.empty;

    final weekStart = _mondayOfWeek(now);
    final weekEnd = weekStart.add(const Duration(days: 7));
    final weekStartMs = weekStart.millisecondsSinceEpoch;
    final weekEndMs = weekEnd.millisecondsSinceEpoch;

    var weeklySeconds = 0;
    final weeklyPageKeys = <String>{};
    final lifetimeBooks = <int>{};
    final lifetimePageKeys = <String>{};
    var lifetimeSeconds = 0;
    final activeDays = <DateTime>{};

    for (final e in entries) {
      final day = _calendarDay(
        DateTime.fromMillisecondsSinceEpoch(e.openedAt),
      );
      activeDays.add(day);

      final secs = _sessionSeconds(e);
      lifetimeSeconds += secs;
      lifetimeBooks.add(e.bookId);
      lifetimePageKeys.add(_pageKey(e));

      if (e.openedAt >= weekStartMs && e.openedAt < weekEndMs) {
        weeklySeconds += secs;
        weeklyPageKeys.add(_pageKey(e));
      }
    }

    final today = _calendarDay(now);
    final streak = _currentStreak(activeDays, today);
    final longest = _longestStreak(activeDays);

    return HomeStats(
      streakDays: streak,
      weeklyMinutes: weeklySeconds ~/ 60,
      weeklyPages: weeklyPageKeys.length,
      lifetimeBooksStarted: lifetimeBooks.length,
      lifetimePages: lifetimePageKeys.length,
      lifetimeMinutes: lifetimeSeconds ~/ 60,
      longestStreak: longest,
    );
  }

  ReadingHistoryEntry? latest() => state.latestReadingHistory();

  List<ReadingHistoryEntry> recentExcludingLatest({int limit = 5}) {
    final all = state.listReadingHistory();
    if (all.isEmpty) return const [];
    return all.skip(1).take(limit).toList();
  }

  /// Duration for stats: stored seconds, else closed−opened capped, else 0.
  static int sessionSeconds(ReadingHistoryEntry e) => _sessionSeconds(e);

  static int _sessionSeconds(ReadingHistoryEntry e) {
    if (e.durationSeconds != null) return e.durationSeconds!;
    final closed = e.closedAt;
    if (closed == null) return 0;
    return StateDatabase.cappedDurationSeconds(closed - e.openedAt);
  }

  static String _pageKey(ReadingHistoryEntry e) =>
      '${e.bookId}|${e.part ?? ''}|${e.pageId}';

  static DateTime _calendarDay(DateTime dt) =>
      DateTime(dt.year, dt.month, dt.day);

  /// Monday 00:00 local of the Mon–Sun week containing [now].
  static DateTime _mondayOfWeek(DateTime now) {
    final day = _calendarDay(now);
    return day.subtract(Duration(days: day.weekday - DateTime.monday));
  }

  /// Walk back from [today]: today counts only if present; else streak is 0.
  static int _currentStreak(Set<DateTime> days, DateTime today) {
    if (!days.contains(today)) return 0;
    var streak = 0;
    var cursor = today;
    while (days.contains(cursor)) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }

  static int _longestStreak(Set<DateTime> days) {
    if (days.isEmpty) return 0;
    final sorted = days.toList()..sort();
    var longest = 1;
    var run = 1;
    for (var i = 1; i < sorted.length; i++) {
      final gap = sorted[i].difference(sorted[i - 1]).inDays;
      if (gap == 1) {
        run++;
        if (run > longest) longest = run;
      } else if (gap > 1) {
        run = 1;
      }
      // gap == 0: duplicate day (shouldn't happen with a Set)
    }
    return longest;
  }
}
