import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:ishamela/core/db/paths.dart';
import 'package:ishamela/core/db/state_database.dart';
import 'package:ishamela/core/models/models.dart';
import 'package:ishamela/features/home/home_stats_dao.dart';

Future<StateDatabase> _openTemp() async {
  final dir = await Directory.systemTemp.createTemp('ishamela-home-stats-');
  final paths = AppPaths(p.join(dir.path, 'ishamela'));
  await paths.ensureLayout();
  return StateDatabase.open(paths);
}

void main() {
  test('empty history yields zero stats', () async {
    final state = await _openTemp();
    final dao = HomeStatsDao(state);
    final now = DateTime(2026, 9, 23, 12); // Wednesday
    final stats = dao.compute(now: now);
    expect(stats.streakDays, 0);
    expect(stats.weeklyMinutes, 0);
    expect(stats.weeklyPages, 0);
    expect(stats.lifetimeBooksStarted, 0);
    expect(stats.lifetimePages, 0);
    expect(stats.lifetimeMinutes, 0);
    expect(stats.longestStreak, 0);
    expect(dao.latest(), isNull);
    expect(dao.recentExcludingLatest(), isEmpty);
    state.close();
  });

  test('streak walks back consecutive calendar days from today', () async {
    final state = await _openTemp();
    // Today Wed 2026-09-23, Tue 22, Mon 21 → streak 3
    // Gap at Sun 20, then Sat 19 alone → longest still 3
    final tMon = DateTime(2026, 9, 21, 10).millisecondsSinceEpoch;
    final tTue = DateTime(2026, 9, 22, 10).millisecondsSinceEpoch;
    final tWed = DateTime(2026, 9, 23, 10).millisecondsSinceEpoch;
    final tSat = DateTime(2026, 9, 19, 10).millisecondsSinceEpoch;

    state.touchReadingHistory(bookId: 1, pageId: 1, nowMs: tSat);
    state.touchReadingHistory(bookId: 2, pageId: 1, nowMs: tMon);
    state.touchReadingHistory(bookId: 3, pageId: 1, nowMs: tTue);
    state.touchReadingHistory(bookId: 4, pageId: 1, nowMs: tWed);
    // Second entry same day must not inflate streak
    state.touchReadingHistory(bookId: 5, pageId: 1, nowMs: tWed + 3600_000);

    final dao = HomeStatsDao(state);
    final stats = dao.compute(now: DateTime(2026, 9, 23, 18));
    expect(stats.streakDays, 3);
    expect(stats.longestStreak, 3);
    state.close();
  });

  test('streak is zero when no entry today', () async {
    final state = await _openTemp();
    final yesterday = DateTime(2026, 9, 22, 10).millisecondsSinceEpoch;
    state.touchReadingHistory(bookId: 1, pageId: 1, nowMs: yesterday);
    final dao = HomeStatsDao(state);
    expect(dao.compute(now: DateTime(2026, 9, 23, 12)).streakDays, 0);
    expect(dao.compute(now: DateTime(2026, 9, 23, 12)).longestStreak, 1);
    state.close();
  });

  test('weekly minutes and pages for Mon–Sun week', () async {
    final state = await _openTemp();
    // Week of Mon 2026-09-21 … Sun 2026-09-27; "now" = Wed 23.
    // Session A: Mon, 10 min stored duration, pages (1,p1) (1,p2) via two rows
    // Session B: Wed, 125 sec → 2 min floor when alone; with A = 12 min
    // Session C: previous Sunday (outside week) ignored for weekly

    final monOpen = DateTime(2026, 9, 21, 9).millisecondsSinceEpoch;
    state.touchReadingHistory(bookId: 10, pageId: 1, nowMs: monOpen);
    state.touchReadingHistory(
      bookId: 10,
      pageId: 1,
      nowMs: monOpen + const Duration(minutes: 10).inMilliseconds,
      closing: true,
    );
    // New page same book — outside coalesce if we use different book or
    // wait > 30 min; use +31 min for new session on same day
    final monPage2 =
        monOpen + const Duration(minutes: 31).inMilliseconds;
    state.touchReadingHistory(bookId: 10, pageId: 2, nowMs: monPage2);
    state.touchReadingHistory(
      bookId: 10,
      pageId: 2,
      nowMs: monPage2 + const Duration(minutes: 5).inMilliseconds,
      closing: true,
    );

    final wedOpen = DateTime(2026, 9, 23, 11).millisecondsSinceEpoch;
    state.touchReadingHistory(bookId: 20, pageId: 5, nowMs: wedOpen);
    state.touchReadingHistory(
      bookId: 20,
      pageId: 5,
      nowMs: wedOpen + const Duration(seconds: 125).inMilliseconds,
      closing: true,
    );

    // Outside week: previous Sunday (20 min within coalesce window)
    final prevSun = DateTime(2026, 9, 20, 12).millisecondsSinceEpoch;
    state.touchReadingHistory(bookId: 99, pageId: 1, nowMs: prevSun);
    state.touchReadingHistory(
      bookId: 99,
      pageId: 1,
      nowMs: prevSun + const Duration(minutes: 20).inMilliseconds,
      closing: true,
    );

    final dao = HomeStatsDao(state);
    final stats = dao.compute(now: DateTime(2026, 9, 23, 15));

    // Hand-computed:
    // Mon session1: 10*60 = 600s, session2: 5*60 = 300s, Wed: 125s
    // Total weekly seconds = 1025 → minutes = 17
    // Weekly pages: (10,'',1), (10,'',2), (20,'',5) = 3
    // (99 not in week)
    expect(stats.weeklyMinutes, 17);
    expect(stats.weeklyPages, 3);

    // Lifetime includes prev Sunday book 99
    expect(stats.lifetimeBooksStarted, 3); // 10, 20, 99
    expect(stats.lifetimePages, 4);
    // 1025 + 1200 = 2225s → 37 minutes
    expect(stats.lifetimeMinutes, 37);
    state.close();
  });

  test('duration capped at 1800s within coalesce window', () async {
    final state = await _openTemp();
    final open = DateTime(2026, 9, 23, 8).millisecondsSinceEpoch;
    state.touchReadingHistory(bookId: 1, pageId: 1, nowMs: open);
    // Exactly 30 min = coalesce boundary and idle cap
    state.touchReadingHistory(
      bookId: 1,
      pageId: 1,
      nowMs: open + const Duration(minutes: 30).inMilliseconds,
      closing: true,
    );
    final entry = state.listReadingHistory().single;
    expect(entry.durationSeconds, StateDatabase.historyDurationCapSeconds);

    final dao = HomeStatsDao(state);
    final stats = dao.compute(now: DateTime(2026, 9, 23, 12));
    expect(stats.weeklyMinutes, 30); // 1800/60
    expect(stats.lifetimeMinutes, 30);
    state.close();
  });

  test('latest and recentExcludingLatest order by opened_at', () async {
    final state = await _openTemp();
    final t1 = DateTime(2026, 9, 21, 10).millisecondsSinceEpoch;
    final t2 = DateTime(2026, 9, 22, 10).millisecondsSinceEpoch;
    final t3 = DateTime(2026, 9, 23, 10).millisecondsSinceEpoch;
    state.touchReadingHistory(bookId: 1, pageId: 1, nowMs: t1);
    state.touchReadingHistory(bookId: 2, pageId: 2, nowMs: t2);
    state.touchReadingHistory(bookId: 3, pageId: 3, nowMs: t3);

    final dao = HomeStatsDao(state);
    expect(dao.latest()?.bookId, 3);
    final recent = dao.recentExcludingLatest(limit: 5);
    expect(recent.map((e) => e.bookId).toList(), [2, 1]);
    state.close();
  });

  test('duration accumulates across coalesce page turns', () async {
    final state = await _openTemp();
    const t0 = 1_000_000;
    state.touchReadingHistory(bookId: 7, pageId: 1, nowMs: t0);
    state.touchReadingHistory(
      bookId: 7,
      pageId: 2,
      nowMs: t0 + const Duration(minutes: 5).inMilliseconds,
    );
    expect(state.listReadingHistory().single.durationSeconds, 5 * 60);

    state.touchReadingHistory(
      bookId: 7,
      pageId: 3,
      nowMs: t0 + const Duration(minutes: 12).inMilliseconds,
      closing: true,
    );
    // +7 min since last checkpoint → total 12 min
    expect(state.listReadingHistory().single.durationSeconds, 12 * 60);
    state.close();
  });

  test('sessionSeconds derives from closed_at when duration null', () {
    expect(
      HomeStatsDao.sessionSeconds(
        ReadingHistoryEntry(
          id: 1,
          bookId: 1,
          pageId: 1,
          openedAt: 0,
          closedAt: 90_000,
        ),
      ),
      90,
    );
    expect(
      HomeStatsDao.sessionSeconds(
        ReadingHistoryEntry(
          id: 2,
          bookId: 1,
          pageId: 1,
          openedAt: 0,
          closedAt: 4_000_000,
        ),
      ),
      StateDatabase.historyDurationCapSeconds,
    );
    expect(
      HomeStatsDao.sessionSeconds(
        ReadingHistoryEntry(
          id: 3,
          bookId: 1,
          pageId: 1,
          openedAt: 0,
        ),
      ),
      0,
    );
  });

  test('sync_state and prefs round-trip', () async {
    final state = await _openTemp();
    expect(state.getSyncState().cellularAllowed, isTrue);
    expect(state.getSyncState().lastSyncedAt, isNull);

    state.setSyncState(lastSyncedAt: 42, lastError: 'offline');
    expect(state.getSyncState().lastSyncedAt, 42);
    expect(state.getSyncState().lastError, 'offline');

    state.setSyncState(cellularAllowed: false, clearError: true);
    expect(state.getSyncState().cellularAllowed, isFalse);
    expect(state.getSyncState().lastError, isNull);
    expect(state.getSyncState().lastSyncedAt, 42);

    state.setPref('sync_banner_dismissed_version', '1.0.0');
    expect(state.getPref('sync_banner_dismissed_version'), '1.0.0');
    state.close();
  });
}
