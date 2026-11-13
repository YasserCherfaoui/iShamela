import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ishamela/l10n/app_localizations.dart';

import 'package:ishamela/core/db/state_database.dart';
import 'package:ishamela/core/models/models.dart';
import 'package:ishamela/core/providers.dart';
import 'package:ishamela/core/sync/progress_policy.dart';
import 'package:ishamela/core/sync/sync_scheduler.dart';
import 'package:ishamela/core/search/normalizer.dart';
import 'package:ishamela/features/catalog/author_page.dart';
import 'package:ishamela/features/reader/annotated_body.dart';
import 'package:ishamela/features/reader/reader_appearance_sheet.dart';
import 'package:ishamela/features/reader/reader_chrome.dart';
import 'package:ishamela/features/reader/body_html.dart';
import 'package:ishamela/features/reader/book_database.dart';
import 'package:ishamela/features/reader/citation.dart';
import 'package:ishamela/features/reader/export_sheet.dart';
import 'package:ishamela/features/reader/highlight_excerpt.dart';
import 'package:ishamela/features/reader/sticky_toc.dart';
import 'package:ishamela/ui/app_search_field.dart';
import 'package:ishamela/ui/glass/drawn/drawn_glass_surface.dart';
import 'package:ishamela/ui/glass/glass_surface.dart';
import 'package:ishamela/ui/glass/chrome/glass_app_bar.dart';
import 'package:ishamela/ui/glass/chrome/glass_filter_chip.dart';
import 'package:ishamela/ui/glass/chrome/glass_sheet.dart';
import 'package:ishamela/ui/glass/chrome/glass_toolbar.dart';
import 'package:ishamela/ui/theme/glass_tokens.dart';
import 'package:ishamela/ui/jump_sheet.dart';
import 'package:ishamela/ui/page_pill.dart';
import 'package:ishamela/ui/rosette_divider.dart';
import 'package:ishamela/ui/segmented_pills.dart';
import 'package:ishamela/ui/theme/ishamela_theme.dart';
import 'package:ishamela/ui/theme/ishamela_tokens.dart';
import 'package:ishamela/ui/theme/atmosphere_label.dart';
import 'package:ishamela/ui/theme/reader_theme_tokens.dart';
import 'package:ishamela/ui/tonal_icon_button.dart';

enum ReadingMode { pagedH, pagedV, continuousV }

ReadingMode _parseReadingMode(String? raw) {
  switch (raw) {
    case 'paged_v':
      return ReadingMode.pagedV;
    case 'continuous_v':
      return ReadingMode.continuousV;
    default:
      return ReadingMode.pagedH;
  }
}

String _readingModeKey(ReadingMode mode) {
  switch (mode) {
    case ReadingMode.pagedH:
      return 'paged_h';
    case ReadingMode.pagedV:
      return 'paged_v';
    case ReadingMode.continuousV:
      return 'continuous_v';
  }
}

/// Wide side panes follow the user's open flag. A very wide window does not
/// force them open.
bool readerSidePaneVisible({
  required bool chromeVisible,
  required bool wide,
  required bool open,
}) => chromeVisible && wide && open;

/// SPEC-005 / SPEC-009 / SPEC-026 reader: TOC, HTML body, modes, بطاقة, in-book search, immersive chrome.
class ReaderPage extends ConsumerStatefulWidget {
  const ReaderPage({
    super.key,
    required this.bookId,
    this.title,
    this.authorName,
    this.authorId,
    this.initialPageId,
    this.initialPrintPage,
    this.initialPart,
    this.initialSearchQuery,
    this.exactPhrase = false,
  });

  final int bookId;
  final String? title;
  final String? authorName;
  final int? authorId;

  /// Page id wins. [initialPrintPage] is the fallback, inside [initialPart].
  final int? initialPageId;
  final int? initialPrintPage;
  final String? initialPart;

  /// Prefill in-book search (SPEC-017 «عرض المزيد» / hit open).
  final String? initialSearchQuery;
  final bool exactPhrase;

  static Future<void> open(
    BuildContext context, {
    required int bookId,
    String? title,
    String? authorName,
    int? authorId,
    int? initialPageId,
    int? initialPrintPage,
    String? initialPart,
    String? initialSearchQuery,
    bool exactPhrase = false,
  }) {
    // Prefer the root navigator so tab shells / overlays cannot swallow the push.
    final nav = Navigator.of(context, rootNavigator: true);
    return nav.push(
      MaterialPageRoute<void>(
        builder: (_) => ReaderPage(
          bookId: bookId,
          title: title,
          authorName: authorName,
          authorId: authorId,
          initialPageId: initialPageId,
          initialPrintPage: initialPrintPage,
          initialPart: initialPart,
          initialSearchQuery: initialSearchQuery,
          exactPhrase: exactPhrase,
        ),
      ),
    );
  }

  @override
  ConsumerState<ReaderPage> createState() => _ReaderPageState();
}

