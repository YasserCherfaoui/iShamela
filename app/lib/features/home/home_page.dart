import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:intl/intl.dart';
import 'package:ishamela/l10n/app_localizations.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:ishamela/core/auth/auth_state.dart';
import 'package:ishamela/core/auth/user_profile.dart';
import 'package:ishamela/core/db/state_database.dart';
import 'package:ishamela/core/models/models.dart';
import 'package:ishamela/core/providers.dart';
import 'package:ishamela/features/auth/auth_welcome_screen.dart';
import 'package:ishamela/features/catalog/catalog_service.dart';
import 'package:ishamela/features/downloads/downloads_page.dart';
import 'package:ishamela/features/home/home_stats_dao.dart';
import 'package:ishamela/features/library/bookmarks_page.dart';
import 'package:ishamela/features/library/history_page.dart';
import 'package:ishamela/features/library/notes_list_page.dart';
import 'package:ishamela/features/profile/profile_page.dart';
import 'package:ishamela/features/reader/reader_page.dart';
import 'package:ishamela/ui/book_spine.dart';
import 'package:ishamela/ui/rosette_divider.dart';
import 'package:ishamela/ui/section_label.dart';
import 'package:ishamela/ui/theme/ishamela_theme.dart';
import 'package:ishamela/ui/theme/ishamela_tokens.dart';

const _kSyncBannerDismissKey = 'home_sync_banner_dismissed_version';

