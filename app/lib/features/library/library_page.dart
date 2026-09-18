import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ishamela/l10n/app_localizations.dart';

import 'package:ishamela/core/models/models.dart';
import 'package:ishamela/core/providers.dart';
import 'package:ishamela/core/search/normalizer.dart';
import 'package:ishamela/features/catalog/catalog_service.dart';
import 'package:ishamela/features/downloads/download_service.dart';
import 'package:ishamela/features/reader/reader_page.dart';

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

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _tabs.addListener(_onTabChanged);
  }

  void _onTabChanged() {
    if (_tabs.indexIsChanging) return;
    setState(() {
      _categoryFilter = null;
      _authorFilter = null;
      _drillBooks = null;
      _query = '';
      _searchCtrl.clear();
      _selecting = false;
      _selected.clear();
    });
    _removeHover();
    _scheduleLoad();
  }

  @override
  void dispose() {
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
    _searchDebounce = Timer(const Duration(milliseconds: 200), () {
      if (!mounted) return;
      setState(() => _query = v);
    });
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
        appBar: AppBar(
          title: Text(l10n.tabLibrary),
          bottom: TabBar(
            controller: _tabs,
            tabs: [
              Tab(text: l10n.categories),
              Tab(text: l10n.authors),
              Tab(text: l10n.libraryAllBooks),
            ],
          ),
          actions: [
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
                tooltip: l10n.deselectAll,
                icon: const Icon(Icons.deselect),
                onPressed: () => setState(() => _selected.clear()),
              ),
              IconButton(
                tooltip: l10n.delete,
                icon: const Icon(Icons.delete_outline),
                onPressed: _selected.isEmpty
                    ? null
                    : () => _bulkDelete(l10n, downloadsAsync),
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
                onPressed: () => setState(() => _selecting = true),
              ),
          ],
        ),
        body: stateAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('$e')),
          data: (state) {
            final ids = state.installedBookIds().toSet();
            if (ids.isEmpty) {
              return Center(child: Text(l10n.noBooks));
            }
            return catalogAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('$e')),
              data: (catalog) {
                // Kick off first load once providers are ready.
                if (_categories == null &&
                    _authors == null &&
                    _allBooks == null &&
                    !_loading) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) unawaited(_loadActive(catalog, ids));
                  });
                }
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                      child: TextField(
                        controller: _searchCtrl,
                        decoration: InputDecoration(
                          hintText: l10n.searchHint,
                          prefixIcon: const Icon(Icons.search),
                          border: const OutlineInputBorder(),
                          isDense: true,
                        ),
                        onChanged: _onSearchChanged,
                      ),
                    ),
                    if (_needsBack)
                      ListTile(
                        leading: const Icon(Icons.arrow_back),
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
      return Center(child: Text(l10n.noBooks));
    }
    return ListView.builder(
      itemCount: filtered.length,
      itemBuilder: (context, i) {
        final e = filtered[i];
        return ListTile(
          title: Text(e.category.name),
          trailing: Text('${e.count}'),
          onTap: () {
            setState(() {
              _categoryFilter = e.category;
              _drillBooks = null;
              _selecting = false;
              _selected.clear();
            });
            _scheduleLoad();
          },
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
      return Center(child: Text(l10n.noBooks));
    }
    return ListView.builder(
      itemCount: filtered.length,
      itemBuilder: (context, i) {
        final e = filtered[i];
        return ListTile(
          title: Text(e.author.name),
          trailing: Text('${e.count}'),
          onTap: () {
            setState(() {
              _authorFilter = e.author;
              _drillBooks = null;
              _selecting = false;
              _selected.clear();
            });
            _scheduleLoad();
          },
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
      return Center(child: Text(l10n.noBooks));
    }
    return ListView.builder(
      itemCount: books.length,
      itemBuilder: (context, i) {
        final book = books[i];
        if (_selecting) {
          return CheckboxListTile(
            value: _selected.contains(book.bookId),
            onChanged: (_) => setState(() {
              if (_selected.contains(book.bookId)) {
                _selected.remove(book.bookId);
              } else {
                _selected.add(book.bookId);
              }
            }),
            title: Text(book.title),
            subtitle: Text(book.authorName ?? ''),
          );
        }
        return MouseRegion(
          onEnter: (e) => _showHoverCard(context, book, e.position),
          onExit: (_) => _removeHover(),
          child: ListTile(
            title: Text(book.title),
            subtitle: Text(
              [
                if (book.authorName != null && book.authorName!.isNotEmpty)
                  book.authorName!,
                if (book.categoryName != null &&
                    book.categoryName!.isNotEmpty)
                  book.categoryName!,
              ].join(' · '),
            ),
            onTap: () {
              _removeHover();
              ReaderPage.open(
                context,
                bookId: book.bookId,
                title: book.title,
                authorName: book.authorName,
              );
            },
            onLongPress: () => _showCardDialog(context, l10n, book),
            trailing: IconButton(
              tooltip: l10n.delete,
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                final svc = downloadsAsync.maybeWhen(
                  data: (s) => s,
                  orElse: () => null,
                );
                await svc?.deleteInstalled(book.bookId);
                _categories = null;
                _authors = null;
                _allBooks = null;
                _drillBooks = null;
                if (mounted) {
                  setState(() {});
                  _scheduleLoad();
                }
              },
            ),
          ),
        );
      },
    );
  }

  Future<void> _bulkDelete(
    AppLocalizations l10n,
    AsyncValue<DownloadService> downloadsAsync,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.delete),
        content: Text(l10n.confirmBulkDelete),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.confirm),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final svc = downloadsAsync.maybeWhen(
      data: (s) => s,
      orElse: () => null,
    );
    await svc?.deleteInstalledMany(_selected);
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

  Future<void> _showCardDialog(
    BuildContext context,
    AppLocalizations l10n,
    Book book,
  ) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.bookCard),
        content: SingleChildScrollView(child: _cardContent(l10n, book)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              ReaderPage.open(
                context,
                bookId: book.bookId,
                title: book.title,
                authorName: book.authorName,
              );
            },
            child: Text(l10n.openBook),
          ),
        ],
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
