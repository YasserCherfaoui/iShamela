import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ishamela/l10n/app_localizations.dart';

import 'package:ishamela/core/db/state_database.dart';
import 'package:ishamela/core/models/models.dart';
import 'package:ishamela/core/providers.dart';
import 'package:ishamela/core/search/normalizer.dart';
import 'package:ishamela/core/search/normalizer_map.dart';
import 'package:ishamela/features/catalog/author_page.dart';
import 'package:ishamela/features/reader/annotated_body.dart';
import 'package:ishamela/features/reader/body_html.dart';
import 'package:ishamela/features/reader/book_database.dart';
import 'package:ishamela/features/reader/export_sheet.dart';
import 'package:ishamela/features/reader/sticky_toc.dart';
import 'package:ishamela/ui/app_search_field.dart';
import 'package:ishamela/ui/jump_sheet.dart';
import 'package:ishamela/ui/page_pill.dart';
import 'package:ishamela/ui/rosette_divider.dart';
import 'package:ishamela/ui/segmented_pills.dart';
import 'package:ishamela/ui/theme/ishamela_theme.dart';
import 'package:ishamela/ui/theme/ishamela_tokens.dart';
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

/// SPEC-005 / SPEC-009 reader: TOC, HTML body, modes, بطاقة, in-book search.
class ReaderPage extends ConsumerStatefulWidget {
  const ReaderPage({
    super.key,
    required this.bookId,
    this.title,
    this.authorName,
    this.authorId,
    this.initialPageId,
    this.initialPrintPage,
    this.initialSearchQuery,
    this.exactPhrase = false,
  });

  final int bookId;
  final String? title;
  final String? authorName;
  final int? authorId;

  /// Prefer [initialPrintPage] when set (SPEC-014 resume).
  final int? initialPageId;
  final int? initialPrintPage;

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
          initialSearchQuery: initialSearchQuery,
          exactPhrase: exactPhrase,
        ),
      ),
    );
  }

  @override
  ConsumerState<ReaderPage> createState() => _ReaderPageState();
}

class _ReaderPageState extends ConsumerState<ReaderPage> {
  BookDatabase? _db;
  List<int> _ids = const [];
  List<TocEntry> _toc = const [];
  int _notesTick = 0;
  int _bookmarksTick = 0;
  int _index = 0;
  PageController? _pageController;
  final _jumpCtrl = TextEditingController();
  final _searchCtrl = TextEditingController();
  Object? _error;
  ReadingMode _mode = ReadingMode.pagedH;
  bool _showToc = true;
  bool _showCard = true;
  bool _exactPhrase = false;
  List<BookSearchHit> _hits = const [];
  Set<int> _highlightPageIds = {};
  StateDatabase? _state;
  int _paneTab = 0;

  /// Prevents multi-page jumps from a single overscroll gesture.
  bool _edgePageLock = false;

