import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ishamela/l10n/app_localizations.dart';

import 'package:ishamela/core/db/state_database.dart';
import 'package:ishamela/core/providers.dart';
import 'package:ishamela/core/search/normalizer.dart';
import 'package:ishamela/core/search/normalizer_map.dart';
import 'package:ishamela/features/reader/annotated_body.dart';
import 'package:ishamela/features/reader/body_html.dart';
import 'package:ishamela/features/reader/book_database.dart';
import 'package:ishamela/features/reader/sticky_toc.dart';

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
  });

  final int bookId;
  final String? title;
  final String? authorName;

  static Future<void> open(
    BuildContext context, {
    required int bookId,
    String? title,
    String? authorName,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ReaderPage(
          bookId: bookId,
          title: title,
          authorName: authorName,
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
  int _index = 0;
  PageController? _pageController;
  final _jumpCtrl = TextEditingController();
  final _searchCtrl = TextEditingController();
  Object? _error;
  ReadingMode _mode = ReadingMode.pagedH;
  bool _showToc = true;
  bool _showCard = true;
  bool _searchOpen = false;
  bool _exactPhrase = false;
  List<BookSearchHit> _hits = const [];
  Set<int> _highlightPageIds = {};
  StateDatabase? _state;

  @override
  void initState() {
    super.initState();
    _open();
  }

  Future<void> _open() async {
    try {
      final paths = await ref.read(appPathsProvider.future);
      final state = await ref.read(stateDatabaseProvider.future);
      final db = BookDatabase.open(paths, widget.bookId);
      final ids = db.pageIds();
      if (ids.isEmpty) {
        db.close();
        setState(() => _error = 'empty book');
        return;
      }
      final saved = state.readingPageId(widget.bookId);
      var index = 0;
      if (saved != null) {
        final i = ids.indexOf(saved);
        if (i >= 0) index = i;
      }
      final mode = _parseReadingMode(state.setting('reading_mode'));
      setState(() {
        _db = db;
        _state = state;
        _ids = ids;
        _toc = db.tocEntries();
        _index = index;
        _mode = mode;
        _pageController = PageController(initialPage: index);
      });
    } catch (e) {
      setState(() => _error = e);
    }
  }

  @override
  void dispose() {
    _pageController?.dispose();
    _jumpCtrl.dispose();
    _searchCtrl.dispose();
    _db?.close();
    super.dispose();
  }

  Future<void> _persist(int pageId) async {
    final state = await ref.read(stateDatabaseProvider.future);
    state.upsertReadingState(
      bookId: widget.bookId,
      pageId: pageId,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
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
    setState(() => _index = i);
    _persist(_ids[i]);
  }

  void _jumpToId(int pageId) {
    final i = _ids.indexOf(pageId);
    if (i < 0) return;
    if (_mode == ReadingMode.continuousV) {
      setState(() => _index = i);
      _persist(pageId);
    } else {
      _pageController?.jumpToPage(i);
      _onPage(i);
    }
  }

  void _jumpToPrintPage() {
    final n = int.tryParse(_jumpCtrl.text.trim());
    if (n == null || _db == null) return;
    final page = _db!.pageByPrintNumber(n);
    if (page == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).pageNotFound)),
      );
      return;
    }
    _jumpToId(page.id);
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
    final wide = MediaQuery.sizeOf(context).width >= 800;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
          actions: [
            if (_ids.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Center(
                  child: Directionality(
                    textDirection: TextDirection.ltr,
                    child: Text(
                      l10n.readerProgress(_index + 1, _ids.length),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ),
              ),
            IconButton(
              tooltip: l10n.searchInBook,
              icon: const Icon(Icons.search),
              onPressed: () => setState(() => _searchOpen = !_searchOpen),
            ),
            IconButton(
              tooltip: l10n.toc,
              icon: const Icon(Icons.list_alt),
              onPressed: () {
                if (wide) {
                  setState(() => _showToc = !_showToc);
                } else {
                  _openTocSheet(context, l10n);
                }
              },
            ),
            IconButton(
              tooltip: l10n.bookCard,
              icon: const Icon(Icons.info_outline),
              onPressed: () {
                if (wide) {
                  setState(() => _showCard = !_showCard);
                } else {
                  _openCardSheet(context, l10n, title);
                }
              },
            ),
            PopupMenuButton<ReadingMode>(
              tooltip: l10n.readingMode,
              onSelected: _setMode,
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: ReadingMode.pagedH,
                  child: Text(l10n.modePagedH),
                ),
                PopupMenuItem(
                  value: ReadingMode.pagedV,
                  child: Text(l10n.modePagedV),
                ),
                PopupMenuItem(
                  value: ReadingMode.continuousV,
                  child: Text(l10n.modeContinuousV),
                ),
              ],
            ),
          ],
        ),
        body: _error != null
            ? Center(child: Text('$_error'))
            : _db == null
                ? const Center(child: CircularProgressIndicator())
                : Column(
                    children: [
                      if (_searchOpen) _searchBar(l10n),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _jumpCtrl,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  hintText: l10n.jumpToPrintPage,
                                  isDense: true,
                                  border: const OutlineInputBorder(),
                                ),
                                onSubmitted: (_) => _jumpToPrintPage(),
                              ),
                            ),
                            const SizedBox(width: 8),
                            FilledButton(
                              onPressed: _jumpToPrintPage,
                              child: Text(l10n.go),
                            ),
                          ],
                        ),
                      ),
                      if (_hits.isNotEmpty) _searchHits(l10n),
                      Expanded(
                        child: Row(
                          children: [
                            if (wide && _showToc)
                              SizedBox(
                                width: 280,
                                child: _sideIndexPane(l10n),
                              ),
                            if (wide && _showToc) const VerticalDivider(width: 1),
                            Expanded(child: _bodyPane(title)),
                            if (wide && _showCard) const VerticalDivider(width: 1),
                            if (wide && _showCard)
                              SizedBox(
                                width: 280,
                                child: _cardPane(l10n, title),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }

  Widget _searchBar(AppLocalizations l10n) {
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _searchCtrl,
                decoration: InputDecoration(
                  hintText: l10n.searchInBook,
                  isDense: true,
                  border: const OutlineInputBorder(),
                ),
                onSubmitted: (_) => _runSearch(),
              ),
            ),
            const SizedBox(width: 8),
            FilterChip(
              label: Text(l10n.exactPhrase),
              selected: _exactPhrase,
              onSelected: (v) => setState(() => _exactPhrase = v),
            ),
            IconButton(
              icon: const Icon(Icons.search),
              onPressed: _runSearch,
            ),
          ],
        ),
      ),
    );
  }

  Widget _searchHits(AppLocalizations l10n) {
    return SizedBox(
      height: 120,
      child: ListView.builder(
        itemCount: _hits.length,
        itemBuilder: (context, i) {
          final h = _hits[i];
          final snip = h.body.length > 120 ? '${h.body.substring(0, 120)}…' : h.body;
          return ListTile(
            dense: true,
            title: Text(
              'ص ${h.pageNumber ?? '—'}',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            subtitle: Text(snip, maxLines: 2, overflow: TextOverflow.ellipsis),
            onTap: () {
              _jumpToId(h.pageId);
            },
          );
        },
      ),
    );
  }

  Widget _sideIndexPane(AppLocalizations l10n) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          TabBar(
            tabs: [
              Tab(text: l10n.toc),
              Tab(text: l10n.notesTab),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _tocList(l10n),
                _notesList(l10n),
              ],
            ),
          ),
        ],
      ),
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
    return ListView.builder(
      itemCount: _toc.length,
      itemBuilder: (context, i) {
        final e = _toc[i];
        return ListTile(
          dense: true,
          selected: i == active,
          selectedTileColor:
              Theme.of(context).colorScheme.primaryContainer.withValues(
                    alpha: 0.45,
                  ),
          title: Text(e.title, maxLines: 2, overflow: TextOverflow.ellipsis),
          onTap: () => _jumpToId(e.pageId),
        );
      },
    );
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
    final category = _db?.meta('category_name') ?? '';
    final pages = _db?.meta('page_count') ?? '${_ids.length}';
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Text(l10n.bookCard, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Text(title, style: Theme.of(context).textTheme.titleSmall),
        if (author.isNotEmpty) Text(author),
        if (category.isNotEmpty) Text(category),
        Text(l10n.pagesCount(int.tryParse(pages) ?? _ids.length)),
        const Divider(),
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
    return PageView.builder(
      controller: _pageController,
      scrollDirection: vertical ? Axis.vertical : Axis.horizontal,
      reverse: !vertical,
      itemCount: _ids.length,
      onPageChanged: _onPage,
      itemBuilder: (context, i) => _pageContent(title, i),
    );
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
          const Divider(),
          Expanded(
            child: SingleChildScrollView(
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
                                if (mounted) {
                                  setState(() => _notesTick++);
                                }
                              },
                            )),
                  if (footnotes != null && footnotes.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    const Divider(),
                    Text(
                      l10n.footnotes,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    buildBodyDisplay(
                      footnotes,
                      style: TextStyle(
                        fontSize: (ref.watch(readerTextStylesProvider).fontSize) *
                            0.9,
                        height: 1.7,
                        fontFamily:
                            ref.watch(readerTextStylesProvider).font.familyName,
                      ),
                    ),
                  ],
                ],
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
    // Prefer HTML display when no overlaps complicate; fall back to plain spans.
    if (ranges.isEmpty) return buildBodyDisplay(body);
    final spans = <InlineSpan>[];
    var cursor = 0;
    final base = const TextStyle(fontSize: 20, height: 1.8);
    final hi = base.copyWith(
      backgroundColor: Colors.yellow.shade200,
    );
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
            child: _sideIndexPane(l10n),
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