class _ReaderPageState extends ConsumerState<ReaderPage>
    with WidgetsBindingObserver {
  BookDatabase? _db;
  List<int> _ids = const [];
  List<TocEntry> _toc = const [];
  List<int?> _tocParents = const [];
  List<BookPart> _parts = const [];
  final _tocExpanded = <int>{};
  final _tocScroll = ScrollController();
  final _tocActiveKey = GlobalKey();
  final _tocProbeKey = GlobalKey();
  int? _tocFollowIndex;
  int? _tocBuiltMax;
  double _tocRowExtent = 56;
  int _tocRevealGen = 0;
  bool _tocRevealArmed = false;
  bool _tocRevealRunning = false;
  String _tocQuery = '';
  int _notesTick = 0;
  int _bookmarksTick = 0;
  int _index = 0;
  BookPage? _currentPage;
  PageController? _pageController;
  final _continuousScroll = ScrollController();
  final _continuousItemKeys = <int, GlobalKey>{};
  int _continuousRevealGen = 0;
  bool _continuousRevealRunning = false;
  bool _programmaticContinuousScroll = false;
  double _continuousAvgExtent = 520;
  final _searchCtrl = TextEditingController();
  Object? _error;
  ReadingMode _mode = ReadingMode.pagedH;
  bool _showToc = true;
  bool _showCard = true;
  bool _exactPhrase = false;
  List<BookSearchHit> _hits = const [];
  int _activeHitIndex = 0;
  Set<int> _highlightPageIds = {};
  Map<int, List<({int start, int end})>> _searchRangesByPage = const {};
  StateDatabase? _state;

  SyncScheduler? _scheduler;
  final _policy = ProgressPolicy();
  Timer? _dwellTimer;
  bool _showResumeChip = false;
  int? _resumeProgressPageId;
  int? _resumePrintPage;
  String? _resumePart;
  int _paneTab = 0;

  /// Prevents multi-page jumps from a single overscroll gesture.
  bool _edgePageLock = false;

  /// Page index reached from the previous/next buttons. That turn keeps
  /// chrome up; a swipe still hides it.
  int? _keepChromeForPage;

  /// SPEC-026. Starts visible; not persisted.
  final _chrome = ReaderChromeController();
  Offset? _tapDown;
  DateTime? _tapDownAt;
  bool _tapSelectionWasActive = false;
  bool _tapInteractive = false;
  int? _tapButtons;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _exactPhrase = widget.exactPhrase;
    if (widget.initialSearchQuery != null) {
      _searchCtrl.text = widget.initialSearchQuery!;
    }
    _open();
  }

  Future<void> _open() async {
    try {
      final paths = await ref.read(appPathsProvider.future);
      final state = await ref.read(stateDatabaseProvider.future);
      if (!mounted) return;
      final db = BookDatabase.open(paths, widget.bookId);
      final ids = db.pageIds();
      if (ids.isEmpty) {
        db.close();
        if (!mounted) return;
        setState(() => _error = 'empty book');
        return;
      }
      final saved = state.viewportPageId(widget.bookId);
      final qualified = state.readingProgressFor(widget.bookId);
      final located = _locateOpenIndex(db, ids);
      var index = located ?? 0;
      final resumeMissing =
          located == null &&
          (widget.initialPageId != null || widget.initialPrintPage != null);
      if (resumeMissing && saved != null) {
        final i = ids.indexOf(saved);
        if (i >= 0) index = i;
      } else if (located == null && saved != null) {
        final i = ids.indexOf(saved);
        if (i >= 0) index = i;
      }
      final mode = _parseReadingMode(state.setting('reading_mode'));
      final page = db.pageById(ids[index]);
      final tree = _orderToc(db.tocEntries());
      final toc = tree.toc;
      final parts = db.parts();
      final section = _sectionTitleForToc(toc, ids[index]);
      final openedAt = DateTime.now().millisecondsSinceEpoch;
      state.upsertBookSession(
        bookId: widget.bookId,
        page: ids[index],
        updatedAt: openedAt,
      );
      state.touchReadingHistory(
        bookId: widget.bookId,
        pageId: ids[index],
        part: page?.part,
        printPage: page?.pageNumber,
        sectionTitle: section,
        nowMs: openedAt,
      );
      _policy.land(bookId: widget.bookId, ordinal: index, page: ids[index]);
      final progressPage = qualified?.page;
      final resumePage = progressPage == null
          ? null
          : db.pageById(progressPage);
      final showChip = progressPage != null && progressPage != ids[index];
      if (!mounted) {
        db.close();
        return;
      }
      setState(() {
        _db = db;
        _state = state;
        _ids = ids;
        _toc = toc;
        _parts = parts;
        _index = index;
        _currentPage = page;
        _mode = mode;
        _pageController = PageController(initialPage: index);
        _showResumeChip = showChip;
        _resumeProgressPageId = progressPage;
        _resumePrintPage = showChip ? resumePage?.pageNumber : null;
        _resumePart = showChip ? resumePage?.part : null;
        _tocParents = tree.parents;
        _tocFollowIndex = null;
        _followToc(index);
      });
      _scheduleTocReveal();
      if (mode == ReadingMode.continuousV && index > 0) {
        _scheduleContinuousReveal(index);
      }
      _scheduler = ref.read(syncSchedulerProvider);
      _scheduler!.setBookOpen(true);
      _dwellTimer?.cancel();
      _dwellTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!_policy.checkDwell()) return;
        if (_ids.isEmpty) return;
        _qualify(_ids[_index]);
      });
      if (widget.initialSearchQuery != null &&
          widget.initialSearchQuery!.trim().isNotEmpty) {
        _runSearch();
      }
      if (resumeMissing && mounted) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.pageNotFound)));
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _dwellTimer?.cancel();
    _scheduler?.setBookOpen(false);
    _closeHistorySession();
    _pageController?.dispose();
    _continuousScroll.dispose();
    _tocScroll.dispose();
    _searchCtrl.dispose();
    _db?.close();
    _restoreSystemUi();
    super.dispose();
  }

  void _closeHistorySession() {
    final state = _state;
    final db = _db;
    if (state == null || db == null || _ids.isEmpty) return;
    final pageId = _ids[_index];
    final page = db.pageById(pageId);
    final now = DateTime.now().millisecondsSinceEpoch;
    state.upsertBookSession(
      bookId: widget.bookId,
      page: pageId,
      updatedAt: now,
    );
    state.touchReadingHistory(
      bookId: widget.bookId,
      pageId: pageId,
      part: page?.part,
      printPage: page?.pageNumber,
      sectionTitle: _sectionTitleFor(pageId),
      nowMs: now,
      closing: true,
    );
  }

  /// Page id first. Print page is used only when that id is not in this book.
  int? _locateOpenIndex(BookDatabase db, List<int> ids) {
    final pageId = widget.initialPageId;
    if (pageId != null) {
      final i = ids.indexOf(pageId);
      if (i >= 0) return i;
    }
    final printPage = widget.initialPrintPage;
    if (printPage == null) return null;
    final page = db.pageByPrintNumber(printPage, part: widget.initialPart);
    if (page == null) return null;
    final i = ids.indexOf(page.id);
    return i >= 0 ? i : null;
  }

  String? _sectionTitleFor(int pageId) => _sectionTitleForToc(_toc, pageId);

  String _resumeChipLabel(AppLocalizations l10n) {
    final page = '${_resumePrintPage ?? _resumeProgressPageId}';
    final part = _resumePart;
    if (part != null && part.isNotEmpty) {
      return l10n.resumeAtPartPage(part, page);
    }
    return l10n.resumeAtPage(page);
  }

  static String? _sectionTitleForToc(List<TocEntry> toc, int pageId) {
    if (toc.isEmpty) return null;
    final i = stickyTocIndex(toc.map((e) => e.pageId).toList(), pageId);
    return toc[i].title;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _policy.setForeground(state == AppLifecycleState.resumed);
  }

  /// Viewport on every turn. Qualified progress is a separate write.
  void _writeViewport(int pageId, {BookPage? page}) {
    final state = _state;
    if (state == null) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    final p = page ?? _db?.pageById(pageId);
    state.upsertBookSession(
      bookId: widget.bookId,
      page: pageId,
      volume: int.tryParse(p?.part ?? ''),
      updatedAt: now,
    );
    state.touchReadingHistory(
      bookId: widget.bookId,
      pageId: pageId,
      part: p?.part,
      printPage: p?.pageNumber,
      sectionTitle: _sectionTitleFor(pageId),
      nowMs: now,
    );
  }

  void _qualify(int pageId, {BookPage? page}) {
    final state = _state;
    if (state == null) return;
    final p = page ?? _db?.pageById(pageId);
    state.commitQualifiedProgress(
      bookId: widget.bookId,
      page: pageId,
      progressAt: DateTime.now().millisecondsSinceEpoch,
      volume: int.tryParse(p?.part ?? ''),
    );
    _scheduler?.nudge();
    if (!mounted || !_showResumeChip) return;
    setState(() => _showResumeChip = false);
  }

  Future<void> _setMode(ReadingMode mode) async {
    final state = await ref.read(stateDatabaseProvider.future);
    state.setSetting('reading_mode', _readingModeKey(mode));
    if (!mounted) return;
    setState(() {
      _mode = mode;
      _pageController?.dispose();
      _pageController = PageController(initialPage: _index);
    });
    if (mode == ReadingMode.continuousV && _index > 0) {
      _scheduleContinuousReveal(_index);
    }
  }

  void _onPage(int i, {bool fromContinuousScroll = false}) {
    final from = _index;
    final keepChrome = _keepChromeForPage == i;
    if (keepChrome) _keepChromeForPage = null;
    final hid = (keepChrome || fromContinuousScroll)
        ? false
        : _chrome.onPageIndexChanged(from: from, to: i);
    final pageId = _ids[i];
    final page = _db?.pageById(pageId);
    final qualified = _policy.onTurn(
      bookId: widget.bookId,
      ordinal: i,
      page: pageId,
    );
    final headingChanged = _followToc(i);
    setState(() {
      _index = i;
      _currentPage = page;
      if (pageId == _resumeProgressPageId) _showResumeChip = false;
    });
    if (headingChanged) _scheduleTocReveal();
    if (hid) _applySystemUi();
    _writeViewport(pageId, page: page);
    if (qualified) _qualify(pageId, page: page);
  }

  void _goRelative(int delta, {bool keepChrome = false}) {
    final next = _index + delta;
    if (next < 0 || next >= _ids.length) return;
    if (keepChrome) _keepChromeForPage = next;
    _onPage(next);
    if (_mode == ReadingMode.continuousV) {
      _scheduleContinuousReveal(next);
      return;
    }
    _jumpReaderTo(next);
  }

  /// [PageView.jumpToPage] during the same frame as a chrome rebuild is
  /// dropped on web. Jump now, and again after the frame, if the view
  /// is still on the old page.
  void _jumpReaderTo(int page) {
    void jump() {
      final controller = _pageController;
      if (!mounted || controller == null || !controller.hasClients) return;
      if (controller.page?.round() == page) return;
      controller.jumpToPage(page);
    }

    jump();
    WidgetsBinding.instance.addPostFrameCallback((_) => jump());
  }

  void _jumpToId(int pageId) {
    final i = _ids.indexOf(pageId);
    if (i < 0) return;
    if (_mode == ReadingMode.continuousV) {
      _onPage(i);
      _scheduleContinuousReveal(i);
    } else {
      _pageController?.jumpToPage(i);
      _onPage(i);
    }
  }

  void _scheduleContinuousReveal(int targetIndex) {
    if (_mode != ReadingMode.continuousV || _ids.isEmpty) return;
    final clamped = targetIndex.clamp(0, _ids.length - 1);
    final gen = ++_continuousRevealGen;
    if (_continuousRevealRunning) return;
    _continuousRevealRunning = true;
    var steps = 0;

    Future<void> step() async {
      if (!mounted ||
          gen != _continuousRevealGen ||
          _mode != ReadingMode.continuousV) {
        if (gen == _continuousRevealGen) _continuousRevealRunning = false;
        return;
      }
      final scroll = _continuousScroll;
      if (!scroll.hasClients || !scroll.position.hasContentDimensions) {
        if (steps++ < 20) {
          WidgetsBinding.instance.addPostFrameCallback((_) => step());
        } else {
          _continuousRevealRunning = false;
        }
        return;
      }
      final key = _continuousItemKeys[clamped];
      final ctx = key?.currentContext;
      if (ctx != null && Scrollable.maybeOf(ctx) != null) {
        _continuousRevealRunning = false;
        _programmaticContinuousScroll = true;
        try {
          await Scrollable.ensureVisible(
            ctx,
            alignment: 0.0,
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
          );
        } finally {
          _programmaticContinuousScroll = false;
        }
        return;
      }
      if (steps++ > 14) {
        _continuousRevealRunning = false;
        return;
      }
      // Estimate offset from average built item extent and jump closer.
      final avg = _measureContinuousAvgExtent();
      final pos = scroll.position;
      final dest = (clamped * avg).clamp(0.0, pos.maxScrollExtent);
      _programmaticContinuousScroll = true;
      try {
        scroll.jumpTo(dest);
      } finally {
        _programmaticContinuousScroll = false;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) => step());
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => step());
  }

  double _measureContinuousAvgExtent() {
    var sum = 0.0;
    var count = 0;
    for (final key in _continuousItemKeys.values) {
      final box = key.currentContext?.findRenderObject();
      if (box is RenderBox && box.hasSize && box.size.height > 0) {
        sum += box.size.height;
        count++;
      }
    }
    if (count > 0) {
      _continuousAvgExtent = sum / count;
    }
    return _continuousAvgExtent;
  }

  void _runSearch() {
    if (_db == null) return;
    final hits = _db!.searchInBook(_searchCtrl.text, exactPhrase: _exactPhrase);
    final byPage = <int, List<({int start, int end})>>{};
    for (final h in hits) {
      byPage[h.pageId] = h.highlightRanges;
    }
    setState(() {
      _hits = hits;
      _activeHitIndex = 0;
      _highlightPageIds = hits.map((h) => h.pageId).toSet();
      _searchRangesByPage = byPage;
    });
  }

  void _clearSearch() {
    setState(() {
      _searchCtrl.clear();
      _hits = const [];
      _activeHitIndex = 0;
      _highlightPageIds = {};
      _searchRangesByPage = const {};
    });
  }

  void _stepSearchHit(int delta) {
    if (_hits.isEmpty) return;
    final next = (_activeHitIndex + delta) % _hits.length;
    final target = next < 0 ? next + _hits.length : next;
    setState(() => _activeHitIndex = target);
    _jumpToId(_hits[target].pageId);
  }

  void _applySystemUi() {
    if (kIsWeb) return;
    if (_chrome.visible) {
      _restoreSystemUi();
      return;
    }
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: const [SystemUiOverlay.bottom],
    );
  }

  void _restoreSystemUi() {
    if (kIsWeb) return;
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  void _commitChrome() {
    setState(() {});
    _applySystemUi();
  }

  void _onBodyPointerDown(PointerDownEvent event) {
    _tapDown = event.position;
    _tapDownAt = DateTime.now();
    _tapSelectionWasActive = _chrome.selectionActive;
    _tapButtons = event.buttons;
  }

  void _onBodyPointerUp(PointerUpEvent event) {
    final down = _tapDown;
    final at = _tapDownAt;
    final buttons = _tapButtons;
    final interactive = _tapInteractive;
    final selectionWasActive = _tapSelectionWasActive;
    _tapDown = null;
    _tapDownAt = null;
    _tapButtons = null;
    _tapInteractive = false;
    if (down == null || at == null) return;
    if (buttons != null && buttons != 0 && buttons != kPrimaryButton) {
      return;
    }
    final changed = _chrome.onPointerTap(
      distance: (event.position - down).distance,
      elapsed: DateTime.now().difference(at),
      selectionWasActive: selectionWasActive,
      interactiveTarget: interactive,
    );
    if (changed) _commitChrome();
  }

  void _onBodyPointerCancel(PointerCancelEvent event) {
    _tapDown = null;
    _tapDownAt = null;
    _tapButtons = null;
    _tapInteractive = false;
  }

  void _toggleChromeFromSemantics() {
    final changed = _chrome.onPointerTap(
      distance: 0,
      elapsed: Duration.zero,
      selectionWasActive: _chrome.selectionActive,
      interactiveTarget: false,
    );
    if (changed) _commitChrome();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final title = widget.title ?? _db?.meta('title') ?? 'book_${widget.bookId}';
    final width = MediaQuery.sizeOf(context).width;
    final wide = width >= 800;
    final showToc = readerSidePaneVisible(
      chromeVisible: _chrome.visible,
      wide: wide,
      open: _showToc,
    );
    final showCard = readerSidePaneVisible(
      chromeVisible: _chrome.visible,
      wide: wide,
      open: _showCard,
    );
    final reader = ReaderThemeTokens.of(context);
    final page = _currentPage;
    final printNo = page?.pageNumber?.toString() ?? '—';
    final part = page?.part;

    final chromeVisible = _db == null || _chrome.visible;
    final glassOn = GlassStyleScope.maybeOf(context)?.liquid ?? false;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: CallbackShortcuts(
        bindings: <ShortcutActivator, VoidCallback>{
          const SingleActivator(LogicalKeyboardKey.arrowLeft): () =>
              _goRelative(1, keepChrome: true),
          const SingleActivator(LogicalKeyboardKey.arrowRight): () =>
              _goRelative(-1, keepChrome: true),
          const SingleActivator(LogicalKeyboardKey.pageDown): () =>
              _goRelative(1, keepChrome: true),
          const SingleActivator(LogicalKeyboardKey.pageUp): () =>
              _goRelative(-1, keepChrome: true),
          const SingleActivator(LogicalKeyboardKey.keyF, control: true): () =>
              _openSearchSheet(l10n),
          const SingleActivator(LogicalKeyboardKey.keyF, meta: true): () =>
              _openSearchSheet(l10n),
          const SingleActivator(LogicalKeyboardKey.keyB): () {
            if (page != null && _state != null) {
              _toggleBookmark(l10n, page);
            }
          },
        },
        child: Focus(
          autofocus: true,
          child: Scaffold(
        backgroundColor: reader.ground,
        body: _GlassOrColumn(
          glass: glassOn,
          children: [
            _AnimatedChrome(
              visible: chromeVisible,
              alignment: Alignment.topCenter,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _MaybeGlassBar(
                    enabled: glassOn,
                    child: glassOn
                        ? _CompactGlassBar(
                            title: title,
                            subtitle: _db == null
                                ? null
                                : (part != null && part.isNotEmpty
                                      ? 'ج$part · ص$printNo'
                                      : 'ص$printNo'),
                            atmosphere: reader.atmosphere,
                            actions: _readerBarActions(
                              l10n,
                              page,
                              title,
                              wide: wide,
                            ),
                          )
                        : AppBar(
                            primary: true,
                            backgroundColor: reader.raised,
                            title: Column(
                              children: [
                                Text(
                                  title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontFamily: 'Amiri',
                                    fontWeight: FontWeight.w700,
                                    fontSize: 18,
                                    color: reader.body,
                                  ),
                                ),
                                if (_db != null)
                                  Text(
                                    part != null && part.isNotEmpty
                                        ? 'ج$part · ص$printNo'
                                        : 'ص$printNo',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: reader.muted,
                                    ),
                                  ),
                              ],
                            ),
                            centerTitle: true,
                            actions: _readerBarActions(
                              l10n,
                              page,
                              title,
                              wide: wide,
                            ),
                          ),
                  ),
                  if (_hits.isNotEmpty) _searchHits(l10n),
                ],
              ),
            ),
            Expanded(
              child: _error != null
                  ? Center(child: Text('$_error'))
                  : _db == null
                  ? const Center(child: CircularProgressIndicator())
                  : _readerColumns(
                      l10n,
                      title,
                      wide: wide,
                      glassOn: glassOn,
                      showToc: showToc,
                      showCard: showCard,
                    ),
              ),
            ],
          ),
        ),
      ),
    ),
    );
  }

  List<Widget> _readerBarActions(
    AppLocalizations l10n,
    BookPage? page,
    String title, {
    required bool wide,
  }) {
    return [
      if (wide)
        Flexible(
          flex: 2,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 200),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: AppSearchField(
                hintText: l10n.searchInBook,
                initialQuery: _searchCtrl.text,
                onChanged: (v) => _searchCtrl.text = v,
                onSubmitted: (_) => _runSearch(),
              ),
            ),
          ),
        )
      else
        IconButton(
          tooltip: l10n.searchInBook,
          icon: const Icon(Icons.search),
          onPressed: () => _openSearchSheet(l10n),
        ),
      IconButton(
        tooltip: l10n.textAppearance,
        icon: const Icon(Icons.text_fields),
        onPressed: () => showReaderAppearanceSheet(context),
      ),
      _bookmarkToggleButton(l10n, page),
      if (!wide)
        IconButton(
          tooltip: l10n.toc,
          icon: const Icon(Icons.list_alt),
          onPressed: () => _openTocSheet(context, l10n),
        ),
      PopupMenuButton<String>(
        onSelected: (v) async {
          switch (v) {
            case 'card':
              if (wide) {
                setState(() => _showCard = !_showCard);
              } else {
                _openCardSheet(context, l10n, title);
              }
            case 'export':
              await showAnnotationsExportSheet(
                context,
                bookId: widget.bookId,
                title: title,
                authorName: widget.authorName,
              );
            case 'mode_h':
              _setMode(ReadingMode.pagedH);
            case 'mode_v':
              _setMode(ReadingMode.pagedV);
            case 'mode_c':
              _setMode(ReadingMode.continuousV);
            case _:
              if (v.startsWith('atm_')) {
                ref
                    .read(readingAtmosphereProvider.notifier)
                    .save(ReadingAtmosphere.fromId(v.substring(4)));
              }
          }
        },
        itemBuilder: (_) {
          final state = ref
              .read(stateDatabaseProvider)
              .maybeWhen(data: (s) => s, orElse: () => null);
          final count = state?.annotationCountForBook(widget.bookId) ?? 0;
          return [
            if (!wide) PopupMenuItem(value: 'card', child: Text(l10n.bookCard)),
            PopupMenuItem(
              value: 'export',
              enabled: count > 0,
              child: Text(
                count > 0
                    ? l10n.exportAnnotations
                    : l10n.exportNoAnnotationsHint,
              ),
            ),
            if (!wide) const PopupMenuDivider(),
            PopupMenuItem(value: 'mode_h', child: Text(l10n.modePagedH)),
            PopupMenuItem(value: 'mode_v', child: Text(l10n.modePagedV)),
            PopupMenuItem(value: 'mode_c', child: Text(l10n.modeContinuousV)),
            const PopupMenuDivider(),
            for (final atmosphere in ReadingAtmosphere.pickerOrder)
              PopupMenuItem(
                value: 'atm_${atmosphere.id}',
                child: Text(atmosphereLabel(l10n, atmosphere)),
              ),
          ];
        },
      ),
    ];
  }

  Widget _readerColumns(
    AppLocalizations l10n,
    String title, {
    required bool wide,
    required bool glassOn,
    required bool showToc,
    required bool showCard,
  }) {
    final chromeVisible = _chrome.visible;
    final viewPad = MediaQuery.viewPaddingOf(context);
    // Full-bleed pages (glass, or chrome hidden) keep the system insets only.
    // Manuscript chrome already occupies the status bar and the home indicator.
    final fullBleed = glassOn || !chromeVisible;
    final pagePadding = EdgeInsets.only(
      top: fullBleed ? viewPad.top : 0,
      bottom: fullBleed ? viewPad.bottom : 0,
    );
    final page = Listener(
      onPointerDown: _onBodyPointerDown,
      onPointerUp: _onBodyPointerUp,
      onPointerCancel: _onBodyPointerCancel,
      child: Semantics(
        label: chromeVisible
            ? l10n.hideReaderControls
            : l10n.showReaderControls,
        onTap: _toggleChromeFromSemantics,
        child: Padding(
          padding: pagePadding,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 660),
              child: _bodyPane(title),
            ),
          ),
        ),
      ),
    );
    final nav = _db == null
        ? null
        : _AnimatedChrome(
            visible: chromeVisible,
            alignment: Alignment.bottomCenter,
            child: _MaybeGlassPill(
              enabled: glassOn,
              child: _bottomNavBar(l10n, glass: glassOn),
            ),
          );
    return Row(
      children: [
        if (showToc)
          SizedBox(
            width: 300,
            child: _sideIndexPane(
              l10n,
              onClose: () => setState(() => _showToc = false),
            ),
          ),
        if (showToc) const VerticalDivider(width: 1),
        Expanded(
          // Side panes are siblings. Without a key, hiding and showing them
          // recreates this column and PageView returns to its initial page.
          key: const ValueKey<String>('reader-column'),
          child: Column(
            children: [
              Expanded(
                child: Stack(
                  children: [
                    Positioned.fill(child: page),
                    if (wide && chromeVisible && !showToc)
                      PositionedDirectional(
                        top: viewPad.top + 8,
                        start: 4,
                        child: _PaneEdgeButton(
                          tooltip: l10n.toc,
                          icon: Icons.list_alt,
                          onPressed: () {
                            _expandCurrentTocPath();
                            setState(() => _showToc = true);
                            _scheduleTocReveal();
                          },
                        ),
                      ),
                    if (wide && chromeVisible && !showCard)
                      PositionedDirectional(
                        top: viewPad.top + 8,
                        end: 4,
                        child: _PaneEdgeButton(
                          tooltip: l10n.bookCard,
                          icon: Icons.menu_book_outlined,
                          onPressed: () => setState(() => _showCard = true),
                        ),
                      ),
                    if (_showResumeChip && _resumeProgressPageId != null)
                      Positioned(
                        top: viewPad.top + 12,
                        left: 24,
                        right: 24,
                        child: Align(
                          alignment: Alignment.topCenter,
                          child: _ResumeProgressChip(
                            label: _resumeChipLabel(l10n),
                            dismissLabel: l10n.cancel,
                            onResume: () {
                              final id = _resumeProgressPageId;
                              if (id == null) return;
                              setState(() => _showResumeChip = false);
                              _jumpToId(id);
                            },
                            onDismiss: () =>
                                setState(() => _showResumeChip = false),
                          ),
                        ),
                      ),
                    if (glassOn && nav != null)
                      Positioned(left: 0, right: 0, bottom: 0, child: nav),
                  ],
                ),
              ),
              if (!glassOn && nav != null) nav,
            ],
          ),
        ),
        if (showCard) const VerticalDivider(width: 1),
        if (showCard)
          SizedBox(
            width: 300,
            child: _cardPane(
              l10n,
              title,
              onClose: () => setState(() => _showCard = false),
            ),
          ),
      ],
    );
  }

  Future<void> _openSearchSheet(AppLocalizations l10n) async {
    final t = IshamelaTokens.of(context);
    await showGlassSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: t.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              12,
              16,
              16 + MediaQuery.paddingOf(ctx).bottom,
            ),
            child: StatefulBuilder(
              builder: (ctx, setLocal) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AppSearchField(
                      hintText: l10n.searchInBook,
                      initialQuery: _searchCtrl.text,
                      autofocus: true,
                      onChanged: (v) => _searchCtrl.text = v,
                      onSubmitted: (_) {
                        _runSearch();
                        setLocal(() {});
                      },
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        GlassFilterChip(
                          label: Text(l10n.exactPhrase),
                          selected: _exactPhrase,
                          onSelected: (v) {
                            setState(() => _exactPhrase = v);
                            if (_searchCtrl.text.trim().isNotEmpty) {
                              _runSearch();
                            }
                            setLocal(() {});
                          },
                        ),
                        const Spacer(),
                        if (_hits.isNotEmpty)
                          TextButton(
                            onPressed: () {
                              _clearSearch();
                              setLocal(() {});
                            },
                            child: Text(l10n.cancel),
                          ),
                        FilledButton(
                          onPressed: () {
                            _runSearch();
                            setLocal(() {});
                          },
                          child: Text(l10n.searchInBook),
                        ),
                      ],
                    ),
                    if (_hits.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 220,
                        child: ListView.builder(
                          itemCount: _hits.length,
                          itemBuilder: (context, i) {
                            final h = _hits[i];
                            final label =
                                (h.part != null && h.part!.isNotEmpty)
                                ? 'ج${h.part} · ص ${h.pageNumber ?? '—'}'
                                : 'ص ${h.pageNumber ?? '—'}';
                            return ListTile(
                              dense: true,
                              title: Text(label),
                              subtitle: Text(
                                h.snippet,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              onTap: () {
                                setState(() => _activeHitIndex = i);
                                Navigator.pop(ctx);
                                _jumpToId(h.pageId);
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _searchHits(AppLocalizations l10n) {
    final t = IshamelaTokens.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          child: Row(
            children: [
              Text(
                '${_activeHitIndex + 1} / ${_hits.length}',
                style: TextStyle(
                  fontFamily: kFontUi,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: t.emphasis,
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: l10n.previousPage,
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.keyboard_arrow_up, size: 20),
                onPressed: () => _stepSearchHit(-1),
              ),
              IconButton(
                tooltip: l10n.nextPage,
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.keyboard_arrow_down, size: 20),
                onPressed: () => _stepSearchHit(1),
              ),
              const Spacer(),
              IconButton(
                tooltip: l10n.cancel,
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.close, size: 18),
                onPressed: _clearSearch,
              ),
            ],
          ),
        ),
        SizedBox(
          height: 112,
          child: ListView.builder(
            itemCount: _hits.length,
            itemBuilder: (context, i) {
              final h = _hits[i];
              final label = (h.part != null && h.part!.isNotEmpty)
                  ? 'ج${h.part} · ص ${h.pageNumber ?? '—'}'
                  : 'ص ${h.pageNumber ?? '—'}';
              return ListTile(
                dense: true,
                selected: i == _activeHitIndex,
                title: Text(
                  label,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                subtitle: Text(
                  h.snippet,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () {
                  setState(() => _activeHitIndex = i);
                  _jumpToId(h.pageId);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _bottomNavBar(AppLocalizations l10n, {bool glass = false}) {
    if (_ids.isEmpty || _db == null) return const SizedBox.shrink();
    final reader = ReaderThemeTokens.of(context);
    final t = IshamelaTokens.of(context);
    final page = _currentPage ?? _db!.pageById(_ids[_index]);
    final printNo = page?.pageNumber?.toString() ?? '—';
    final part = page?.part;
    final canPrev = _index > 0;
    final canNext = _index < _ids.length - 1;
    final pillLabel = [
      if (part != null && part.isNotEmpty) 'ج$part',
      'ص$printNo',
      '${_index + 1}/${_ids.length}',
    ].join(' · ');

    return Material(
      color: glass ? const Color(0x00000000) : reader.raised,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: glass
              ? null
              : Border(top: BorderSide(color: reader.hairline)),
          color: glass ? const Color(0x00000000) : reader.raised,
        ),
        child: SafeArea(
          top: false,
          bottom: !glass,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_ids.length > 1)
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 3,
                      thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 6,
                      ),
                      overlayShape: const RoundSliderOverlayShape(
                        overlayRadius: 14,
                      ),
                      activeTrackColor: reader.progressFill,
                      inactiveTrackColor: glass
                          ? GlassTokens.forAtmosphere(reader.atmosphere).stroke
                          : t.segmentTrack,
                      thumbColor: glass
                          ? GlassTokens.forAtmosphere(
                              reader.atmosphere,
                            ).foregroundGold
                          : null,
                    ),
                    child: Slider(
                      value: _index.toDouble(),
                      min: 0,
                      max: (_ids.length - 1).toDouble(),
                      onChangeStart: (_) => _chrome.onScrubStart(),
                      onChangeEnd: (_) {
                        if (_chrome.onScrubEnd()) _commitChrome();
                      },
                      onChanged: (v) {
                        final i = v.round();
                        if (_mode == ReadingMode.continuousV) {
                          _onPage(i);
                          _scheduleContinuousReveal(i);
                        } else {
                          _pageController?.jumpToPage(i);
                          _onPage(i);
                        }
                      },
                    ),
                  ),
                Row(
                  textDirection: TextDirection.rtl,
                  children: [
                    TonalIconButton(
                      tooltip: l10n.previousPage,
                      icon: Icons.chevron_right,
                      iconTextDirection: TextDirection.ltr,
                      enabled: canPrev,
                      onPressed: () => _goRelative(-1, keepChrome: true),
                    ),
                    Expanded(
                      child: Center(
                        child: PagePill(
                          label: pillLabel,
                          onTap: () => showJumpSheet(
                            context: context,
                            title: l10n.jumpToPageTitle,
                            fieldHint: l10n.jumpToPrintPage,
                            goLabel: l10n.go,
                            cancelLabel: l10n.cancel,
                            tocLabel: l10n.toc,
                            initialValue: page?.pageNumber?.toString(),
                            parts: _parts.length > 1
                                ? [for (final p in _parts) p.label]
                                : null,
                            initialPart: page?.part,
                            onGoWithPart: (raw, selectedPart) async {
                              final n = int.tryParse(raw.trim());
                              if (n == null) return false;
                              final p =
                                  _db!.pageByPrintNumber(
                                    n,
                                    part: selectedPart ?? page?.part,
                                  ) ??
                                  _db!.pageByPrintNumber(n);
                              if (p == null) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(l10n.pageNotFound)),
                                  );
                                }
                                return false;
                              }
                              _jumpToId(p.id);
                              return true;
                            },
                            onOpenToc: () => _openTocSheet(context, l10n),
                          ),
                        ),
                      ),
                    ),
                    TonalIconButton(
                      tooltip: l10n.nextPage,
                      icon: Icons.chevron_left,
                      iconTextDirection: TextDirection.ltr,
                      enabled: canNext,
                      onPressed: () => _goRelative(1, keepChrome: true),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _bookmarkToggleButton(AppLocalizations l10n, BookPage? page) {
    final _ = _bookmarksTick;
    final state = _state;
    final marked =
        state != null &&
        page != null &&
        state.isPageBookmarked(
          bookId: widget.bookId,
          pageId: page.id,
          part: page.part,
        );
    final glass = glassChromeTokens(context);
    final gold = glass?.foregroundGold ?? IshamelaTokens.of(context).goldSoft;
    final idle = glass?.foregroundInk ?? IshamelaTokens.of(context).muted;
    final reduce = MediaQuery.disableAnimationsOf(context);
    return SizedBox(
      width: 38,
      height: 38,
      child: IconButton(
        padding: EdgeInsets.zero,
        tooltip: l10n.bookmarks,
        icon: AnimatedScale(
          scale: marked ? 1.1 : 1.0,
          duration: reduce ? Duration.zero : const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          child: Icon(
            marked ? Icons.bookmark : Icons.bookmark_border,
            color: marked ? gold : idle,
            size: 22,
          ),
        ),
        onPressed: page == null || state == null
            ? null
            : () => _toggleBookmark(l10n, page),
      ),
    );
  }

  void _toggleBookmark(AppLocalizations l10n, BookPage page) {
    final state = _state;
    if (state == null) return;
    final printLabel = page.pageNumber?.toString() ?? '—';
    final addedId = state.toggleBookmark(
      bookId: widget.bookId,
      pageId: page.id,
      part: page.part,
      printPage: page.pageNumber,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );
    setState(() => _bookmarksTick++);
    final messenger = ScaffoldMessenger.of(context);
    if (addedId != null) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(l10n.bookmarkAdded(printLabel)),
          action: SnackBarAction(
            label: l10n.undo,
            onPressed: () {
              state.deleteBookmark(addedId);
              if (mounted) setState(() => _bookmarksTick++);
            },
          ),
        ),
      );
    } else {
      messenger.showSnackBar(SnackBar(content: Text(l10n.bookmarkRemoved)));
    }
  }

  /// [onSheetTick] rebuilds a modal host — parent [setState] alone does not
  /// refresh [showModalBottomSheet] content.
  Widget _sideIndexPane(
    AppLocalizations l10n, {
    VoidCallback? onSheetTick,
    VoidCallback? onCloseSheet,
    VoidCallback? onClose,
  }) {
    // Depend on ticks so badges rebuild when annotations/bookmarks change.
    final ticks = _notesTick + _bookmarksTick;
    assert(ticks >= 0);
    final noteCount = _state?.notesForBook(widget.bookId).length ?? 0;
    final bookmarkCount = _state?.bookmarksForBook(widget.bookId).length ?? 0;
    final highlightCount = _state?.highlightsForBook(widget.bookId).length ?? 0;
    final bookmarkLabel = bookmarkCount > 0
        ? '${l10n.bookmarks} $bookmarkCount'
        : l10n.bookmarks;
    final highlightsLabel = highlightCount > 0
        ? '${l10n.highlightsTab} $highlightCount'
        : l10n.highlightsTab;
    final notesLabel = noteCount > 0
        ? '${l10n.notesTab} $noteCount'
        : l10n.notesTab;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
          child: Row(
            children: [
              Expanded(
                child: SegmentedPills(
                  fitLabels: true,
                  labels: [
                    l10n.toc,
                    bookmarkLabel,
                    highlightsLabel,
                    notesLabel,
                  ],
                  selectedIndex: _paneTab,
                  onChanged: (i) {
                    setState(() => _paneTab = i);
                    onSheetTick?.call();
                  },
                ),
              ),
              if (onClose != null)
                IconButton(
                  tooltip: l10n.cancel,
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(
                    width: 32,
                    height: 32,
                  ),
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: onClose,
                ),
            ],
          ),
        ),
        Expanded(
          child: IndexedStack(
            index: _paneTab,
            children: [
              _tocList(
                l10n,
                onSheetTick: onSheetTick,
                onCloseSheet: onCloseSheet,
              ),
              _bookmarksList(l10n, onCloseSheet: onCloseSheet),
              _highlightsList(l10n, onCloseSheet: onCloseSheet),
              _notesList(l10n, onCloseSheet: onCloseSheet),
            ],
          ),
        ),
      ],
    );
  }

  Widget _tocList(
    AppLocalizations l10n, {
    VoidCallback? onSheetTick,
    VoidCallback? onCloseSheet,
  }) {
    if (_toc.isEmpty && _parts.length < 2) {
      return Center(child: Text(l10n.tocEmpty));
    }
    return Column(
      children: [
        if (_parts.length > 1) _partSwitcher(onCloseSheet: onCloseSheet),
        if (_toc.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
            child: AppSearchField(
              hintText: l10n.tocSearch,
              onChanged: (value) {
                setState(() => _tocQuery = value);
                onSheetTick?.call();
              },
            ),
          ),
        Expanded(
          child: _tocRows(
            l10n,
            onSheetTick: onSheetTick,
            onCloseSheet: onCloseSheet,
          ),
        ),
      ],
    );
  }

  Widget _partSwitcher({VoidCallback? onCloseSheet}) {
    final t = IshamelaTokens.of(context);
    final current = _currentPage?.part;
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        itemCount: _parts.length,
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        itemBuilder: (context, i) {
          final part = _parts[i];
          final selected = part.label == current;
          return Material(
            color: selected ? t.green100 : t.card,
            borderRadius: BorderRadius.circular(999),
            child: InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: () {
                onCloseSheet?.call();
                _jumpToId(part.firstPageId);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Center(
                  child: Text(
                    part.label,
                    style: TextStyle(
                      fontFamily: kFontUi,
                      fontSize: 12,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                      color: selected ? t.emphasis : t.ink,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Set<int>? _tocMatchIds() {
    final query = normalize(_tocQuery.trim());
    if (query.isEmpty) return null;
    return <int>{
      for (final entry in _toc)
        if (normalize(entry.title).contains(query)) entry.id,
    };
  }

  Widget _tocRows(
    AppLocalizations l10n, {
    VoidCallback? onSheetTick,
    VoidCallback? onCloseSheet,
  }) {
    if (_toc.isEmpty) {
      return Center(child: Text(l10n.tocEmpty));
    }
    final currentId = _ids.isNotEmpty ? _ids[_index] : _toc.first.pageId;
    final active = stickyTocIndex(
      _toc.map((e) => e.pageId).toList(),
      currentId,
    );
    final matchIds = _tocMatchIds();
    final titleIds = [for (final entry in _toc) entry.id];
    final rows = visibleTocRows(
      ids: titleIds,
      parentIds: _tocParents,
      expandedIds: _tocExpanded,
      matchIds: matchIds,
    );
    if (rows.isEmpty) {
      return Center(child: Text(l10n.tocSearchEmpty));
    }
    final t = IshamelaTokens.of(context);
    _tocBuiltMax = null;
    if (_tocRevealArmed && !_tocRevealRunning) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _tocRevealArmed && !_tocRevealRunning) {
          _scheduleTocReveal();
        }
      });
    }
    return ListView.builder(
      controller: _tocScroll,
      cacheExtent: 1600,
      itemCount: rows.length,
      itemBuilder: (context, i) {
        final row = rows[i];
        final e = _toc[row.index];
        final selected = row.index == active;
        final builtMax = _tocBuiltMax;
        if (builtMax == null || i > builtMax) _tocBuiltMax = i;
        final page = _db?.pageById(e.pageId);
        final printNo = page?.pageNumber?.toString() ?? '—';
        final part = page?.part;
        final pageLabel = _parts.length > 1 && part != null && part.isNotEmpty
            ? 'ج$part · ص$printNo'
            : printNo;
        final depth = row.depth.clamp(0, 8);
        final fontSize = depth <= 0
            ? 15.0
            : depth == 1
            ? 14.0
            : 13.0;
        return Padding(
          key: selected ? _tocActiveKey : (i == 0 ? _tocProbeKey : null),
          padding: EdgeInsetsDirectional.only(start: 4.0 + depth * 18),
          child: Material(
            color: selected ? t.green100 : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            child: Row(
              children: [
                if (row.hasChildren)
                  IconButton(
                    tooltip: row.expanded ? l10n.tocCollapse : l10n.tocExpand,
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints.tightFor(
                      width: 28,
                      height: 28,
                    ),
                    icon: Icon(
                      row.expanded ? Icons.expand_more : Icons.chevron_left,
                      size: 18,
                      color: t.muted,
                    ),
                    onPressed: () => _toggleToc(e.id, onSheetTick: onSheetTick),
                  )
                else
                  const SizedBox(width: 28),
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () {
                      onCloseSheet?.call();
                      _jumpToId(e.pageId);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              e.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: 'Amiri',
                                fontWeight: selected
                                    ? FontWeight.w700
                                    : (depth == 0
                                          ? FontWeight.w600
                                          : FontWeight.w400),
                                fontSize: fontSize,
                                color: selected ? t.emphasis : t.ink,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            pageLabel,
                            style: TextStyle(
                              fontFamily: kFontUi,
                              fontSize: 11,
                              color: t.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _toggleToc(int id, {VoidCallback? onSheetTick}) {
    setState(() {
      if (!_tocExpanded.add(id)) _tocExpanded.remove(id);
    });
    // The phone contents list is a modal sheet. Parent setState does not
    // rebuild it, so the chevron has to refresh the sheet itself.
    onSheetTick?.call();
  }

  /// Ascending `shamela_title_id`; `parent_id` points at a `title_id`.
  static ({List<TocEntry> toc, List<int?> parents}) _orderToc(
    List<TocEntry> entries,
  ) {
    final tree = tocTreeOrder([
      for (final entry in entries)
        TocHeading(
          titleId: entry.id,
          shamelaTitleId: entry.position,
          parentId: entry.parentId,
          title: entry.title,
        ),
    ]);
    return (
      toc: [for (final i in tree.order) entries[i]],
      parents: tree.parents,
    );
  }

  /// Expands the branch of the heading that contains this page, and closes
  /// every other branch. Returns whether the heading changed.
  bool _followToc(int pageIndex) {
    if (_toc.isEmpty || _ids.isEmpty || _tocParents.length != _toc.length) {
      return false;
    }
    final active = stickyTocIndex([
      for (final entry in _toc) entry.pageId,
    ], _ids[pageIndex]);
    if (active == _tocFollowIndex) return false;
    _tocFollowIndex = active;
    _tocExpanded
      ..clear()
      ..addAll(
        tocPathIds(
          ids: [for (final entry in _toc) entry.id],
          parentIds: _tocParents,
          index: active,
        ),
      );
    return true;
  }

  /// Opens every heading above the current page so that row can be scrolled to.
  void _expandCurrentTocPath() {
    if (_toc.isEmpty || _ids.isEmpty || _tocParents.length != _toc.length) {
      return;
    }
    final active = stickyTocIndex([
      for (final entry in _toc) entry.pageId,
    ], _ids[_index]);
    _tocFollowIndex = active;
    _tocExpanded.addAll(
      tocPathIds(
        ids: [for (final entry in _toc) entry.id],
        parentIds: _tocParents,
        index: active,
      ),
    );
  }

  void _scheduleTocReveal() {
    _tocRevealArmed = true;
    if (_tocRevealRunning) return;
    _tocRevealRunning = true;
    final generation = ++_tocRevealGen;
    var idle = 0;
    var moves = 0;

    Future<void> step() async {
      if (!mounted || generation != _tocRevealGen) {
        if (!mounted && generation == _tocRevealGen) _tocRevealRunning = false;
        return;
      }
      final scroll = _tocScroll;
      final ready = scroll.hasClients && scroll.position.hasContentDimensions;
      if (!ready) {
        if (idle++ > 24) {
          _tocRevealRunning = false;
          return;
        }
        WidgetsBinding.instance.addPostFrameCallback((_) => step());
        return;
      }
      if (_tocFollowIndex == null || moves > 6) {
        _tocRevealArmed = false;
        _tocRevealRunning = false;
        return;
      }
      final current = _tocActiveKey.currentContext;
      if (current != null && Scrollable.maybeOf(current) != null) {
        _tocRevealArmed = false;
        _tocRevealRunning = false;
        if (!_tocRowIsVisible(current)) {
          await Scrollable.ensureVisible(
            current,
            alignment: 0.35,
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeOutCubic,
          );
        }
        return;
      }
      final rows = visibleTocRows(
        ids: [for (final entry in _toc) entry.id],
        parentIds: _tocParents,
        expandedIds: _tocExpanded,
        matchIds: _tocMatchIds(),
      );
      final pos = rows.indexWhere((row) => row.index == _tocFollowIndex);
      if (pos < 0) {
        _tocRevealArmed = false;
        _tocRevealRunning = false;
        return;
      }
      final position = scroll.position;
      final dest = tocRevealOffset(
        visibleIndex: pos,
        rowExtent: _measureTocRow(),
        pixels: position.pixels,
        maxExtent: position.maxScrollExtent,
        builtMax: _tocBuiltMax,
      );
      if (position.maxScrollExtent <= 0 && pos > 0) {
        if (idle++ > 24) {
          _tocRevealRunning = false;
          return;
        }
        WidgetsBinding.instance.addPostFrameCallback((_) => step());
        return;
      }
      final short =
          dest + 1 < pos * _tocRowExtent &&
          position.pixels >= position.maxScrollExtent - 1;
      if (short) {
        if (idle++ > 24) {
          _tocRevealArmed = false;
          _tocRevealRunning = false;
          return;
        }
        WidgetsBinding.instance.addPostFrameCallback((_) => step());
        return;
      }
      if ((position.pixels - dest).abs() < 1) {
        moves++;
        final further = (position.pixels + position.viewportDimension).clamp(
          0.0,
          position.maxScrollExtent,
        );
        if (further > position.pixels + 1 && pos > (_tocBuiltMax ?? -1)) {
          try {
            await scroll.animateTo(
              further,
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
            );
          } catch (_) {
            if (generation == _tocRevealGen) _tocRevealRunning = false;
            return;
          }
        }
        if (!mounted || generation != _tocRevealGen) return;
        WidgetsBinding.instance.addPostFrameCallback((_) => step());
        return;
      }
      _tocRevealArmed = false;
      moves++;
      try {
        await scroll.animateTo(
          dest,
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
        );
      } catch (_) {
        _tocRevealRunning = false;
        return;
      }
      if (!mounted || generation != _tocRevealGen || !scroll.hasClients) {
        if (generation == _tocRevealGen) _tocRevealRunning = false;
        return;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) => step());
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => step());
  }

  double _measureTocRow() {
    final probe = _tocProbeKey.currentContext ?? _tocActiveKey.currentContext;
    final box = probe?.findRenderObject();
    if (box is RenderBox && box.hasSize && box.size.height > 0) {
      _tocRowExtent = box.size.height;
    }
    return _tocRowExtent;
  }

  bool _tocRowIsVisible(BuildContext rowContext) {
    final box = rowContext.findRenderObject();
    final viewport = _tocScroll.position.context.notificationContext
        ?.findRenderObject();
    if (box is! RenderBox || viewport is! RenderBox) return false;
    if (!box.hasSize || !box.attached || !viewport.hasSize) return false;
    final top = box.localToGlobal(Offset.zero, ancestor: viewport).dy;
    final bottom = top + box.size.height;
    return top >= -1 && bottom <= viewport.size.height + 1;
  }

  Widget _bookmarksList(
    AppLocalizations l10n, {
    VoidCallback? onCloseSheet,
  }) {
    final _ = _bookmarksTick;
    final marks = _state?.bookmarksForBook(widget.bookId) ?? const [];
    if (marks.isEmpty) {
      return Center(child: Text(l10n.bookmarksEmpty));
    }
    final t = IshamelaTokens.of(context);
    return ListView.builder(
      itemCount: marks.length,
      itemBuilder: (context, i) {
        final b = marks[i];
        final section = _sectionTitleFor(b.pageId);
        final printNo = b.printPage?.toString() ?? '—';
        final label = (b.label != null && b.label!.isNotEmpty)
            ? b.label!
            : (section ?? 'ص$printNo');
        return ListTile(
          dense: true,
          leading: Icon(Icons.bookmark, color: t.goldSoft, size: 20),
          title: Text(label, maxLines: 2, overflow: TextOverflow.ellipsis),
          trailing: Text(
            printNo,
            style: TextStyle(fontFamily: kFontUi, fontSize: 11, color: t.muted),
          ),
          onTap: () {
            onCloseSheet?.call();
            _jumpToId(b.pageId);
          },
          onLongPress: () => _bookmarkActions(l10n, b),
        );
      },
    );
  }

  Future<void> _bookmarkActions(AppLocalizations l10n, Bookmark b) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(l10n.renameBookmark),
              onTap: () => Navigator.pop(ctx, 'rename'),
            ),
            ListTile(
              title: Text(l10n.delete),
              onTap: () => Navigator.pop(ctx, 'delete'),
            ),
          ],
        ),
      ),
    );
    if (choice == null || _state == null) return;
    if (choice == 'delete') {
      _state!.deleteBookmark(b.id);
      setState(() => _bookmarksTick++);
      return;
    }
    if (!mounted) return;
    final ctrl = TextEditingController(text: b.label ?? '');
    final String? renamed;
    try {
      renamed = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(l10n.renameBookmark),
          content: TextField(controller: ctrl, autofocus: true),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text),
              child: Text(l10n.confirm),
            ),
          ],
        ),
      );
    } finally {
      ctrl.dispose();
    }
    if (renamed == null || !mounted) return;
    _state!.updateBookmarkLabel(b.id, renamed);
    setState(() => _bookmarksTick++);
  }

  Widget _highlightsList(
    AppLocalizations l10n, {
    VoidCallback? onCloseSheet,
  }) {
    final _ = _notesTick;
    final rows = _state?.highlightsForBook(widget.bookId) ?? const [];
    if (rows.isEmpty) {
      return Center(child: Text(l10n.highlightsEmpty));
    }
    final night =
        ReaderThemeTokens.of(context).atmosphere == ReadingAtmosphere.night;
    final palette = night ? highlightColorsNight : highlightColors;
    return ListView.builder(
      itemCount: rows.length,
      itemBuilder: (context, i) {
        final h = rows[i];
        final pageId = h['page_id'] as int;
        final start = h['start_offset'] as int;
        final end = h['end_offset'] as int;
        final colorName = h['color'] as String? ?? 'yellow';
        final page = _db?.pageById(pageId);
        final excerpt = page == null
            ? ''
            : highlightListExcerpt(page.body, start, end);
        final printNo = page?.pageNumber?.toString() ?? '—';
        final argb = palette[colorName] ?? palette['yellow']!;
        return ListTile(
          dense: true,
          leading: Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: Color(argb),
              shape: BoxShape.circle,
            ),
          ),
          title: Text(excerpt, maxLines: 2, overflow: TextOverflow.ellipsis),
          subtitle: Text(l10n.notePageLabel(printNo)),
          trailing: IconButton(
            tooltip: l10n.delete,
            icon: const Icon(Icons.delete_outline, size: 18),
            onPressed: () {
              _state?.deleteHighlight(h['id'] as int);
              setState(() => _notesTick++);
            },
          ),
          onTap: () {
            onCloseSheet?.call();
            _jumpToId(pageId);
          },
        );
      },
    );
  }

  Widget _notesList(
    AppLocalizations l10n, {
    VoidCallback? onCloseSheet,
  }) {
    // Depend on tick so list rebuilds when annotations change.
    final _ = _notesTick;
    final notes = _state?.notesForBook(widget.bookId) ?? const [];
    if (notes.isEmpty) {
      return Center(child: Text(l10n.notesEmpty));
    }
    return ListView.builder(
      itemCount: notes.length,
      itemBuilder: (context, i) {
        final n = notes[i];
        final pageId = n['page_id'] as int;
        final preview = n['note'] as String;
        final page = _db?.pageById(pageId);
        final printNo = page?.pageNumber?.toString() ?? '—';
        return ListTile(
          dense: true,
          leading: CircleAvatar(
            radius: 12,
            child: Text('${i + 1}', style: const TextStyle(fontSize: 11)),
          ),
          title: Text(preview, maxLines: 2, overflow: TextOverflow.ellipsis),
          subtitle: Text(l10n.notePageLabel(printNo)),
          onTap: () {
            onCloseSheet?.call();
            _jumpToId(pageId);
          },
          onLongPress: () => _noteActions(l10n, n),
        );
      },
    );
  }

  Future<void> _noteActions(
    AppLocalizations l10n,
    Map<String, Object?> n,
  ) async {
    final id = n['id'] as int;
    final current = n['note'] as String;
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(l10n.addNote),
              onTap: () => Navigator.pop(ctx, 'edit'),
            ),
            ListTile(
              title: Text(l10n.delete),
              onTap: () => Navigator.pop(ctx, 'delete'),
            ),
          ],
        ),
      ),
    );
    if (choice == null || _state == null) return;
    if (choice == 'delete') {
      _state!.deleteNote(id);
      setState(() => _notesTick++);
      return;
    }
    if (!mounted) return;
    final ctrl = TextEditingController(text: current);
    final String? updated;
    try {
      updated = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(l10n.addNote),
          content: TextField(controller: ctrl, maxLines: 4, autofocus: true),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
              child: Text(l10n.confirm),
            ),
          ],
        ),
      );
    } finally {
      ctrl.dispose();
    }
    if (!mounted || updated == null) return;
    if (updated.isEmpty) {
      _state!.deleteNote(id);
    } else {
      _state!.updateNote(id, updated);
    }
    setState(() => _notesTick++);
  }

  Widget _cardPane(
    AppLocalizations l10n,
    String title, {
    VoidCallback? onClose,
  }) {
    final betaka = _db?.meta('betaka');
    final author = widget.authorName ?? _db?.meta('author') ?? '';
    final authorId = widget.authorId;
    final category = _db?.meta('category_name') ?? '';
    final pages = _db?.meta('page_count') ?? '${_ids.length}';
    final t = IshamelaTokens.of(context);
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                l10n.bookCard,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            if (onClose != null)
              IconButton(
                tooltip: l10n.cancel,
                icon: const Icon(Icons.close),
                onPressed: onClose,
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(title, style: Theme.of(context).textTheme.titleSmall),
        if (author.isNotEmpty)
          authorId == null
              ? Text(author)
              : InkWell(
                  onTap: () => AuthorPage.open(
                    context,
                    authorId: authorId,
                    author: Author(id: authorId, name: author),
                  ),
                  child: Text(
                    author,
                    style: TextStyle(
                      color: t.green700,
                      decoration: TextDecoration.underline,
                      decorationColor: t.green700.withValues(alpha: 0.4),
                    ),
                  ),
                ),
        if (category.isNotEmpty) Text(category),
        Text(l10n.pagesCount(int.tryParse(pages) ?? _ids.length)),
        const SizedBox(height: 8),
        FilledButton.tonal(
          onPressed: () async {
            final arabic = Localizations.localeOf(context).languageCode == 'ar';
            final page = _ids.isNotEmpty ? _db?.pageById(_ids[_index]) : null;
            final printNo = page?.pageNumber?.toString() ?? '—';
            final partBit = (page?.part != null && page!.part!.isNotEmpty)
                ? (arabic ? '، ج${page.part}' : ', vol. ${page.part}')
                : '';
            final text = arabic
                ? '$title، $author$partBit، ص$printNo'
                : '$title, $author$partBit, p. $printNo';
            await Clipboard.setData(ClipboardData(text: text));
            if (!mounted) return;
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(l10n.copiedCitation)));
          },
          child: Text(l10n.copyBibliography),
        ),
        Divider(color: t.hairline),
        if (betaka != null && betaka.isNotEmpty)
          SelectableText(betaka, style: const TextStyle(height: 1.6))
        else
          Text(l10n.noBooks),
      ],
    );
  }

  Widget _bodyPane(String title) {
    if (_mode == ReadingMode.continuousV) {
      return NotificationListener<ScrollNotification>(
        onNotification: _onContinuousScroll,
        child: ListView.builder(
          controller: _continuousScroll,
          itemCount: _ids.length,
          itemBuilder: (context, i) {
            final key = _continuousItemKeys.putIfAbsent(i, () => GlobalKey());
            return KeyedSubtree(
              key: key,
              child: _pageContent(title, i, scrollableInner: false),
            );
          },
        ),
      );
    }
    final vertical = _mode == ReadingMode.pagedV;
    // Reader [Directionality] is RTL. Horizontal PageView already maps
    // forward = right→left (SPEC-005/009). Setting reverse:true would
    // undo that and feel like a Western book.
    return PageView.builder(
      controller: _pageController,
      scrollDirection: vertical ? Axis.vertical : Axis.horizontal,
      reverse: false,
      itemCount: _ids.length,
      onPageChanged: _onPage,
      itemBuilder: (context, i) => _pageContent(title, i),
    );
  }

  /// Inner body scroll: at top/bottom overscroll, advance the page (paged modes).
  /// SPEC-026: scrolling inside one print page does not hide chrome.
  bool _onPageBodyScroll(ScrollNotification notification) {
    if (_mode == ReadingMode.continuousV) return false;
    if (notification.depth != 0) return false;
    if (notification is! OverscrollNotification) return false;
    if (_edgePageLock) return false;

    final over = notification.overscroll;
    // Ignore tiny rubber-band noise.
    if (over.abs() < 12) return false;

    _edgePageLock = true;
    if (over > 0) {
      _goRelative(1); // past bottom → next page
    } else {
      _goRelative(-1); // past top → previous page
    }
    Future<void>.delayed(const Duration(milliseconds: 450), () {
      _edgePageLock = false;
    });
    return false;
  }

  bool _onContinuousScroll(ScrollNotification notification) {
    if (notification.depth != 0) {
      if (notification is ScrollUpdateNotification) {
        _chrome.onInnerPageScroll(notification.scrollDelta ?? 0);
      }
      return false;
    }
    if (notification is ScrollUpdateNotification) {
      final delta = notification.scrollDelta ?? 0;
      if (!_programmaticContinuousScroll &&
          delta != 0 &&
          _chrome.onContinuousScrollDelta(delta)) {
        _commitChrome();
      }
      if (!_programmaticContinuousScroll) {
        _syncContinuousVisiblePage();
      }
    } else if (notification is ScrollEndNotification) {
      _chrome.onContinuousScrollEnd();
      if (!_programmaticContinuousScroll) {
        _syncContinuousVisiblePage();
      }
    }
    return false;
  }

  void _syncContinuousVisiblePage() {
    if (!_continuousScroll.hasClients) return;
    final viewport = _continuousScroll.position.context.notificationContext
        ?.findRenderObject();
    if (viewport is! RenderBox || !viewport.hasSize) return;
    int? bestIdx;
    var bestDist = double.infinity;
    for (final entry in _continuousItemKeys.entries) {
      final box = entry.value.currentContext?.findRenderObject();
      if (box is! RenderBox || !box.hasSize || !box.attached) continue;
      final top = box.localToGlobal(Offset.zero, ancestor: viewport).dy;
      final bottom = top + box.size.height;
      if (bottom <= 0 || top >= viewport.size.height) continue;
      final dist = top.abs();
      if (dist < bestDist) {
        bestDist = dist;
        bestIdx = entry.key;
      }
    }
    if (bestIdx != null && bestIdx != _index) {
      _onPage(bestIdx, fromContinuousScroll: true);
    }
  }

  Widget _pageContent(
    String title,
    int i, {
    bool scrollableInner = true,
  }) {
    final page = _db!.pageById(_ids[i])!;
    final printNo = page.pageNumber?.toString() ?? '—';
    final part = page.part;
    final header = [
      title,
      if (part != null && part.isNotEmpty) part,
      printNo,
    ].join(' · ');
    final searchRanges = _highlightPageIds.contains(page.id)
        ? (_searchRangesByPage[page.id] ?? const <({int start, int end})>[])
        : const <({int start, int end})>[];
    final author = widget.authorName ?? _db?.meta('author') ?? '';
    final footnotes = page.footnotes?.trim();
    final hasFootnotes = footnotes != null && footnotes.isNotEmpty;
    final footnotesKey = hasFootnotes ? GlobalKey() : null;
    final l10n = AppLocalizations.of(context);
    final styles = ref.watch(readerTextStylesProvider);

    final bodyContent = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: scrollableInner ? MainAxisSize.max : MainAxisSize.min,
      children: [
        _state == null
            ? buildBodyDisplay(page.body)
            : AnnotatedBody(
                body: page.body,
                bookId: widget.bookId,
                pageId: page.id,
                state: _state!,
                title: title,
                author: author,
                part: part,
                pageNumber: page.pageNumber,
                textStyles: styles,
                searchRanges: searchRanges,
                onSelectionActive: (active) {
                  _chrome.selectionActive = active;
                },
                onInteractivePointerDown: () {
                  _tapInteractive = true;
                },
                onNotesChanged: () {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) {
                      setState(() => _notesTick++);
                    }
                  });
                },
              ),
        if (hasFootnotes) ...[
          const SizedBox(height: 24),
          Divider(color: ReaderThemeTokens.of(context).hairline),
          Text(
            key: footnotesKey,
            l10n.footnotes,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: IshamelaTokens.of(context).gold,
              fontFamily: 'Amiri',
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          _FootnotesBlock(
            text: footnotes,
            fontSize: styles.fontSize * 0.9,
            fontFamily: styles.font.familyName,
          ),
        ],
      ],
    );

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: scrollableInner ? MainAxisSize.max : MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  header,
                  style: Theme.of(context).textTheme.labelLarge,
                  textAlign: TextAlign.center,
                ),
              ),
              if (hasFootnotes && footnotesKey != null)
                ActionChip(
                  visualDensity: VisualDensity.compact,
                  label: Text(
                    l10n.footnotes,
                    style: const TextStyle(fontSize: 11),
                  ),
                  onPressed: () {
                    final ctx = footnotesKey.currentContext;
                    if (ctx != null) {
                      Scrollable.ensureVisible(
                        ctx,
                        duration: const Duration(milliseconds: 260),
                        curve: Curves.easeOutCubic,
                      );
                    }
                  },
                ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: RosetteDivider(size: 14),
          ),
          if (scrollableInner)
            Expanded(
              child: NotificationListener<ScrollNotification>(
                onNotification: _onPageBodyScroll,
                child: SingleChildScrollView(
                  // Always scrollable so short pages still receive drag/overscroll
                  // (otherwise only the header/footer hit the PageView).
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  child: bodyContent,
                ),
              ),
            )
          else
            bodyContent,
        ],
      ),
    );
  }

  void _openTocSheet(BuildContext context, AppLocalizations l10n) {
    _expandCurrentTocPath();
    showGlassSheet<void>(
      context: context,
      builder: (sheetCtx) => Directionality(
        textDirection: TextDirection.rtl,
        child: SafeArea(
          child: SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.6,
            child: StatefulBuilder(
              builder: (_, setSheet) => _sideIndexPane(
                l10n,
                onSheetTick: () => setSheet(() {}),
                onCloseSheet: () => Navigator.pop(sheetCtx),
              ),
            ),
          ),
        ),
      ),
    );
    _scheduleTocReveal();
  }

  void _openCardSheet(
    BuildContext context,
    AppLocalizations l10n,
    String title,
  ) {
    showGlassSheet<void>(
      context: context,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: SafeArea(
          child: SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.5,
            child: _cardPane(l10n, title),
          ),
        ),
      ),
    );
  }
}