  @override
  void initState() {
    super.initState();
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
      final saved = state.readingPageId(widget.bookId);
      var index = 0;
      var resumeMissing = false;
      if (widget.initialPrintPage != null) {
        final p = db.pageByPrintNumber(widget.initialPrintPage!);
        if (p != null) {
          final i = ids.indexOf(p.id);
          if (i >= 0) index = i;
        } else {
          resumeMissing = true;
        }
      } else if (widget.initialPageId != null) {
        final i = ids.indexOf(widget.initialPageId!);
        if (i >= 0) {
          index = i;
        } else {
          resumeMissing = true;
        }
      }
      if ((widget.initialPrintPage != null || widget.initialPageId != null) &&
          resumeMissing &&
          saved != null) {
        final i = ids.indexOf(saved);
        if (i >= 0) index = i;
      } else if (widget.initialPrintPage == null &&
          widget.initialPageId == null &&
          saved != null) {
        final i = ids.indexOf(saved);
        if (i >= 0) index = i;
      }
      final mode = _parseReadingMode(state.setting('reading_mode'));
      final page = db.pageById(ids[index]);
      final section = _sectionTitleForToc(db.tocEntries(), ids[index]);
      state.upsertReadingState(
        bookId: widget.bookId,
        pageId: ids[index],
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      );
      state.touchReadingHistory(
        bookId: widget.bookId,
        pageId: ids[index],
        part: page?.part,
        printPage: page?.pageNumber,
        sectionTitle: section,
        nowMs: DateTime.now().millisecondsSinceEpoch,
      );
      if (!mounted) {
        db.close();
        return;
      }
      setState(() {
        _db = db;
        _state = state;
        _ids = ids;
        _toc = db.tocEntries();
        _index = index;
        _mode = mode;
        _pageController = PageController(initialPage: index);
        _jumpCtrl.text = page?.pageNumber?.toString() ?? '';
      });
      if (widget.initialSearchQuery != null &&
          widget.initialSearchQuery!.trim().isNotEmpty) {
        _runSearch();
      }
      if (resumeMissing && mounted) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.pageNotFound)),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
    }
  }

  @override
  void dispose() {
    _closeHistorySession();
    _pageController?.dispose();
    _jumpCtrl.dispose();
    _searchCtrl.dispose();
    _db?.close();
    super.dispose();
  }

  void _closeHistorySession() {
    final state = _state;
    final db = _db;
    if (state == null || db == null || _ids.isEmpty) return;
    final pageId = _ids[_index];
    final page = db.pageById(pageId);
    final now = DateTime.now().millisecondsSinceEpoch;
    state.upsertReadingState(
      bookId: widget.bookId,
      pageId: pageId,
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

  String? _sectionTitleFor(int pageId) =>
      _sectionTitleForToc(_toc, pageId);

  static String? _sectionTitleForToc(List<TocEntry> toc, int pageId) {
    if (toc.isEmpty) return null;
    final i = stickyTocIndex(toc.map((e) => e.pageId).toList(), pageId);
    return toc[i].title;
  }

  Future<void> _persist(int pageId) async {
    final state = await ref.read(stateDatabaseProvider.future);
    final now = DateTime.now().millisecondsSinceEpoch;
    state.upsertReadingState(
      bookId: widget.bookId,
      pageId: pageId,
      updatedAt: now,
    );
    final page = _db?.pageById(pageId);
    state.touchReadingHistory(
      bookId: widget.bookId,
      pageId: pageId,
      part: page?.part,
      printPage: page?.pageNumber,
      sectionTitle: _sectionTitleFor(pageId),
      nowMs: now,
    );
  }

  Future<void> _setMode(ReadingMode mode) async {
    final state = await ref.read(stateDatabaseProvider.future);
    state.setSetting('reading_mode', _readingModeKey(mode));
    setState(() {
      _mode = mode;
      _pageController?.dispose();
      _pageController = PageController(initialPage: _index);
    });
  }

  void _onPage(int i) {
    setState(() {
      _index = i;
      _syncJumpField();
    });
    _persist(_ids[i]);
  }

  void _syncJumpField() {
    if (_db == null || _ids.isEmpty) return;
    final page = _db!.pageById(_ids[_index]);
    final n = page?.pageNumber;
    final text = n?.toString() ?? '';
    if (_jumpCtrl.text != text) {
      _jumpCtrl.text = text;
    }
  }

  void _goRelative(int delta) {
    final next = _index + delta;
    if (next < 0 || next >= _ids.length) return;
    if (_mode == ReadingMode.continuousV) {
      _onPage(next);
    } else {
      _pageController?.jumpToPage(next);
      _onPage(next);
    }
  }

  void _jumpToId(int pageId) {
    final i = _ids.indexOf(pageId);
    if (i < 0) return;
    if (_mode == ReadingMode.continuousV) {
      setState(() {
        _index = i;
        _syncJumpField();
      });
      _persist(pageId);
    } else {
      _pageController?.jumpToPage(i);
      _onPage(i);
    }
  }

  void _runSearch() {
    if (_db == null) return;
    final hits = _db!.searchInBook(
      _searchCtrl.text,
      exactPhrase: _exactPhrase,
    );
    setState(() {
      _hits = hits;
      _highlightPageIds = hits.map((h) => h.pageId).toSet();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final title = widget.title ?? _db?.meta('title') ?? 'book_${widget.bookId}';
    final width = MediaQuery.sizeOf(context).width;
    final wide = width >= 800;
    final veryWide = width >= 1200;
    final showToc = wide && (veryWide || _showToc);
    final showCard = wide && (veryWide || _showCard);
    final reader = ReaderThemeTokens.of(context);
    final page = (_db != null && _ids.isNotEmpty)
        ? _db!.pageById(_ids[_index])
        : null;
    final printNo = page?.pageNumber?.toString() ?? '—';
    final part = page?.part;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: reader.ground,
        appBar: AppBar(
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
          actions: [
            if (wide)
              SizedBox(
                width: 200,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: AppSearchField(
                    hintText: l10n.searchInBook,
                    initialQuery: _searchCtrl.text,
                    onChanged: (v) => _searchCtrl.text = v,
                    onSubmitted: (_) {
                      _runSearch();
                      setState(() {});
                    },
                  ),
                ),
              )
            else
              IconButton(
                tooltip: l10n.searchInBook,
                icon: const Icon(Icons.search),
                onPressed: () => _openSearchSheet(l10n),
              ),
            _bookmarkToggleButton(l10n, page),
            if (wide)
              TextButton(
                onPressed: () => setState(() => _showToc = !_showToc),
                child: Text(l10n.toc),
              )
            else
              IconButton(
                tooltip: l10n.toc,
                icon: const Icon(Icons.list_alt),
                onPressed: () => _openTocSheet(context, l10n),
              ),
            if (wide)
              TextButton(
                onPressed: () => setState(() => _showCard = !_showCard),
                child: Text(l10n.bookCard),
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
                  case 'atm_paper':
                    ref
                        .read(readingAtmosphereProvider.notifier)
                        .save(ReadingAtmosphere.paper);
                  case 'atm_sepia':
                    ref
                        .read(readingAtmosphereProvider.notifier)
                        .save(ReadingAtmosphere.sepia);
                  case 'atm_night':
                    ref
                        .read(readingAtmosphereProvider.notifier)
                        .save(ReadingAtmosphere.night);
                }
              },
              itemBuilder: (_) {
                final state = ref.read(stateDatabaseProvider).maybeWhen(
                      data: (s) => s,
                      orElse: () => null,
                    );
                final count = state?.annotationCountForBook(widget.bookId) ?? 0;
                return [
                  if (!wide)
                    PopupMenuItem(value: 'card', child: Text(l10n.bookCard)),
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
                  PopupMenuItem(
                    value: 'mode_c',
                    child: Text(l10n.modeContinuousV),
                  ),
                  const PopupMenuDivider(),
                  PopupMenuItem(
                    value: 'atm_paper',
                    child: Text(l10n.atmospherePaper),
                  ),
                  PopupMenuItem(
                    value: 'atm_sepia',
                    child: Text(l10n.atmosphereSepia),
                  ),
                  PopupMenuItem(
                    value: 'atm_night',
                    child: Text(l10n.atmosphereNight),
                  ),
                ];
              },
            ),
          ],
        ),
        body: _error != null
            ? Center(child: Text('$_error'))
            : _db == null
                ? const Center(child: CircularProgressIndicator())
                : Column(
                    children: [
                      if (_hits.isNotEmpty) _searchHits(l10n),
                      Expanded(
                        child: Row(
                          children: [
                            if (showToc)
                              SizedBox(
                                width: 300,
                                child: _sideIndexPane(l10n),
                              ),
                            if (showToc) const VerticalDivider(width: 1),
                            Expanded(
                              child: Center(
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxWidth: 660,
                                  ),
                                  child: _bodyPane(title),
                                ),
                              ),
                            ),
                            if (showCard) const VerticalDivider(width: 1),
                            if (showCard)
                              SizedBox(
                                width: 300,
                                child: _cardPane(l10n, title),
                              ),
                          ],
                        ),
                      ),
                      _bottomNavBar(l10n),
                    ],
                  ),
      ),
    );
  }

  Future<void> _openSearchSheet(AppLocalizations l10n) async {
    final t = IshamelaTokens.of(context);
    await showModalBottomSheet<void>(
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
                        FilterChip(
                          label: Text(l10n.exactPhrase),
                          selected: _exactPhrase,
                          onSelected: (v) {
                            setState(() => _exactPhrase = v);
                            setLocal(() {});
                          },
                        ),
                        const Spacer(),
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
                            return ListTile(
                              dense: true,
                              title: Text('ص ${h.pageNumber ?? '—'}'),
                              subtitle: Text(
                                h.snippet,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              onTap: () {
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
    return SizedBox(
      height: 140,
      child: ListView.builder(
        itemCount: _hits.length,
        itemBuilder: (context, i) {
          final h = _hits[i];
          return ListTile(
            dense: true,
            title: Text(
              'ص ${h.pageNumber ?? '—'}',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            subtitle: Text(
              h.snippet,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            onTap: () {
              _jumpToId(h.pageId);
            },
          );
        },
      ),
    );
  }

  Widget _bottomNavBar(AppLocalizations l10n) {
    if (_ids.isEmpty || _db == null) return const SizedBox.shrink();
    final reader = ReaderThemeTokens.of(context);
    final t = IshamelaTokens.of(context);
    final page = _db!.pageById(_ids[_index]);
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
      color: reader.raised,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: reader.hairline)),
          color: reader.raised,
        ),
        child: SafeArea(
          top: false,
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
                      inactiveTrackColor: t.segmentTrack,
                    ),
                    child: Slider(
                      value: _index.toDouble(),
                      min: 0,
                      max: (_ids.length - 1).toDouble(),
                      onChanged: (v) {
                        final i = v.round();
                        if (_mode == ReadingMode.continuousV) {
                          _onPage(i);
                        } else {
                          _pageController?.jumpToPage(i);
                          _onPage(i);
                        }
                      },
                    ),
                  ),
                Row(
                  children: [
                    TonalIconButton(
                      tooltip: l10n.previousPage,
                      icon: Icons.chevron_right,
                      enabled: canPrev,
                      onPressed: () => _goRelative(-1),
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
                            onGo: (raw) async {
                              final n = int.tryParse(raw.trim());
                              if (n == null) return false;
                              final p = _db!.pageByPrintNumber(n);
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
                      enabled: canNext,
                      onPressed: () => _goRelative(1),
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
    final marked = state != null &&
        page != null &&
        state.isPageBookmarked(
          bookId: widget.bookId,
          pageId: page.id,
          part: page.part,
        );
    final gold = IshamelaTokens.of(context).goldSoft;
    final reduce = MediaQuery.disableAnimationsOf(context);
    return SizedBox(
      width: 38,
      height: 38,
      child: IconButton(
        padding: EdgeInsets.zero,
        tooltip: l10n.bookmarks,
        icon: AnimatedScale(
          scale: marked ? 1.1 : 1.0,
          duration: reduce
              ? Duration.zero
              : const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          child: Icon(
            marked ? Icons.bookmark : Icons.bookmark_border,
            color: marked ? gold : IshamelaTokens.of(context).muted,
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
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.bookmarkRemoved)),
      );
    }
  }

  /// [onSheetTick] rebuilds a modal host — parent [setState] alone does not
  /// refresh [showModalBottomSheet] content.
  Widget _sideIndexPane(AppLocalizations l10n, {VoidCallback? onSheetTick}) {
    // Depend on ticks so badges rebuild when annotations/bookmarks change.
    final ticks = _notesTick + _bookmarksTick;
    assert(ticks >= 0);
    final noteCount = _state?.notesForBook(widget.bookId).length ?? 0;
    final bookmarkCount = _state?.bookmarksForBook(widget.bookId).length ?? 0;
    final bookmarkLabel = bookmarkCount > 0
        ? '${l10n.bookmarks} $bookmarkCount'
        : l10n.bookmarks;
    final notesLabel =
        noteCount > 0 ? '${l10n.notesTab} $noteCount' : l10n.notesTab;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
          child: SegmentedPills(
            labels: [l10n.toc, bookmarkLabel, notesLabel],
            selectedIndex: _paneTab,
            onChanged: (i) {
              setState(() => _paneTab = i);
              onSheetTick?.call();
            },
          ),
        ),
        Expanded(
          child: IndexedStack(
            index: _paneTab,
            children: [
              _tocList(l10n),
              _bookmarksList(l10n),
              _notesList(l10n),
            ],
          ),
        ),
      ],
    );
  }

  Widget _tocList(AppLocalizations l10n) {
    if (_toc.isEmpty) {
      return Center(child: Text(l10n.tocEmpty));
    }
    final currentId = _ids.isNotEmpty ? _ids[_index] : _toc.first.pageId;
    final active = stickyTocIndex(
      _toc.map((e) => e.pageId).toList(),
      currentId,
    );
    final depths = tocIndentDepths(
      ids: _toc.map((e) => e.id).toList(),
      parentIds: _toc.map((e) => e.parentId).toList(),
    );
    final t = IshamelaTokens.of(context);
    return ListView.builder(
      itemCount: _toc.length,
      itemBuilder: (context, i) {
        final e = _toc[i];
        final selected = i == active;
        final printNo = _db?.pageById(e.pageId)?.pageNumber?.toString() ?? '—';
        final depth = depths[i].clamp(0, 6);
        return Padding(
          padding: EdgeInsetsDirectional.only(start: 8.0 + depth * 14),
          child: Material(
            color: selected ? t.green100 : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => _jumpToId(e.pageId),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        e.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Amiri',
                          fontWeight:
                              selected ? FontWeight.w700 : FontWeight.w400,
                          fontSize: 14,
                          color: selected ? t.emphasis : t.ink,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      printNo,
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
        );
      },
    );
  }

  Widget _bookmarksList(AppLocalizations l10n) {
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
            style: TextStyle(
              fontFamily: kFontUi,
              fontSize: 11,
              color: t.muted,
            ),
          ),
          onTap: () => _jumpToId(b.pageId),
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
    final renamed = await showDialog<String>(
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
    if (renamed == null || !mounted) return;
    _state!.updateBookmarkLabel(b.id, renamed);
    setState(() => _bookmarksTick++);
  }

  Widget _notesList(AppLocalizations l10n) {
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
            child: Text(
              '${i + 1}',
              style: const TextStyle(fontSize: 11),
            ),
          ),
          title: Text(
            preview,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(l10n.notePageLabel(printNo)),
          onTap: () => _jumpToId(pageId),
        );
      },
    );
  }

  Widget _cardPane(AppLocalizations l10n, String title) {
    final betaka = _db?.meta('betaka');
    final author = widget.authorName ?? _db?.meta('author') ?? '';
    final authorId = widget.authorId;
    final category = _db?.meta('category_name') ?? '';
    final pages = _db?.meta('page_count') ?? '${_ids.length}';
    final t = IshamelaTokens.of(context);
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Text(l10n.bookCard, style: Theme.of(context).textTheme.titleMedium),
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
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(l10n.copiedCitation)),
            );
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
      return ListView.builder(
        itemCount: _ids.length,
        itemBuilder: (context, i) => _pageContent(title, i),
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

  Widget _pageContent(String title, int i) {
    final page = _db!.pageById(_ids[i])!;
    final printNo = page.pageNumber?.toString() ?? '—';
    final part = page.part;
    final header = [
      title,
      if (part != null && part.isNotEmpty) part,
      printNo,
    ].join(' · ');
    final searchHit = _highlightPageIds.contains(page.id);
    final author = widget.authorName ?? _db?.meta('author') ?? '';
    final footnotes = page.footnotes?.trim();
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            header,
            style: Theme.of(context).textTheme.labelLarge,
            textAlign: TextAlign.center,
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: RosetteDivider(size: 14),
          ),
          Expanded(
            child: NotificationListener<ScrollNotification>(
              onNotification: _onPageBodyScroll,
              child: SingleChildScrollView(
                // Always scrollable so short pages still receive drag/overscroll
                // (otherwise only the header/footer hit the PageView).
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    searchHit
                        ? _highlightedBody(page.body)
                        : (_state == null
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
                                textStyles: ref.watch(readerTextStylesProvider),
                                onNotesChanged: () {
                                  WidgetsBinding.instance
                                      .addPostFrameCallback((_) {
                                    if (mounted) {
                                      setState(() => _notesTick++);
                                    }
                                  });
                                },
                              )),
                    if (footnotes != null && footnotes.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      Divider(color: ReaderThemeTokens.of(context).hairline),
                      Text(
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
                        fontSize:
                            (ref.watch(readerTextStylesProvider).fontSize) * 0.9,
                        fontFamily:
                            ref.watch(readerTextStylesProvider).font.familyName,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _highlightedBody(String body) {
    final nr = normalizeWithMap(body);
    final q = normalize(_searchCtrl.text);
    final tokens = _exactPhrase
        ? [q]
        : q.split(RegExp(r'\s+')).where((t) => t.isNotEmpty);
    final ranges = <({int start, int end})>[];
    for (final t in tokens) {
      ranges.addAll(findHighlightRanges(nr, t));
    }
    ranges.sort((a, b) => a.start.compareTo(b.start));
    if (ranges.isEmpty) return buildBodyDisplay(body);
    final reader = ReaderThemeTokens.of(context);
    final spans = <InlineSpan>[];
    var cursor = 0;
    final base = TextStyle(
      fontSize: 20,
      height: 1.9,
      color: reader.body,
    );
    var hi = base.copyWith(backgroundColor: reader.highlight);
    if (reader.highlightUnderline != null) {
      hi = hi.copyWith(
        decoration: TextDecoration.underline,
        decorationColor: reader.highlightUnderline,
        decorationThickness: 2,
      );
    }
    for (final r in ranges) {
      if (r.start < cursor) continue;
      if (r.start > cursor) {
        spans.add(TextSpan(text: body.substring(cursor, r.start), style: base));
      }
      final end = r.end.clamp(0, body.length);
      spans.add(TextSpan(text: body.substring(r.start, end), style: hi));
      cursor = end;
    }
    if (cursor < body.length) {
      spans.add(TextSpan(text: body.substring(cursor), style: base));
    }
    return Text.rich(TextSpan(children: spans), textAlign: TextAlign.justify);
  }

  void _openTocSheet(BuildContext context, AppLocalizations l10n) {
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: SafeArea(
          child: SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.6,
            child: StatefulBuilder(
              builder: (_, setSheet) => _sideIndexPane(
                l10n,
                onSheetTick: () => setSheet(() {}),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _openCardSheet(
    BuildContext context,
    AppLocalizations l10n,
    String title,
  ) {
    showModalBottomSheet<void>(
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
            style: base.copyWith(
              color: gold,
              fontWeight: FontWeight.w700,
            ),
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
