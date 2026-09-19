import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ishamela/l10n/app_localizations.dart';

import 'package:ishamela/core/author_death.dart';
import 'package:ishamela/core/author_line.dart';
import 'package:ishamela/core/format_bytes.dart';
import 'package:ishamela/core/models/models.dart';
import 'package:ishamela/core/providers.dart';
import 'package:ishamela/features/catalog/catalog_search_field.dart';
import 'package:ishamela/features/catalog/author_page.dart';
import 'package:ishamela/features/catalog/catalog_service.dart';
import 'package:ishamela/features/downloads/download_service.dart';
import 'package:ishamela/features/reader/reader_page.dart';
import 'package:ishamela/ui/book_card.dart';
import 'package:ishamela/ui/empty_state.dart';
import 'package:ishamela/ui/highlighted_text.dart';
import 'package:ishamela/ui/progress_ring.dart';
import 'package:ishamela/ui/rosette_divider.dart';
import 'package:ishamela/ui/section_label.dart';
import 'package:ishamela/ui/segmented_pills.dart';
import 'package:ishamela/ui/theme/ishamela_theme.dart';
import 'package:ishamela/ui/theme/ishamela_tokens.dart';
import 'package:ishamela/ui/tonal_icon_button.dart';

class CatalogPage extends ConsumerStatefulWidget {
  const CatalogPage({super.key});

  @override
  ConsumerState<CatalogPage> createState() => _CatalogPageState();
}

class _CatalogPageState extends ConsumerState<CatalogPage> {
  String _query = '';
  CatalogSearchScope _scope = CatalogSearchScope.all;
  int _browseIndex = 0;