/// Footnotes zone: gold-tint existing leading markers; never invent numbers (SPEC-012).
class _FootnotesBlock extends StatelessWidget {
  const _FootnotesBlock({
    required this.text,
    required this.fontSize,
    this.fontFamily,
  });

  final String text;
  final double fontSize;
  final String? fontFamily;

  static final _marker = RegExp(
    r'^([\(\[]?\s*[0-9٠-٩۰-۹]+\s*[\)\].:\-–—]?\s*)',
  );

  @override
  Widget build(BuildContext context) {
    final gold = IshamelaTokens.of(context).gold;
    final base = TextStyle(
      fontSize: fontSize,
      height: 1.8,
      fontFamily: fontFamily,
    );
    final lines = text.split('\n');
    final spans = <InlineSpan>[];
    for (var i = 0; i < lines.length; i++) {
      if (i > 0) spans.add(const TextSpan(text: '\n'));
      final line = lines[i];
      final m = _marker.firstMatch(line);
      if (m != null) {
        spans.add(
          TextSpan(
            text: m.group(1),
            style: base.copyWith(color: gold, fontWeight: FontWeight.w700),
          ),
        );
        spans.add(TextSpan(text: line.substring(m.end), style: base));
      } else {
        spans.add(TextSpan(text: line, style: base));
      }
    }
    return SelectableText.rich(TextSpan(children: spans));
  }
}