/// SPEC-023 Home tab — continue reading, weekly stats, recent history.
class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  final _scroll = ScrollController();
  int _tick = 0;
  String? _appVersion;

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((info) {
      if (mounted) setState(() => _appVersion = info.version);
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToTop() {
    if (!_scroll.hasClients) return;
    _scroll.animateTo(
      0,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _openOrPromptDownload({
    required ReadingHistoryEntry entry,
    required Book? book,
    required bool installed,
  }) async {
    final l10n = AppLocalizations.of(context);
    if (installed) {
      await ReaderPage.open(
        context,
        bookId: entry.bookId,
        title: book?.title,
        authorName: book?.authorName,
        initialPageId: entry.pageId,
        initialPrintPage: entry.printPage,
      );
      if (mounted) setState(() => _tick++);
      return;
    }
    if (!mounted) return;
    final svc = await ref.read(downloadServiceProvider.future);
    final running = svc.listTasks().any(
          (t) =>
              t.bookId == entry.bookId &&
              t.status != DownloadStatus.done &&
              t.status != DownloadStatus.error,
        );
    if (!mounted) return;
    if (running) {
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => DownloadsPage(focusBookId: entry.bookId),
        ),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.homeBookNotDownloaded),
        action: SnackBarAction(
          label: l10n.download,
          onPressed: () async {
            final svc = await ref.read(downloadServiceProvider.future);
            await svc.enqueue(entry.bookId);
            ref.read(homeTabIndexProvider.notifier).go(HomeTabs.catalog);
          },
        ),
      ),
    );
  }

  Future<void> _dismissSyncBanner(StateDatabase state) async {
    final version = _appVersion ?? '0';
    state.setPref(_kSyncBannerDismissKey, version);
    setState(() => _tick++);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final t = IshamelaTokens.of(context);
    final locale = Localizations.localeOf(context);
    final auth = ref.watch(authProvider);
    final stateAsync = ref.watch(stateDatabaseProvider);
    final catalogAsync = ref.watch(catalogRepositoryProvider);
    final width = MediaQuery.sizeOf(context).width;

    ref.listen(homeScrollToTopTickProvider, (prev, next) {
      if (prev != next) _scrollToTop();
    });

    final body = stateAsync.when(
      loading: () => const _HomeSkeleton(),
      error: (e, _) => Center(child: Text('$e')),
      data: (state) {
        final _ = _tick;
        final catalog = catalogAsync.maybeWhen(
          data: (c) => c,
          orElse: () => null,
        );
        final dao = HomeStatsDao(state);
        final now = DateTime.now();
        final latest = dao.latest();
        final recent = dao.recentExcludingLatest();
        final stats = dao.compute(now: now);
        final historyCount = state.listReadingHistory().length;
        final isGuest = auth.isGuest;
        final dismissedVersion = state.getPref(_kSyncBannerDismissKey);
        final showSyncBanner = isGuest &&
            historyCount >= 3 &&
            dismissedVersion != _appVersion;

        if (latest == null) {
          return ListView(
            controller: _scroll,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: [
              _HomeHeader(auth: auth, locale: locale),
              const SizedBox(height: 20),
              _EmptyInvitation(
                onBrowse: () =>
                    ref.read(homeTabIndexProvider.notifier).go(HomeTabs.catalog),
              ),
              const SizedBox(height: 24),
              _QuickActions(
                onBookmarks: () => BookmarksPage.open(context),
                onNotes: () => NotesListPage.open(context),
              ),
            ],
          );
        }

        final book = catalog?.bookById(latest.bookId);
        final installed = state.isInstalled(latest.bookId);
        final total = book != null && book.pageCount > 0
            ? book.pageCount
            : (state.installedPageCount(latest.bookId) ?? 0);
        final progress =
            total > 0 ? (latest.pageId / total).clamp(0.0, 1.0) : 0.0;

        return ListView(
          controller: _scroll,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            _HomeHeader(auth: auth, locale: locale),
            const SizedBox(height: 16),
            _ContinueCard(
              entry: latest,
              book: book,
              installed: installed,
              progress: progress,
              locale: locale,
              onTap: () => _openOrPromptDownload(
                entry: latest,
                book: book,
                installed: installed,
              ),
            ),
            const SizedBox(height: 16),
            _WeeklyStatsStrip(stats: stats, locale: locale),
            const SizedBox(height: 8),
            SectionLabel(
              label: l10n.homeRecentHistory,
              trailing: TextButton(
                onPressed: () => HistoryPage.open(context),
                child: Text(
                  l10n.homeViewAll,
                  style: TextStyle(
                    fontFamily: kFontUi,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    color: t.emphasis,
                  ),
                ),
              ),
            ),
            if (recent.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  l10n.historyEmpty,
                  style: TextStyle(
                    fontFamily: kFontUi,
                    fontSize: 13,
                    color: t.muted,
                  ),
                ),
              )
            else
              ..._buildRecentGroups(recent, catalog, state, locale),
            const SizedBox(height: 16),
            _QuickActions(
              onBookmarks: () => BookmarksPage.open(context),
              onNotes: () => NotesListPage.open(context),
            ),
            if (showSyncBanner) ...[
              const SizedBox(height: 16),
              _SyncBanner(
                onSignIn: () => AuthWelcomeScreen.open(context),
                onDismiss: () => _dismissSyncBanner(state),
              ),
            ],
          ],
        );
      },
    );

    if (width >= 800) {
      return Scaffold(
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: body,
          ),
        ),
      );
    }
    return Scaffold(body: SafeArea(child: body));
  }

  List<Widget> _buildRecentGroups(
    List<ReadingHistoryEntry> recent,
    CatalogRepository? catalog,
    StateDatabase state,
    Locale locale,
  ) {
    final groups = groupHistoryByDay(recent, DateTime.now());
    final l10n = AppLocalizations.of(context);
    return [
      for (final g in groups) ...[
        Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 4),
          child: Text(
            _dayLabel(l10n, g.key),
            style: TextStyle(
              fontFamily: kFontUi,
              fontWeight: FontWeight.w600,
              fontSize: 12,
              color: IshamelaTokens.of(context).muted,
            ),
          ),
        ),
        for (final e in g.entries)
          _RecentHistoryRow(
            entry: e,
            book: catalog?.bookById(e.bookId),
            installed: state.isInstalled(e.bookId),
            locale: locale,
            onTap: () => _openOrPromptDownload(
              entry: e,
              book: catalog?.bookById(e.bookId),
              installed: state.isInstalled(e.bookId),
            ),
          ),
      ],
    ];
  }

  String _dayLabel(AppLocalizations l10n, HistoryDayBucket b) {
    switch (b) {
      case HistoryDayBucket.today:
        return l10n.today;
      case HistoryDayBucket.yesterday:
        return l10n.yesterday;
      case HistoryDayBucket.thisWeek:
        return l10n.thisWeek;
      case HistoryDayBucket.older:
        return l10n.older;
    }
  }
}

String _statDigits(int n, Locale locale) {
  return NumberFormat.decimalPattern(locale.toLanguageTag()).format(n);
}

String _positionCrumb(
  AppLocalizations l10n,
  ReadingHistoryEntry e,
  Locale locale,
) {
  final page = e.printPage?.toString() ?? '—';
  final part = e.part;
  if (part != null && part.isNotEmpty) {
    return l10n.homeVolPage(part, page);
  }
  return l10n.homePageOnly(page);
}

class _HomeHeader extends ConsumerWidget {
  const _HomeHeader({required this.auth, required this.locale});

