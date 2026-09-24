import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ishamela/l10n/app_localizations.dart';

import 'package:ishamela/core/auth/auth_state.dart';
import 'package:ishamela/core/author_line.dart';
import 'package:ishamela/core/models/models.dart';
import 'package:ishamela/core/providers.dart';
import 'package:ishamela/core/db/state_database.dart';
import 'package:ishamela/core/search/normalizer.dart';
import 'package:ishamela/features/catalog/author_page.dart';
import 'package:ishamela/features/catalog/catalog_service.dart';
import 'package:ishamela/features/downloads/download_service.dart';
import 'package:ishamela/features/downloads/downloads_page.dart';
import 'package:ishamela/features/library/history_page.dart';
import 'package:ishamela/features/library/library_search_service.dart';
import 'package:ishamela/features/library/library_sync_sheets.dart';
import 'package:ishamela/features/reader/export_sheet.dart';
import 'package:ishamela/features/reader/reader_page.dart';
import 'package:ishamela/ui/app_search_field.dart';
import 'package:ishamela/ui/book_card.dart';
import 'package:ishamela/ui/book_spine.dart';
import 'package:ishamela/ui/empty_state.dart';
import 'package:ishamela/ui/highlighted_text.dart';
import 'package:ishamela/ui/meta_chip.dart';
import 'package:ishamela/ui/segmented_pills.dart';
import 'package:ishamela/ui/theme/ishamela_theme.dart';
import 'package:ishamela/ui/theme/ishamela_tokens.dart';

/// Library browse (SPEC-013) — lazy: only the active tab is built and loaded;
/// catalog queries are batched (no per-row SQLite opens).
class LibraryPage extends ConsumerStatefulWidget {
  const LibraryPage({super.key});

  @override
  ConsumerState<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends ConsumerState<LibraryPage>
    with SingleTickerProviderStateMixin {
  DownloadService? _svc;
  late final TabController _tabs;
  final _searchCtrl = TextEditingController();
  String _query = '';
  Timer? _searchDebounce;
  Category? _categoryFilter;
  Author? _authorFilter;
  bool _selecting = false;
  final Set<int> _selected = {};
  OverlayEntry? _hoverOverlay;

  int _loadGen = 0;

  List<({Category category, int count})>? _categories;
  List<({Author author, int count})>? _authors;
  List<Book>? _allBooks;
  List<Book>? _drillBooks;
  bool _loading = false;

  /// 0 = titles (default), 1 = full text (SPEC-017).
  int _searchScope = 0;
  bool _exactPhrase = false;
  CancellationToken? _textSearchToken;
  StreamSubscription<LibraryTextSearchGroup>? _textSearchSub;
  final List<LibraryTextSearchGroup> _textGroups = [];
  int _textSearchDone = 0;
  int _textSearchTotal = 0;
  bool _textSearching = false;
  bool _textSearchFailed = false;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _tabs.addListener(_onTabChanged);
  }

  void _cancelTextSearch() {
    _textSearchToken?.cancel();
    _textSearchToken = null;
    _textSearchSub?.cancel();
    _textSearchSub = null;
  }

  void _onTabChanged() {
    if (_tabs.indexIsChanging) return;
    _cancelTextSearch();
    setState(() {
      _categoryFilter = null;
      _authorFilter = null;
      _drillBooks = null;
      _query = '';
      _searchCtrl.clear();
      _searchScope = 0;
      _selecting = false;
      _selected.clear();
      _textGroups.clear();
      _textSearching = false;
      _textSearchFailed = false;
    });
    _removeHover();
    _scheduleLoad();
  }