class _PaneEdgeButton extends StatelessWidget {
  const _PaneEdgeButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return GlassCluster(
      shape: const GlassShape.pill(),
      useBackdrop: false,
      child: TonalIconButton(
        tooltip: tooltip,
        icon: icon,
        onPressed: onPressed,
      ),
    );
  }
}

/// SPEC-026: collapses the reader bars so the page grows into their space.
class _MaybeGlassBar extends StatelessWidget {
  const _MaybeGlassBar({required this.enabled, required this.child});

  final bool enabled;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;
    return GlassAppBar(child: child);
  }
}

class _MaybeGlassPill extends StatelessWidget {
  const _MaybeGlassPill({required this.enabled, required this.child});

  final bool enabled;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;
    return GlassToolbar(child: child);
  }
}

class _CompactGlassBar extends StatelessWidget {
  const _CompactGlassBar({
    required this.title,
    required this.subtitle,
    required this.atmosphere,
    required this.actions,
  });

  final String title;
  final String? subtitle;
  final ReadingAtmosphere atmosphere;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final tokens = GlassTokens.forAtmosphere(atmosphere);
    return IconTheme(
      data: IconThemeData(color: tokens.foregroundAccent),
      child: Padding(
        padding: const EdgeInsetsDirectional.only(start: 4, end: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const BackButton(),
            Flexible(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 280),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Amiri',
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                        color: tokens.foregroundInk,
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: tokens.foregroundInk.withValues(alpha: 0.72),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            ...actions,
          ],
        ),
      ),
    );
  }
}