  void _refresh() {
    ref.invalidate(catalogSyncTickProvider);
    ref.invalidate(catalogRepositoryProvider);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final t = IshamelaTokens.of(context);
    final catalogAsync = ref.watch(catalogRepositoryProvider);
    final syncTick = ref.watch(catalogSyncTickProvider);
    final stateAsync = ref.watch(stateDatabaseProvider);

    ref.listen<String?>(catalogPendingQueryProvider, (prev, next) {
      if (next == null || next.trim().isEmpty) return;
      setState(() => _query = next);
      ref.read(catalogPendingQueryProvider.notifier).clear();
    });

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: catalogAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('$e')),
          data: (catalog) {
            if (!catalog.hasCatalog) {
              return EmptyState(
                message: l10n.offlineEmpty,
                actionLabel: l10n.refresh,
                onAction: _refresh,
              );
            }

            final showStale = catalog.isCatalogStale();
            final staleDays = catalog.catalogAgeDays() ?? 30;
            final bookCount = catalog.bookCount();
            final installedBytes = stateAsync.maybeWhen(
              data: (s) => s.installedSqliteBytesTotal,
              orElse: () => 0,
            );
            final searching = _query.trim().isNotEmpty;

            return CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            const RosetteMark(size: 16),
                            const SizedBox(width: 8),
                            Text(
                              l10n.brandName,
                              style: TextStyle(
                                fontFamily: kFontUi,
                                fontWeight: FontWeight.w700,
                                fontSize: 10.5,
                                letterSpacing: 2.5,
                                color: t.emphasis,
                              ),
                            ),
                            const Spacer(),
                            IconButton(
                              tooltip: l10n.refresh,
                              onPressed: _refresh,
                              icon: const Icon(Icons.refresh),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          l10n.tabCatalog,
                          style: TextStyle(
                            fontFamily: kFontAmiri,
                            fontWeight: FontWeight.w700,
                            fontSize: 26,
                            color: t.ink,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          l10n.catalogFooter(
                            bookCount,
                            formatBytes(installedBytes),
                          ),
                          style: TextStyle(
                            fontFamily: kFontUi,
                            fontSize: 12,
                            color: t.muted,
                          ),
                        ),
                        const SizedBox(height: 16),
                        CatalogSearchField(
                          key: ValueKey('cat-search-$_query'),
                          hintText: l10n.searchHint,
                          initialQuery: _query,
                          onChanged: (v) => setState(() => _query = v),
                        ),
                        if (showStale) ...[
                          const SizedBox(height: 12),
                          _StaleBanner(
                            message: l10n.catalogStaleDays(staleDays),
                            action: l10n.catalogStaleAction,
                            onAction: _refresh,
                          ),
                        ],
                        if (searching) ...[
                          const SizedBox(height: 12),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                for (final s in CatalogSearchScope.values)
                                  Padding(
                                    padding: const EdgeInsetsDirectional.only(
                                      end: 8,
                                    ),
                                    child: FilterChip(
                                      label: Text(_scopeLabel(l10n, s)),
                                      selected: _scope == s,
                                      selectedColor: t.green700,
                                      checkmarkColor: Colors.white,
                                      labelStyle: TextStyle(
                                        fontFamily: kFontUi,
                                        fontWeight: FontWeight.w600,
                                        color: _scope == s
                                            ? Colors.white
                                            : t.ink,
                                      ),
                                      side: BorderSide(
                                        color: _scope == s
                                            ? t.green700
                                            : t.hairline,
                                      ),
                                      onSelected: (_) =>
                                          setState(() => _scope = s),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ] else ...[
                          const SizedBox(height: 16),
                          SegmentedPills(
                            labels: [l10n.categories, l10n.authors],
                            selectedIndex: _browseIndex,
                            onChanged: (i) =>
                                setState(() => _browseIndex = i),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                if (syncTick.isLoading)
                  const SliverToBoxAdapter(
                    child: LinearProgressIndicator(minHeight: 2),
                  ),
                if (searching)
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                    sliver: _SearchResultsSliver(
                      catalog: catalog,
                      query: _query,
                      scope: _scope,
                    ),
                  )
                else if (_browseIndex == 0)
                  _CategorySliver(catalog: catalog)
                else
                  _AuthorSliver(catalog: catalog),
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

class _StaleBanner extends StatelessWidget {
  const _StaleBanner({
    required this.message,
    required this.action,
    required this.onAction,
  });

  final String message;
  final String action;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final t = IshamelaTokens.of(context);
    return Material(
      color: t.goldPale,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Icon(Icons.info_outline, size: 18, color: t.gold),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  fontFamily: kFontUi,
                  fontSize: 12,
                  color: t.ink,
                ),
              ),
            ),
            TextButton(
              onPressed: onAction,
              child: Text(
                action,
                style: TextStyle(
                  fontFamily: kFontUi,
                  fontWeight: FontWeight.w700,
                  color: t.gold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BrowseEntityCard extends StatelessWidget {
  const _BrowseEntityCard({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.titleQuery,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final String? titleQuery;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = IshamelaTokens.of(context);
    return Material(
      color: t.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: t.hairline),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: t.green100,
                child: Icon(icon, color: t.emphasis, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (titleQuery != null && titleQuery!.trim().isNotEmpty)
                      HighlightedText(text: title, query: titleQuery!)
                    else
                      Text(
                        title,
                        style: TextStyle(
                          fontFamily: kFontAmiri,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          color: t.ink,
                        ),
                      ),
                    if (subtitle != null && subtitle!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: TextStyle(
                          fontFamily: kFontUi,
                          fontSize: 12,
                          color: t.muted,
                        ),
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
    );
  }
}

class _CategorySliver extends StatelessWidget {
  const _CategorySliver({required this.catalog});
  final CatalogRepository catalog;

  @override
  Widget build(BuildContext context) {
    final items = catalog.categories();
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      sliver: SliverList.separated(
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, i) {
          final c = items[i];
          return _BrowseEntityCard(
            icon: Icons.folder_outlined,
            title: c.name,
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
      ),
    );
  }
}

class _AuthorSliver extends StatelessWidget {
  const _AuthorSliver({required this.catalog});
  final CatalogRepository catalog;

  @override
  Widget build(BuildContext context) {
    final items = catalog.authors();
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      sliver: SliverList.separated(
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, i) {
          final a = items[i];
          return _BrowseEntityCard(
            icon: Icons.person_outline,
            title: a.name,
            subtitle: formatAuthorDeath(AppLocalizations.of(context), a.deathYearHijri),
            onTap: () => AuthorPage.open(context, authorId: a.id, author: a),
          );
        },
      ),
    );
  }
}

class _SearchResultsSliver extends StatelessWidget {
  const _SearchResultsSliver({
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
      return SliverToBoxAdapter(child: EmptyState(message: l10n.noBooks));
    }
    return SliverList(
      delegate: SliverChildListDelegate([
        if (hits.categories.isNotEmpty) ...[
          SectionLabel(
            label: l10n.sectionWithCount(
              l10n.categories,
              hits.categories.length,
            ),
          ),
          for (final c in hits.categories)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _BrowseEntityCard(
                icon: Icons.folder_outlined,
                title: c.name,
                titleQuery: query,
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
            ),
        ],
        if (hits.authors.isNotEmpty) ...[
          SectionLabel(
            label: l10n.sectionWithCount(l10n.authors, hits.authors.length),
          ),
          for (final a in hits.authors)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _BrowseEntityCard(
                icon: Icons.person_outline,
                title: a.name,
                titleQuery: query,
                subtitle: formatAuthorDeath(l10n, a.deathYearHijri),
                onTap: () =>
                    AuthorPage.open(context, authorId: a.id, author: a),
              ),
            ),
        ],
        if (hits.books.isNotEmpty) ...[
          SectionLabel(
            label: l10n.sectionWithCount(l10n.books, hits.books.length),
          ),
          BookListView(
            books: hits.books,
            shrinkWrap: true,
            highlightQuery: query,
          ),
        ],
      ]),
    );
  }
}

class BookListPage extends ConsumerStatefulWidget {
  const BookListPage({
    super.key,
    required this.title,
    required this.books,
    this.allowDownloadAll = false,
    this.embedded = false,
  });

  final String title;
  final List<Book> books;
  final bool allowDownloadAll;

  /// When true, omit Scaffold/AppBar (SPEC-018 author page body).
  final bool embedded;

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
    final t = IshamelaTokens.of(context);
    final ok = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: t.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
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
                  style: TextStyle(
                    fontFamily: kFontAmiri,
                    fontWeight: FontWeight.w700,
                    fontSize: 22,
                    color: t.ink,
                  ),
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
    final t = IshamelaTokens.of(context);
    final body = Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
          child: _selecting
              ? Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton(
                      onPressed: () => setState(() {
                        for (final b in _visible) {
                          if (b.canInstallOnDevice) {
                            _selected.add(b.bookId);
                          }
                        }
                      }),
                      child: Text(l10n.selectAll),
                    ),
                    OutlinedButton(
                      onPressed: () => setState(() => _selected.clear()),
                      child: Text(l10n.deselectAll),
                    ),
                    FilledButton(
                      onPressed: _selected.isEmpty
                          ? null
                          : () {
                              final books = widget.books
                                  .where(
                                    (b) => _selected.contains(b.bookId),
                                  )
                                  .toList();
                              _confirmAndEnqueue(books);
                            },
                      child: Text(
                        l10n.downloadSelectedCount(_selected.length),
                      ),
                    ),
                    TextButton(
                      onPressed: () => setState(() {
                        _selecting = false;
                        _selected.clear();
                      }),
                      child: Text(
                        l10n.cancel,
                        style: TextStyle(color: t.muted),
                      ),
                    ),
                  ],
                )
              : Row(
                  children: [
                    if (widget.allowDownloadAll)
                      FilledButton.tonal(
                        onPressed: () => _confirmAndEnqueue(widget.books),
                        style: FilledButton.styleFrom(
                          backgroundColor: t.green100,
                          foregroundColor: t.emphasis,
                        ),
                        child: Text(l10n.downloadAll),
                      ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: () => setState(() => _selecting = true),
                      child: Text(l10n.select),
                    ),
                  ],
                ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: CatalogSearchField(
            hintText: l10n.filterHint,
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
    );

    if (widget.embedded) return body;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.title),
        ),
        body: body,
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
    this.highlightQuery,
  });

  final List<Book> books;
  final bool selecting;
  final Set<int> selected;
  final String? highlightQuery;
  final void Function(int bookId)? onToggle;
  final void Function(int bookId)? onLongPressSelect;
  final bool shrinkWrap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final stateAsync = ref.watch(stateDatabaseProvider);
    final downloadsAsync = ref.watch(downloadServiceProvider);
    final width = MediaQuery.sizeOf(context).width;
    final cols = width >= 1200 ? 3 : width >= 600 ? 2 : 1;

    if (books.isEmpty) {
      return EmptyState(message: l10n.noBooks);
    }

    Widget tile(Book book) {
      final installed = stateAsync.maybeWhen(
        data: (s) => s.isInstalled(book.bookId),
        orElse: () => false,
      );
      final status = stateAsync.maybeWhen(
        data: (s) => s.downloadStatus(book.bookId),
        orElse: () => null,
      );
      final installedPages = stateAsync.maybeWhen(
        data: (s) => s.installedPageCount(book.bookId),
        orElse: () => null,
      );
      final displayPages =
          book.pageCount > 0 ? book.pageCount : (installedPages ?? 0);
      final meta = <String>[
        if (book.volumeCount != null && book.volumeCount! > 0)
          l10n.volumesCount(book.volumeCount!),
        if (displayPages > 0) l10n.pagesCount(displayPages),
        if (book.isbBytes > 0) formatBytes(book.isbBytes),
        if (book.categoryName != null && book.categoryName!.isNotEmpty)
          book.categoryName!,
      ];
      final canDownload = book.canInstallOnDevice;
      final inFlight = status == DownloadStatus.downloading ||
          status == DownloadStatus.queued ||
          status == DownloadStatus.verifying ||
          status == DownloadStatus.installing;

      Widget? trailing;
      if (installed) {
        trailing = MetaChipInstalled(label: l10n.installed);
      } else if (inFlight) {
        trailing = const ProgressRing(value: 0.35);
      } else if (canDownload) {
        trailing = TonalIconButton(
          tooltip: l10n.download,
          icon: Icons.download,
          onPressed: () async {
            final svc = await downloadsAsync.when(
              data: (s) async => s,
              loading: () async => null,
              error: (_, __) async => null,
            );
            await svc?.enqueue(book.bookId);
          },
        );
      }

      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: BookCard(
          title: book.title,
          categoryId: book.categoryId,
          author: formatAuthorLine(book.authorName, book.authorDeathYearHijri),
          onAuthorTap: book.authorId == null
              ? null
              : () => AuthorPage.open(
                    context,
                    authorId: book.authorId!,
                    author: Author(
                      id: book.authorId!,
                      name: book.authorName ?? '',
                      deathYearHijri: book.authorDeathYearHijri,
                    ),
                  ),
          meta: meta,
          highlightQuery: highlightQuery,
          available: canDownload || installed,
          unavailableLabel:
              canDownload || installed ? null : l10n.unavailableForDownload,
          trailing: trailing,
          selected: selecting ? selected.contains(book.bookId) : null,
          onSelectedChanged: selecting && canDownload && !installed
              ? (_) => onToggle?.call(book.bookId)
              : null,
          onTap: installed
              ? () => ReaderPage.open(
                    context,
                    bookId: book.bookId,
                    title: book.title,
                    authorName: book.authorName,
                    authorId: book.authorId,
                  )
              : null,
          onLongPress: installed || !canDownload
              ? null
              : () => onLongPressSelect?.call(book.bookId),
        ),
      );
    }

    if (shrinkWrap) {
      return Column(
        children: [for (final b in books) tile(b)],
      );
    }

    if (cols > 1) {
      return GridView.builder(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: cols,
          mainAxisExtent: 148,
          crossAxisSpacing: 12,
          mainAxisSpacing: 4,
        ),
        itemCount: books.length,
        itemBuilder: (context, i) => tile(books[i]),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      itemCount: books.length,
      itemBuilder: (context, i) => tile(books[i]),
    );
  }
}

/// Small installed chip using design tokens.
class MetaChipInstalled extends StatelessWidget {
  const MetaChipInstalled({super.key, required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final t = IshamelaTokens.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: t.green100,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: kFontUi,
          fontWeight: FontWeight.w600,
          fontSize: 11,
          color: t.emphasis,
        ),
      ),
    );
  }
}