  @override
  void dispose() {
    _cancelTextSearch();
    _searchDebounce?.cancel();
    _svc?.removeListener(_onDownloadsChanged);
    _tabs.removeListener(_onTabChanged);
    _removeHover();
    _tabs.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onDownloadsChanged() {
    _categories = null;
    _authors = null;
    _allBooks = null;
    _drillBooks = null;
    if (mounted) {
      setState(() {});
      _scheduleLoad();
    }
  }

  void _removeHover() {
    _hoverOverlay?.remove();
    _hoverOverlay = null;
  }

  void _onSearchChanged(String v) {
    _searchDebounce?.cancel();
    final delay = _searchScope == 1
        ? const Duration(milliseconds: 300)
        : const Duration(milliseconds: 200);
    _searchDebounce = Timer(delay, () {
      if (!mounted) return;
      final cleared = v.trim().isEmpty;
      setState(() {
        _query = v;
        if (cleared) _searchScope = 0;
      });
      if (_searchScope == 1) {
        _startTextSearch();
      } else {
        _cancelTextSearch();
        setState(() {
          _textGroups.clear();
          _textSearching = false;
        });
      }
    });
  }

  void _startTextSearch() {
    _cancelTextSearch();
    final q = normalize(_query.trim());
    if (q.length < 2) {
      setState(() {
        _textGroups.clear();
        _textSearching = false;
        _textSearchFailed = false;
      });
      return;
    }
    final paths = ref.read(appPathsProvider).maybeWhen(
          data: (p) => p,
          orElse: () => null,
        );
    final state = ref.read(stateDatabaseProvider).maybeWhen(
          data: (s) => s,
          orElse: () => null,
        );
    final catalog = ref.read(catalogRepositoryProvider).maybeWhen(
          data: (c) => c,
          orElse: () => null,
        );
    if (paths == null || state == null || catalog == null) return;

    final token = CancellationToken();
    _textSearchToken = token;
    final svc = LibrarySearchService(
      paths: paths,
      state: state,
      catalog: catalog,
    );
    final ordered = svc.orderedInstalledBookIds();
    setState(() {
      _textGroups.clear();
      _textSearching = true;
      _textSearchFailed = false;
      _textSearchDone = 0;
      _textSearchTotal = ordered.length;
    });

    final seen = <int>{};
    _textSearchSub = svc
        .search(query: _query, exactPhrase: _exactPhrase, token: token)
        .listen(
      (g) {
        if (!mounted || token.isCancelled) return;
        setState(() {
          _textGroups.removeWhere((x) => x.bookId == g.bookId);
          _textGroups.add(g);
          seen.add(g.bookId);
          _textSearchDone = seen.length;
        });
      },
      onError: (_) {
        if (!mounted || token.isCancelled) return;
        setState(() {
          _textSearching = false;
          _textSearchFailed = true;
        });
      },
      onDone: () {
        if (!mounted || token.isCancelled) return;
        setState(() {
          _textSearching = false;
          _textSearchDone = _textSearchTotal;
          // Re-sort to LS-11 order
          final order = {
            for (var i = 0; i < ordered.length; i++) ordered[i]: i,
          };
          _textGroups.sort(
            (a, b) => (order[a.bookId] ?? 0).compareTo(order[b.bookId] ?? 0),
          );
        });
      },
    );
  }

  void _scheduleLoad() {
    final catalog = ref.read(catalogRepositoryProvider).maybeWhen(
          data: (c) => c,
          orElse: () => null,
        );
    final state = ref.read(stateDatabaseProvider).maybeWhen(
          data: (s) => s,
          orElse: () => null,
        );
    if (catalog == null || state == null) return;
    unawaited(_loadActive(catalog, state.installedBookIds().toSet()));
  }

  Future<void> _loadActive(CatalogRepository catalog, Set<int> ids) async {
    final gen = ++_loadGen;
    if (!mounted) return;
    setState(() => _loading = true);

    // Yield so the first frame (spinner / empty shell) paints before SQL.
    await Future<void>.delayed(Duration.zero);
    if (!mounted || gen != _loadGen) return;

    try {
      if (_tabs.index == 0 && _categoryFilter != null) {
        final books =
            catalog.installedBooksByCategory(_categoryFilter!.id, ids);
        if (!mounted || gen != _loadGen) return;
        setState(() {
          _drillBooks = books;
          _loading = false;
        });
        return;
      }
      if (_tabs.index == 1 && _authorFilter != null) {
        final books = catalog.installedBooksByAuthor(_authorFilter!.id, ids);
        if (!mounted || gen != _loadGen) return;
        setState(() {
          _drillBooks = books;
          _loading = false;
        });
        return;
      }

      switch (_tabs.index) {
        case 1:
          if (_authors == null) {
            final authors = catalog.authorsForInstalled(ids);
            if (!mounted || gen != _loadGen) return;
            setState(() {
              _authors = authors;
              _loading = false;
            });
          } else if (mounted && gen == _loadGen) {
            setState(() => _loading = false);
          }
        case 2:
          if (_allBooks == null) {
            final books = catalog.booksByIds(ids);
            if (!mounted || gen != _loadGen) return;
            setState(() {
              _allBooks = books;
              _loading = false;
            });
          } else if (mounted && gen == _loadGen) {
            setState(() => _loading = false);
          }
        default:
          if (_categories == null) {
            final cats = catalog.categoriesForInstalled(ids);
            if (!mounted || gen != _loadGen) return;
            setState(() {
              _categories = cats;
              _loading = false;
            });
          } else if (mounted && gen == _loadGen) {
            setState(() => _loading = false);
          }
      }
    } catch (_) {
      if (mounted && gen == _loadGen) {
        setState(() => _loading = false);
      }
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final stateAsync = ref.watch(stateDatabaseProvider);
    final catalogAsync = ref.watch(catalogRepositoryProvider);
    final downloadsAsync = ref.watch(downloadServiceProvider);
    ref.watch(downloadRevisionProvider);

    ref.listen(downloadServiceProvider, (prev, next) {
      next.whenData((svc) {
        if (_svc != svc) {
          _svc?.removeListener(_onDownloadsChanged);
          _svc = svc;
          _svc!.addListener(_onDownloadsChanged);
        }
      });
    });

    ref.listen(stateDatabaseProvider, (prev, next) {
      next.whenData((_) {
        _categories = null;
        _authors = null;
        _allBooks = null;
        _drillBooks = null;
        _scheduleLoad();
      });
    });

    ref.listen(catalogRepositoryProvider, (prev, next) {
      next.whenData((_) => _scheduleLoad());
    });

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: stateAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('$e')),
          data: (state) {
            final ids = state.installedBookIds().toSet();
            if (ids.isEmpty) {
              return EmptyState(
                message: l10n.libraryEmptyHint,
                actionLabel: l10n.browseCatalog,
                onAction: () =>
                    ref.read(homeTabIndexProvider.notifier).go(HomeTabs.catalog),
              );
            }
            return catalogAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('$e')),
              data: (catalog) {
                if (_categories == null &&
                    _authors == null &&
                    _allBooks == null &&
                    !_loading) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) unawaited(_loadActive(catalog, ids));
                  });
                }
                final t = IshamelaTokens.of(context);
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  l10n.tabLibrary,
                                  style: TextStyle(
                                    fontFamily: kFontAmiri,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 26,
                                    color: t.ink,
                                  ),
                                ),
                              ),
                              if (!_selecting)
                                IconButton(
                                  tooltip: l10n.tabDownloads,
                                  icon: const Icon(Icons.download_outlined),
                                  onPressed: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute<void>(
                                        builder: (_) => const DownloadsPage(),
                                      ),
                                    );
                                  },
                                ),
                              if (_selecting) ...[
                                IconButton(
                                  tooltip: l10n.selectAll,
                                  icon: const Icon(Icons.select_all),
                                  onPressed: () {
                                    final books = _currentBooks();
                                    setState(() {
                                      _selected
                                        ..clear()
                                        ..addAll(books.map((b) => b.bookId));
                                    });
                                  },
                                ),
                                IconButton(
                                  tooltip: l10n.delete,
                                  icon: const Icon(Icons.delete_outline),
                                  onPressed: _selected.isEmpty
                                      ? null
                                      : () =>
                                          _bulkDelete(downloadsAsync),
                                ),
                                IconButton(
                                  tooltip: l10n.cancel,
                                  icon: const Icon(Icons.close),
                                  onPressed: () => setState(() {
                                    _selecting = false;
                                    _selected.clear();
                                  }),
                                ),
                              ] else if (_showingBooksList)
                                IconButton(
                                  tooltip: l10n.select,
                                  icon: const Icon(Icons.checklist),
                                  onPressed: () =>
                                      setState(() => _selecting = true),
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _ContinueReadingHero(state: state, catalog: catalog),
                          const SizedBox(height: 12),
                          AppSearchField(
                            key: ValueKey('lib-search-${_tabs.index}'),
                            hintText: l10n.searchHint,
                            initialQuery: _query,
                            onChanged: _onSearchChanged,
                          ),
                          if (_query.trim().isNotEmpty) ...[
                            const SizedBox(height: 8),
                            SegmentedPills(
                              labels: [
                                l10n.searchScopeTitles,
                                l10n.searchScopeTexts,
                              ],
                              selectedIndex: _searchScope,
                              onChanged: (i) {
                                _cancelTextSearch();
                                setState(() {
                                  _searchScope = i;
                                  _textGroups.clear();
                                });
                                if (i == 1) _startTextSearch();
                              },
                            ),
                            if (_searchScope == 1) ...[
                              const SizedBox(height: 8),
                              Align(
                                alignment: AlignmentDirectional.centerStart,
                                child: FilterChip(
                                  label: Text(l10n.exactPhrase),
                                  selected: _exactPhrase,
                                  onSelected: (v) {
                                    setState(() => _exactPhrase = v);
                                    _startTextSearch();
                                  },
                                ),
                              ),
                              if (_textSearching)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      LinearProgressIndicator(
                                        value: _textSearchTotal == 0
                                            ? null
                                            : (_textSearchDone /
                                                    _textSearchTotal)
                                                .clamp(0.0, 1.0),
                                        minHeight: 3,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        l10n.searchingBooksProgress(
                                          _textSearchDone,
                                          _textSearchTotal,
                                        ),
                                        style: TextStyle(
                                          fontFamily: kFontUi,
                                          fontSize: 11,
                                          color: t.muted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ],
                          if (_searchScope != 1) ...[
                            const SizedBox(height: 12),
                            SegmentedPills(
                              labels: [
                                l10n.categories,
                                l10n.authors,
                                l10n.libraryAllBooks,
                              ],
                              selectedIndex: _tabs.index,
                              onChanged: (i) {
                                if (_tabs.index != i) _tabs.animateTo(i);
                              },
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (_needsBack && _searchScope != 1)
                      ListTile(
                        leading: const Icon(Icons.arrow_forward),
                        title: Text(l10n.back),
                        onTap: () {
                          setState(() {
                            _categoryFilter = null;
                            _authorFilter = null;
                            _drillBooks = null;
                            _selecting = false;
                            _selected.clear();
                          });
                          _scheduleLoad();
                        },
                      ),
                    Expanded(
                      child: AnimatedBuilder(
                        animation: _tabs,
                        builder: (context, _) {
                          if (_searchScope == 1 &&
                              _query.trim().isNotEmpty) {
                            return _textSearchResults(l10n, t);
                          }
                          if (_loading && !_hasDataForActive) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }
                          return _buildActiveTab(l10n, downloadsAsync);
                        },
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _textSearchResults(AppLocalizations l10n, IshamelaTokens t) {
    final q = normalize(_query.trim());
    if (q.length < 2) {
      return Center(
        child: Text(
          l10n.minQueryHint,
          style: TextStyle(fontFamily: kFontUi, color: t.muted),
        ),
      );
    }
    if (_textSearchFailed) {
      return EmptyState(
        message: l10n.searchFailedRetry,
        actionLabel: l10n.searchFailedRetry,
        onAction: _startTextSearch,
      );
    }
    if (!_textSearching && _textGroups.isEmpty) {
      return EmptyState(
        message: l10n.libSearchEmpty,
        actionLabel: l10n.tryCatalogSearch,
        onAction: () {
          ref.read(catalogPendingQueryProvider.notifier).set(_query);
          ref.read(homeTabIndexProvider.notifier).go(HomeTabs.catalog);
        },
      );
    }
    final reduce = MediaQuery.disableAnimationsOf(context);
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      itemCount: _textGroups.length,
      itemBuilder: (context, i) {
        final g = _textGroups[i];
        final countLabel = g.capped
            ? l10n.hitsCapped(g.totalHits > 50 ? 50 : g.totalHits)
            : '${g.totalHits}';
        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: reduce
              ? Duration.zero
              : const Duration(milliseconds: 120),
          builder: (context, opacity, child) =>
              Opacity(opacity: opacity, child: child),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    BookSpine(
                      title: g.title,
                      categoryId: g.categoryId,
                      width: 32,
                      height: 46,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        g.title,
                        style: TextStyle(
                          fontFamily: kFontAmiri,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          color: t.ink,
                        ),
                      ),
                    ),
                    MetaChip(label: countLabel),
                  ],
                ),
                const SizedBox(height: 8),
                for (final hit in g.hits)
                  InkWell(
                    onTap: () => ReaderPage.open(
                      context,
                      bookId: g.bookId,
                      title: g.title,
                      initialPageId: hit.pageId,
                      initialSearchQuery: _query,
                      exactPhrase: _exactPhrase,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: t.goldSoft.withValues(alpha: 0.45),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              'ص ${hit.pageNumber?.toString() ?? '—'}',
                              style: TextStyle(
                                fontFamily: kFontUi,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                                color: t.ink,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: HighlightedText(
                              text: hit.snippet,
                              query: _query,
                              maxLines: 1,
                              style: TextStyle(
                                fontFamily: kFontAmiri,
                                fontSize: 14,
                                height: 1.4,
                                color: t.ink,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (g.capped)
                  TextButton(
                    onPressed: () => ReaderPage.open(
                      context,
                      bookId: g.bookId,
                      title: g.title,
                      initialSearchQuery: _query,
                      exactPhrase: _exactPhrase,
                    ),
                    child: Text(l10n.moreHitsInBook),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  bool get _needsBack =>
      (_tabs.index == 0 && _categoryFilter != null) ||
      (_tabs.index == 1 && _authorFilter != null);

  bool get _showingBooksList =>
      _tabs.index == 2 ||
      _categoryFilter != null ||
      _authorFilter != null;

  bool get _hasDataForActive {
    if (_tabs.index == 0 && _categoryFilter != null) {
      return _drillBooks != null;
    }
    if (_tabs.index == 1 && _authorFilter != null) {
      return _drillBooks != null;
    }
    switch (_tabs.index) {
      case 1:
        return _authors != null;
      case 2:
        return _allBooks != null;
      default:
        return _categories != null;
    }
  }

  List<Book> _currentBooks() {
    if (_categoryFilter != null || _authorFilter != null) {
      return _filterBooks(_drillBooks ?? const []);
    }
    return _filterBooks(_allBooks ?? const []);
  }

  List<Book> _filterBooks(List<Book> books) {
    final q = normalize(_query.trim());
    if (q.isEmpty) return books;
    return books.where((b) {
      final hay = normalize(
        '${b.title} ${b.authorName ?? ''} ${b.categoryName ?? ''}',
      );
      return hay.contains(q);
    }).toList();
  }

  Widget _buildActiveTab(
    AppLocalizations l10n,
    AsyncValue<DownloadService> downloadsAsync,
  ) {
    switch (_tabs.index) {
      case 1:
        return _authorsView(l10n, downloadsAsync);
      case 2:
        return _booksList(
          l10n,
          _filterBooks(_allBooks ?? const []),
          downloadsAsync,
        );
      default:
        return _categoriesView(l10n, downloadsAsync);
    }
  }

  Widget _categoriesView(
    AppLocalizations l10n,
    AsyncValue<DownloadService> downloadsAsync,
  ) {
    if (_categoryFilter != null) {
      return _booksList(
        l10n,
        _filterBooks(_drillBooks ?? const []),
        downloadsAsync,
      );
    }
    final cats = _categories ?? const [];
    final q = normalize(_query.trim());
    final filtered = q.isEmpty
        ? cats
        : cats
            .where((e) => normalize(e.category.name).contains(q))
            .toList();
    if (filtered.isEmpty) {
      return EmptyState(message: l10n.noBooks);
    }
    final t = IshamelaTokens.of(context);
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      itemCount: filtered.length,
      itemBuilder: (context, i) {
        final e = filtered[i];
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Material(
            color: t.card,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: t.hairline),
            ),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: t.green100,
                child: Icon(Icons.folder_outlined, color: t.emphasis),
              ),
              title: Text(
                e.category.name,
                style: const TextStyle(
                  fontFamily: kFontAmiri,
                  fontWeight: FontWeight.w700,
                ),
              ),
              trailing: Text('${e.count}', style: TextStyle(color: t.muted)),
              onTap: () {
                setState(() {
                  _categoryFilter = e.category;
                  _drillBooks = null;
                  _selecting = false;
                  _selected.clear();
                });
                _scheduleLoad();
              },
            ),
          ),
        );
      },
    );
  }

  Widget _authorsView(
    AppLocalizations l10n,
    AsyncValue<DownloadService> downloadsAsync,
  ) {
    if (_authorFilter != null) {
      return _booksList(
        l10n,
        _filterBooks(_drillBooks ?? const []),
        downloadsAsync,
      );
    }
    final authors = _authors ?? const [];
    final q = normalize(_query.trim());
    final filtered = q.isEmpty
        ? authors
        : authors
            .where((e) => normalize(e.author.name).contains(q))
            .toList();
    if (filtered.isEmpty) {
      return EmptyState(message: l10n.noBooks);
    }
    final t = IshamelaTokens.of(context);
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      itemCount: filtered.length,
      itemBuilder: (context, i) {
        final e = filtered[i];
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Material(
            color: t.card,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: t.hairline),
            ),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: t.green100,
                child: Icon(Icons.person_outline, color: t.emphasis),
              ),
              title: Text(
                e.author.name,
                style: const TextStyle(
                  fontFamily: kFontAmiri,
                  fontWeight: FontWeight.w700,
                ),
              ),
              trailing: Text('${e.count}', style: TextStyle(color: t.muted)),
              onTap: () => AuthorPage.open(
                context,
                authorId: e.author.id,
                author: e.author,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _booksList(
    AppLocalizations l10n,
    List<Book> books,
    AsyncValue<DownloadService> downloadsAsync,
  ) {
    if (books.isEmpty) {
      return EmptyState(message: l10n.noBooks);
    }
    final state = ref.read(stateDatabaseProvider).maybeWhen(
          data: (s) => s,
          orElse: () => null,
        );
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      itemCount: books.length,
      itemBuilder: (context, i) {
        final book = books[i];
        final pageId = state?.readingPageId(book.bookId);
        final total = book.pageCount > 0
            ? book.pageCount
            : (state?.installedPageCount(book.bookId) ?? 0);
        double? progress;
        if (pageId != null && total > 0) {
          // page_id is internal; approximate progress by order index if possible
          progress = null;
          final allIds = _cachedPageProgress(book.bookId, pageId, total);
          progress = allIds;
        }
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: MouseRegion(
            onEnter: (e) => _showHoverCard(context, book, e.position),
            onExit: (_) => _removeHover(),
            child: BookCard(
              title: book.title,
              categoryId: book.categoryId,
              author: formatAuthorLine(
                book.authorName,
                book.authorDeathYearHijri,
              ),
              onAuthorTap: book.authorId == null
                  ? null
                  : () {
                      _removeHover();
                      AuthorPage.open(
                        context,
                        authorId: book.authorId!,
                        author: Author(
                          id: book.authorId!,
                          name: book.authorName ?? '',
                          deathYearHijri: book.authorDeathYearHijri,
                        ),
                      );
                    },
              meta: [
                if (book.volumeCount != null && book.volumeCount! > 0)
                  l10n.volumesCount(book.volumeCount!),
                if (book.categoryName != null && book.categoryName!.isNotEmpty)
                  book.categoryName!,
                if (total > 0) l10n.pagesCount(total),
              ],
              progress: progress,
              selected: _selecting ? _selected.contains(book.bookId) : null,
              onSelectedChanged: _selecting
                  ? (_) => setState(() {
                        if (_selected.contains(book.bookId)) {
                          _selected.remove(book.bookId);
                        } else {
                          _selected.add(book.bookId);
                        }
                      })
                  : null,
              onTap: () {
                _removeHover();
                ReaderPage.open(
                  context,
                  bookId: book.bookId,
                  title: book.title,
                  authorName: book.authorName,
                  authorId: book.authorId,
                );
              },
              onLongPress: () => setState(() {
                _selecting = true;
                _selected.add(book.bookId);
              }),
              trailing: PopupMenuButton<String>(
                tooltip: l10n.bookCard,
                onSelected: (v) async {
                  if (v == 'card') {
                    await _showCardSheet(context, l10n, book);
                  } else if (v == 'export') {
                    await showAnnotationsExportSheet(
                      context,
                      bookId: book.bookId,
                      title: book.title,
                      authorName: book.authorName,
                    );
                  } else if (v == 'delete') {
                    final svc = downloadsAsync.maybeWhen(
                      data: (s) => s,
                      orElse: () => null,
                    );
                    final db = ref.read(stateDatabaseProvider).maybeWhen(
                          data: (s) => s,
                          orElse: () => null,
                        );
                    final signedIn = ref.read(authProvider).isVerified;
                    final choice = await showBookRemovalSheet(
                      context,
                      signedIn: signedIn,
                    );
                    if (choice != null && svc != null && db != null) {
                      await applyBookRemoval(
                        choice: choice,
                        signedIn: signedIn,
                        bookId: book.bookId,
                        title: book.title,
                        sizeBytes: book.sqliteBytes,
                        catalogVersion: 0,
                        state: db,
                        downloads: svc,
                        pushRemoved: (docs) =>
                            ref.read(authProvider.notifier).pushLibrary(docs),
                      );
                    }
                    _categories = null;
                    _authors = null;
                    _allBooks = null;
                    _drillBooks = null;
                    if (mounted) {
                      setState(() {});
                      _scheduleLoad();
                    }
                  }
                },
                itemBuilder: (_) {
                  final count =
                      state?.annotationCountForBook(book.bookId) ?? 0;
                  return [
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
                    PopupMenuItem(
                      value: 'delete',
                      child: Text(
                        l10n.delete,
                        style: const TextStyle(color: Color(0xFFA6402E)),
                      ),
                    ),
                  ];
                },
              ),
            ),
          ),
        );
      },
    );
  }

  /// Rough progress: page_id / page_count when ids align; else null.
  double? _cachedPageProgress(int bookId, int pageId, int total) {
    if (total <= 0) return null;
    return (pageId / total).clamp(0.0, 1.0);
  }

  Future<void> _bulkDelete(
    AsyncValue<DownloadService> downloadsAsync,
  ) async {
    final signedIn = ref.read(authProvider).isVerified;
    final choice = await showBookRemovalSheet(context, signedIn: signedIn);
    if (choice == null) return;
    final svc = downloadsAsync.maybeWhen(
      data: (s) => s,
      orElse: () => null,
    );
    final db = ref.read(stateDatabaseProvider).maybeWhen(
          data: (s) => s,
          orElse: () => null,
        );
    if (svc == null || db == null) return;
    for (final id in _selected.toList()) {
      await applyBookRemoval(
        choice: choice,
        signedIn: signedIn,
        bookId: id,
        title: '',
        sizeBytes: 0,
        catalogVersion: 0,
        state: db,
        downloads: svc,
        pushRemoved: (docs) => ref.read(authProvider.notifier).pushLibrary(docs),
      );
    }
    _categories = null;
    _authors = null;
    _allBooks = null;
    _drillBooks = null;
    setState(() {
      _selected.clear();
      _selecting = false;
    });
    _scheduleLoad();
  }

  void _showHoverCard(BuildContext context, Book book, Offset globalPos) {
    _removeHover();
    final overlay = Overlay.of(context);
    final size = MediaQuery.sizeOf(context);
    final left = (globalPos.dx + 16).clamp(8.0, size.width - 320);
    final top = (globalPos.dy + 16).clamp(8.0, size.height - 220);
    _hoverOverlay = OverlayEntry(
      builder: (ctx) => Positioned(
        left: left,
        top: top,
        width: 300,
        child: Material(
          elevation: 6,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: _cardContent(AppLocalizations.of(context), book),
          ),
        ),
      ),
    );
    overlay.insert(_hoverOverlay!);
  }

  Future<void> _showCardSheet(
    BuildContext context,
    AppLocalizations l10n,
    Book book,
  ) {
    final t = IshamelaTokens.of(context);
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: t.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  BookSpine(title: book.title, categoryId: book.categoryId),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      l10n.bookCard,
                      style: TextStyle(
                        fontFamily: kFontAmiri,
                        fontWeight: FontWeight.w700,
                        fontSize: 20,
                        color: t.ink,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _cardContent(l10n, book),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  appNavigatorKey.currentState?.push(
                    MaterialPageRoute<void>(
                      builder: (_) => ReaderPage(
                        bookId: book.bookId,
                        title: book.title,
                        authorName: book.authorName,
                      ),
                    ),
                  );
                },
                child: Text(l10n.openBook),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _cardContent(AppLocalizations l10n, Book book) {
    var betaka = book.betakaText?.trim() ?? '';
    if (betaka.length > 400) {
      betaka = '${betaka.substring(0, 399)}…';
    }
    final pages = book.pageCount > 0 ? l10n.pagesCount(book.pageCount) : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(book.title, style: const TextStyle(fontWeight: FontWeight.bold)),
        if (book.authorName != null && book.authorName!.isNotEmpty)
          Text(book.authorName!),
        if (book.categoryName != null && book.categoryName!.isNotEmpty)
          Text(book.categoryName!),
        if (pages != null) Text(pages),
        if (betaka.isNotEmpty) ...[
          const Divider(),
          Text(betaka, style: const TextStyle(height: 1.5)),
        ],
      ],
    );
  }
}

class _ContinueReadingHero extends StatelessWidget {
  const _ContinueReadingHero({required this.state, required this.catalog});

  final StateDatabase state;
  final CatalogRepository catalog;

  @override
  Widget build(BuildContext context) {
    final latest = state.latestReadingHistory();
    if (latest == null) {
      return const SizedBox.shrink();
    }
    final book = catalog.bookById(latest.bookId);
    if (book == null) return const SizedBox.shrink();
    final installed = state.isInstalled(latest.bookId);
    final l10n = AppLocalizations.of(context);
    final t = IshamelaTokens.of(context);
    final total = book.pageCount > 0
        ? book.pageCount
        : (state.installedPageCount(book.bookId) ?? 0);
    final progress =
        total > 0 ? (latest.pageId / total).clamp(0.0, 1.0) : 0.0;

    return Material(
      color: t.green900,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        l10n.continueReading,
                        style: TextStyle(
                          fontFamily: kFontUi,
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                          color: t.goldSoft,
                        ),
                      ),
                      Text(
                        ' · ',
                        style: TextStyle(
                          fontFamily: kFontUi,
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                          color: t.goldSoft,
                        ),
                      ),
                      InkWell(
                        onTap: () => HistoryPage.open(context),
                        child: Text(
                          '${l10n.historyLink} ←',
                          style: TextStyle(
                            fontFamily: kFontUi,
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                            color: t.goldSoft,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  InkWell(
                    onTap: installed
                        ? () => ReaderPage.open(
                              context,
                              bookId: book.bookId,
                              title: book.title,
                              authorName: book.authorName,
                              initialPageId: latest.pageId,
                              initialPrintPage: latest.printPage,
                            )
                        : null,
                    child: Text(
                      book.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: kFontAmiri,
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  if (total > 0 && installed) ...[
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: progress),
                        duration: const Duration(milliseconds: 400),
                        curve: Curves.easeOutCubic,
                        builder: (context, v, _) => LinearProgressIndicator(
                          value: v,
                          minHeight: 4,
                          backgroundColor: Colors.white24,
                          color: t.goldSoft,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            if (installed)
              InkWell(
                onTap: () => ReaderPage.open(
                  context,
                  bookId: book.bookId,
                  title: book.title,
                  authorName: book.authorName,
                  initialPageId: latest.pageId,
                  initialPrintPage: latest.printPage,
                ),
                child: CircleAvatar(
                  backgroundColor: t.gold,
                  child: const Icon(Icons.play_arrow, color: Colors.white),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