class _GlassOrColumn extends StatelessWidget {
  const _GlassOrColumn({required this.glass, required this.children});

  final bool glass;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    if (!glass) return Column(children: children);
    Widget? top;
    Widget? middle;
    Widget? bottom;
    for (final child in children) {
      if (child is Expanded) {
        middle = child.child;
      } else if (middle == null) {
        top = child;
      } else {
        bottom = child;
      }
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        if (middle != null) Positioned.fill(child: middle),
        if (top != null) Positioned(top: 0, left: 0, right: 0, child: top),
        if (bottom != null)
          Positioned(left: 0, right: 0, bottom: 0, child: bottom),
      ],
    );
  }
}

class _AnimatedChrome extends StatelessWidget {
  const _AnimatedChrome({
    required this.visible,
    required this.alignment,
    required this.child,
  });

  final bool visible;
  final Alignment alignment;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    return ClipRect(
      child: AnimatedAlign(
        alignment: alignment,
        heightFactor: visible ? 1 : 0,
        duration: reduce
            ? Duration.zero
            : ReaderChromeController.animationDuration,
        curve: Curves.easeInOut,
        child: child,
      ),
    );
  }
}

class _ResumeProgressChip extends StatelessWidget {
  const _ResumeProgressChip({
    required this.label,
    required this.dismissLabel,
    required this.onResume,
    required this.onDismiss,
  });

  final String label;
  final String dismissLabel;
  final VoidCallback onResume;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final t = IshamelaTokens.of(context);
    return Material(
      color: t.card,
      elevation: 2,
      shadowColor: t.ink.withValues(alpha: 0.2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: t.hairline),
      ),
      child: InkWell(
        onTap: onResume,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsetsDirectional.only(start: 14),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: kFontUi,
                    fontSize: 13,
                    color: t.ink,
                  ),
                ),
              ),
              IconButton(
                tooltip: dismissLabel,
                visualDensity: VisualDensity.compact,
                icon: Icon(Icons.close, size: 18, color: t.muted),
                onPressed: onDismiss,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