  final AuthStatus auth;
  final Locale locale;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final t = IshamelaTokens.of(context);
    final profile = auth.profileOrNull;
    final name = profile?.displayName?.trim();
    final greeting = (name != null && name.isNotEmpty)
        ? l10n.homeGreetingNamed(name)
        : l10n.homeGreeting;

    final now = DateTime.now();
    final gregorian = DateFormat.yMMMMd(locale.toLanguageTag()).format(now);
    final hijri = HijriCalendar.fromDate(now);
    final hijriLine =
        '${hijri.hDay} ${hijri.getLongMonthName()} ${hijri.hYear} هـ';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                greeting,
                style: TextStyle(
                  fontFamily: kFontAmiri,
                  fontWeight: FontWeight.w700,
                  fontSize: 24,
                  color: t.ink,
                ),
              ),
              const SizedBox(height: 4),
              Tooltip(
                message: l10n.homeHijriApprox,
                child: Text(
                  '$gregorian · $hijriLine',
                  style: TextStyle(
                    fontFamily: kFontUi,
                    fontSize: 12,
                    color: t.muted,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        _AvatarButton(
          profile: profile,
          onTap: () => ProfilePage.open(context),
        ),
      ],
    );
  }
}

class _AvatarButton extends StatelessWidget {
  const _AvatarButton({required this.profile, required this.onTap});

  final UserProfile? profile;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = IshamelaTokens.of(context);
    final name = profile?.displayName;
    final photo = profile?.photoUrl;
    final initial = (name != null && name.isNotEmpty) ? name[0] : null;

    Widget child;
    if (photo != null && photo.isNotEmpty) {
      child = CircleAvatar(
        radius: 20,
        backgroundImage: NetworkImage(photo),
        backgroundColor: t.green900,
      );
    } else if (initial != null) {
      child = CircleAvatar(
        radius: 20,
        backgroundColor: t.green900,
        child: Text(
          initial,
          style: const TextStyle(
            fontFamily: kFontAmiri,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            fontSize: 16,
          ),
        ),
      );
    } else {
      child = CircleAvatar(
        radius: 20,
        backgroundColor: t.green100,
        child: Icon(Icons.person_outline, color: t.emphasis),
      );
    }

    return Material(
      color: Colors.transparent,
      shape: CircleBorder(
        side: BorderSide(color: t.goldSoft, width: 1.5),
      ),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(padding: const EdgeInsets.all(2), child: child),
      ),
    );
  }
}

class _ContinueCard extends StatelessWidget {
  const _ContinueCard({
    required this.entry,
    required this.book,
    required this.installed,
    required this.progress,
    required this.locale,
    required this.onTap,
  });

  final ReadingHistoryEntry entry;
  final Book? book;
  final bool installed;
  final double progress;
  final Locale locale;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final t = IshamelaTokens.of(context);
    final title = book?.title ?? 'book_${entry.bookId}';
    final section = entry.sectionTitle ?? '';
    final crumb = section.isNotEmpty
        ? l10n.homeBookCrumb(title, section)
        : (entry.sectionTitle ?? '');
    final pos = _positionCrumb(l10n, entry, locale);
    final pct = (progress * 100).round();
    final a11y = l10n.homeContinueA11y(
      title,
      entry.part ?? '—',
      entry.printPage?.toString() ?? '—',
    );

