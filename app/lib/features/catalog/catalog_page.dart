import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ishamela/l10n/app_localizations.dart';

import 'package:ishamela/core/format_bytes.dart';
import 'package:ishamela/core/models/models.dart';
import 'package:ishamela/core/providers.dart';
import 'package:ishamela/features/catalog/catalog_search_field.dart';
import 'package:ishamela/features/catalog/catalog_service.dart';
import 'package:ishamela/features/downloads/download_service.dart';
import 'package:ishamela/features/reader/reader_page.dart';

class CatalogPage extends ConsumerStatefulWidget {
  const CatalogPage({super.key});

  @override
  ConsumerState<CatalogPage> createState() => _CatalogPageState();
}

class _CatalogPageState extends ConsumerState<CatalogPage> {
  String _query = '';
  CatalogSearchScope _scope = CatalogSearchScope.all;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final catalogAsync = ref.watch(catalogRepositoryProvider);
    final syncTick = ref.watch(catalogSyncTickProvider);
    final stateAsync = ref.watch(stateDatabaseProvider);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.tabCatalog),
          actions: [
            IconButton(
              tooltip: l10n.refresh,
              onPressed: () {
                ref.invalidate(catalogSyncTickProvider);
                ref.invalidate(catalogRepositoryProvider);
              },
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: catalogAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('$e')),
          data: (catalog) {
            if (!catalog.hasCatalog) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(l10n.offlineEmpty, textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: () {
                          ref.invalidate(catalogSyncTickProvider);
                          ref.invalidate(catalogRepositoryProvider);
                        },
                        child: Text(l10n.refresh),
                      ),
                      syncTick.when(
                        data: (_) => const SizedBox.shrink(),
                        loading: () => const Padding(
                          padding: EdgeInsets.only(top: 16),
                          child: CircularProgressIndicator(),
                        ),
                        error: (_, __) => const SizedBox.shrink(),
                      ),
                    ],
                  ),
                ),
              );
            }

            // Stale hint: local catalog older than 30 days (SPEC-007 optional).
            final showStale = catalog.isCatalogStale();
            final bookCount = catalog.bookCount();
            final installedBytes = stateAsync.maybeWhen(
              data: (s) => s.installedSqliteBytesTotal,
              orElse: () => 0,
            );

            return Column(
              children: [
                if (showStale)
                  Material(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline, size: 18),
                          const SizedBox(width: 8),
                          Expanded(child: Text(l10n.catalogStaleHint)),
                        ],
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: CatalogSearchField(
                    hintText: l10n.searchHint,
                    initialQuery: _query,
                    onChanged: (v) => setState(() => _query = v),
                  ),
                ),
                if (_query.trim().isNotEmpty)
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        for (final s in CatalogSearchScope.values)
                          Padding(
                            padding: const EdgeInsetsDirectional.only(end: 8),
                            child: ChoiceChip(
                              label: Text(_scopeLabel(l10n, s)),
                              selected: _scope == s,
                              onSelected: (_) => setState(() => _scope = s),
                            ),
                          ),
                      ],
                    ),
                  ),
                Expanded(
                  child: _query.trim().isEmpty
                      ? _BrowseTabs(catalog: catalog)
                      : _SearchResults(
                          catalog: catalog,
                          query: _query,
                          scope: _scope,
                        ),
                ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                    child: Text(
                      l10n.catalogFooter(
                        bookCount,
                        formatBytes(installedBytes),
                      ),
                      style: Theme.of(context).textTheme.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  String _scopeLabel(AppLocalizations l10n, CatalogSearchScope s) {
    switch (s) {
      case CatalogSearchScope.all:
        return l10n.searchScopeAll;
      case CatalogSearchScope.books:
        return l10n.searchScopeBooks;
      case CatalogSearchScope.authors:
        return l10n.searchScopeAuthors;
      case CatalogSearchScope.categories:
        return l10n.searchScopeCategories;
    }
  }
}

class _BrowseTabs extends StatelessWidget {
  const _BrowseTabs({required this.catalog});
  final CatalogRepository catalog;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          TabBar(
            tabs: [
              Tab(text: l10n.categories),
              Tab(text: l10n.authors),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _CategoryList(catalog: catalog),
                _AuthorList(catalog: catalog),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryList extends StatelessWidget {
  const _CategoryList({required this.catalog});
  final CatalogRepository catalog;

  @override
  Widget build(BuildContext context) {
    final items = catalog.categories();
    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (context, i) {
        final c = items[i];
        return ListTile(
          title: Text(c.name),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => BookListPage(
                title: c.name,
                books: catalog.booksByCategory(c.id),
                allowDownloadAll: true,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _AuthorList extends StatelessWidget {
  const _AuthorList({required this.catalog});
  final CatalogRepository catalog;

  @override
  Widget build(BuildContext context) {
    final items = catalog.authors();
    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (context, i) {
        final a = items[i];
        return ListTile(
          title: Text(a.name),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => BookListPage(
                title: a.name,
                books: catalog.booksByAuthor(a.id),
                allowDownloadAll: true,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SearchResults extends StatelessWidget {
  const _SearchResults({
    required this.catalog,
    required this.query,
    required this.scope,
  });
  final CatalogRepository catalog;
  final String query;
  final CatalogSearchScope scope;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final hits = catalog.scopedSearch(query, chipScope: scope);
    if (hits.isEmpty) {
      return Center(child: Text(l10n.noBooks));
    }
    return ListView(
      children: [
        if (hits.categories.isNotEmpty) ...[
          ListTile(
            title: Text(
              l10n.categories,
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          for (final c in hits.categories)
            ListTile(
              leading: const Icon(Icons.folder_outlined),
              title: Text(c.name),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => BookListPage(
                    title: c.name,
                    books: catalog.booksByCategory(c.id),
                    allowDownloadAll: true,
                  ),
                ),
              ),
            ),
        ],
        if (hits.authors.isNotEmpty) ...[
          ListTile(
            title: Text(
              l10n.authors,
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          for (final a in hits.authors)
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: Text(a.name),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => BookListPage(
                    title: a.name,
                    books: catalog.booksByAuthor(a.id),
                    allowDownloadAll: true,
                  ),
                ),
              ),
            ),
        ],
        if (hits.books.isNotEmpty) ...[
          ListTile(
            title: Text(
              l10n.books,
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          BookListView(books: hits.books, shrinkWrap: true),
        ],
      ],
    );
  }
}

class BookListPage extends ConsumerStatefulWidget {
  const BookListPage({
    super.key,
    required this.title,
    required this.books,
    this.allowDownloadAll = false,
  });

  final String title;
  final List<Book> books;
  final bool allowDownloadAll;

  @override
  ConsumerState<BookListPage> createState() => _BookListPageState();
}

class _BookListPageState extends ConsumerState<BookListPage> {
  bool _selecting = false;
  final Set<int> _selected = {};
  String _filter = '';

  List<Book> get _visible {
    final q = _filter.trim();
    if (q.isEmpty) return widget.books;
    final lower = q.toLowerCase();
    return widget.books.where((b) {
      return b.title.toLowerCase().contains(lower) ||
          (b.authorName?.toLowerCase().contains(lower) ?? false);
    }).toList();
  }

  Future<DownloadService?> _service() async {
    return ref.read(downloadServiceProvider).when(
          data: (s) => s,
          loading: () => null,
          error: (_, __) => null,
        );
  }

  Future<void> _confirmAndEnqueue(List<Book> books) async {
    final l10n = AppLocalizations.of(context);
    final state = await ref.read(stateDatabaseProvider.future);
    if (!mounted) return;
    final statuses = <int, DownloadStatus?>{};
    for (final row in state.listDownloads()) {
      statuses[row['book_id'] as int] = DownloadStatus.parse(
        row['status'] as String,
      );
    }
    final plan = planBatchDownload(
      books: books,
      isInstalled: state.isInstalled,
      downloadStatus: (id) => statuses[id],
    );
    if (plan.missingCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.noBooks)),
      );
      return;
    }
    final ok = await showModalBottomSheet<bool>(
      context: context,
      builder: (ctx) {
        final loc = AppLocalizations.of(ctx);
        return Directionality(
          textDirection: TextDirection.rtl,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  loc.confirmDownloadTitle,
                  style: Theme.of(ctx).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                Text(
                  loc.confirmDownloadBody(
                    plan.missingCount,
                    formatBytes(plan.isbBytesTotal),
                    formatBytes(plan.sqliteBytesTotal),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: Text(loc.cancel),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: Text(loc.confirm),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
    if (!mounted || ok != true) return;
    final svc = await _service();
    await svc?.enqueueMany(plan.toEnqueue);
    if (!mounted) return;
    setState(() {
      _selecting = false;
      _selected.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.title),
          actions: [
            if (_selecting) ...[
              IconButton(
                tooltip: l10n.selectAll,
                onPressed: () => setState(() {
                  for (final b in _visible) {
                    if (b.canInstallOnDevice) _selected.add(b.bookId);
                  }
                }),
                icon: const Icon(Icons.select_all),
              ),
              IconButton(
                tooltip: l10n.deselectAll,
                onPressed: () => setState(() => _selected.clear()),
                icon: const Icon(Icons.deselect),
              ),
              IconButton(
                tooltip: l10n.downloadSelected,
                onPressed: _selected.isEmpty
                    ? null
                    : () {
                        final books = widget.books
                            .where((b) => _selected.contains(b.bookId))
                            .toList();
                        _confirmAndEnqueue(books);
                      },
                icon: const Icon(Icons.download),
              ),
              IconButton(
                tooltip: l10n.cancel,
                onPressed: () => setState(() {
                  _selecting = false;
                  _selected.clear();
                }),
                icon: const Icon(Icons.close),
              ),
            ] else ...[
              IconButton(
                tooltip: l10n.select,
                onPressed: () => setState(() => _selecting = true),
                icon: const Icon(Icons.checklist),
              ),
              if (widget.allowDownloadAll)
                IconButton(
                  tooltip: l10n.downloadAll,
                  onPressed: () => _confirmAndEnqueue(widget.books),
                  icon: const Icon(Icons.download_for_offline_outlined),
                ),
            ],
          ],
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: CatalogSearchField(
                hintText: l10n.searchHint,
                onChanged: (v) => setState(() => _filter = v),
              ),
            ),
            Expanded(
              child: BookListView(
                books: _visible,
                selecting: _selecting,
                selected: _selected,
                onToggle: (id) {
                  setState(() {
                    if (_selected.contains(id)) {
                      _selected.remove(id);
                    } else {
                      _selected.add(id);
                    }
                  });
                },
                onLongPressSelect: (id) {
                  setState(() {
                    _selecting = true;
                    _selected.add(id);
                  });
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class BookListView extends ConsumerWidget {
  const BookListView({
    super.key,
    required this.books,
    this.selecting = false,
    this.selected = const {},
    this.onToggle,
    this.onLongPressSelect,
    this.shrinkWrap = false,
  });

  final List<Book> books;
  final bool selecting;
  final Set<int> selected;
  final void Function(int bookId)? onToggle;
  final void Function(int bookId)? onLongPressSelect;
  final bool shrinkWrap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final stateAsync = ref.watch(stateDatabaseProvider);
    final downloadsAsync = ref.watch(downloadServiceProvider);

    if (books.isEmpty) {
      return Center(child: Text(l10n.noBooks));
    }

    return ListView.builder(
      shrinkWrap: shrinkWrap,
      physics: shrinkWrap ? const NeverScrollableScrollPhysics() : null,
      itemCount: books.length,
      itemBuilder: (context, i) {
        final book = books[i];
        final installed = stateAsync.maybeWhen(
          data: (s) => s.isInstalled(book.bookId),
          orElse: () => false,
        );
        final installedPages = stateAsync.maybeWhen(
          data: (s) => s.installedPageCount(book.bookId),
          orElse: () => null,
        );
        final displayPages =
            book.pageCount > 0 ? book.pageCount : (installedPages ?? 0);
        final sizeLabel =
            book.isbBytes > 0 ? ' · ${formatBytes(book.isbBytes)}' : '';
        final pagesLabel =
            displayPages > 0 ? ' · ${l10n.pagesCount(displayPages)}' : '';
        final subtitle =
            '${book.authorName ?? ''}$pagesLabel'
            '$sizeLabel'
            '${book.categoryName != null ? ' · ${book.categoryName}' : ''}';

        final canDownload = book.canInstallOnDevice;

        if (selecting) {
          return CheckboxListTile(
            value: selected.contains(book.bookId),
            onChanged: installed || !canDownload
                ? null
                : (_) => onToggle?.call(book.bookId),
            title: Text(book.title),
            subtitle: Text(subtitle),
            secondary: installed ? Chip(label: Text(l10n.installed)) : null,
          );
        }

        return ListTile(
          title: Text(book.title),
          subtitle: Text(subtitle),
          onTap: installed
              ? () => ReaderPage.open(
                    context,
                    bookId: book.bookId,
                    title: book.title,
                    authorName: book.authorName,
                  )
              : null,
          onLongPress: installed || !canDownload
              ? null
              : () => onLongPressSelect?.call(book.bookId),
          trailing: installed
              ? Chip(label: Text(l10n.installed))
              : canDownload
                  ? IconButton(
                      tooltip: l10n.download,
                      icon: const Icon(Icons.download),
                      onPressed: () async {
                        final svc = await downloadsAsync.when(
                          data: (s) async => s,
                          loading: () async => null,
                          error: (_, __) async => null,
                        );
                        await svc?.enqueue(book.bookId);
                      },
                    )
                  : null,
        );
      },
    );
  }
}