    return Semantics(
      button: true,
      label: a11y,
      child: Material(
        color: t.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: t.hairline),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                BookSpine(
                  title: title,
                  categoryId: book?.categoryId ?? 0,
                  available: installed,
                  width: 48,
                  height: 68,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        l10n.homeContinueReading,
                        style: TextStyle(
                          fontFamily: kFontUi,
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                          color: t.gold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: kFontAmiri,
                          fontWeight: FontWeight.w700,
                          fontSize: 17,
                          color: t.ink,
                        ),
                      ),
                      if (crumb.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          crumb,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: kFontUi,
                            fontSize: 12,
                            color: t.muted,
                          ),
                        ),
                      ],
                      const SizedBox(height: 2),
                      Text(
                        pos,
                        style: TextStyle(
                          fontFamily: kFontUi,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: t.muted,
                        ),
                      ),
                      if (progress > 0) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(999),
                                child: LinearProgressIndicator(
                                  value: progress,
                                  minHeight: 3,
                                  backgroundColor: t.hairline,
                                  color: const Color(0xFFC6A15B),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              l10n.homePercent(_statDigits(pct, locale)),
                              style: TextStyle(
                                fontFamily: kFontUi,
                                fontSize: 11,
                                color: t.muted,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                Icon(Icons.chevron_left, color: t.muted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WeeklyStatsStrip extends StatelessWidget {
  const _WeeklyStatsStrip({required this.stats, required this.locale});

  final HomeStats stats;
  final Locale locale;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _StatChip(
          value: _statDigits(stats.streakDays, locale),
          label: l10n.homeStreakDays,
        ),
        _StatChip(
          value: _statDigits(stats.weeklyMinutes, locale),
          label: l10n.homeWeeklyMinutes,
        ),
        _StatChip(
          value: _statDigits(stats.weeklyPages, locale),
          label: l10n.homeWeeklyPages,
        ),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final t = IshamelaTokens.of(context);
    return Container(
      constraints: const BoxConstraints(minWidth: 100),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: t.chipBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: t.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              fontFamily: kFontAmiri,
              fontWeight: FontWeight.w700,
              fontSize: 20,
              color: t.emphasis,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontFamily: kFontUi,
              fontSize: 11,
              color: t.muted,
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentHistoryRow extends StatelessWidget {
  const _RecentHistoryRow({
    required this.entry,
    required this.book,
    required this.installed,
    required this.locale,
    required this.onTap,
  });

  final ReadingHistoryEntry entry;
  final Book? book;
  final bool installed;
  final Locale locale;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final t = IshamelaTokens.of(context);
    final title = book?.title ?? 'book_${entry.bookId}';
    final pos = _positionCrumb(l10n, entry, locale);
    final when = relativeOpenedLabel(entry.openedAt, DateTime.now(), l10n);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: t.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: t.hairline),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                BookSpine(
                  title: title,
                  categoryId: book?.categoryId ?? 0,
                  available: installed,
                  width: 36,
                  height: 50,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: kFontAmiri,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: t.ink,
                        ),
                      ),
                      Text(
                        '$pos · $when',
                        style: TextStyle(
                          fontFamily: kFontUi,
                          fontSize: 12,
                          color: t.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.onBookmarks, required this.onNotes});

  final VoidCallback onBookmarks;
  final VoidCallback onNotes;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final t = IshamelaTokens.of(context);
    return Row(
      children: [
        Expanded(
          child: FilledButton.tonal(
            onPressed: onBookmarks,
            style: FilledButton.styleFrom(
              backgroundColor: t.green100,
              foregroundColor: t.emphasis,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: Text(l10n.homeQuickBookmarks),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: FilledButton.tonal(
            onPressed: onNotes,
            style: FilledButton.styleFrom(
              backgroundColor: t.green100,
              foregroundColor: t.emphasis,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: Text(l10n.homeQuickNotes),
          ),
        ),
      ],
    );
  }
}

class _SyncBanner extends StatelessWidget {
  const _SyncBanner({required this.onSignIn, required this.onDismiss});

  final VoidCallback onSignIn;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final t = IshamelaTokens.of(context);
    return Material(
      color: t.goldPale,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: t.hairline),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    l10n.homeSyncBanner,
                    style: TextStyle(
                      fontFamily: kFontUi,
                      fontSize: 13,
                      color: t.ink,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: FilledButton(
                      onPressed: onSignIn,
                      style: FilledButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                      ),
                      child: Text(l10n.homeSyncBannerCta),
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: l10n.cancel,
              onPressed: onDismiss,
              icon: Icon(Icons.close, color: t.muted, size: 20),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyInvitation extends StatelessWidget {
  const _EmptyInvitation({required this.onBrowse});

  final VoidCallback onBrowse;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final t = IshamelaTokens.of(context);
    return Material(
      color: t.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: t.hairline),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
        child: Column(
          children: [
            const RosetteMark(size: 32),
            const SizedBox(height: 16),
            Text(
              l10n.homeEmptyTitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: kFontAmiri,
                fontWeight: FontWeight.w700,
                fontSize: 20,
                color: t.ink,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onBrowse,
              child: Text(l10n.homeEmptyCta),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeSkeleton extends StatelessWidget {
  const _HomeSkeleton();

  @override
  Widget build(BuildContext context) {
    final t = IshamelaTokens.of(context);
    Widget block({double h = 80}) => Container(
          height: h,
          decoration: BoxDecoration(
            color: t.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: t.hairline),
          ),
        );
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        block(h: 56),
        const SizedBox(height: 16),
        block(h: 120),
        const SizedBox(height: 16),
        block(h: 64),
        const SizedBox(height: 16),
        block(h: 160),
      ],
    );
  }
}
