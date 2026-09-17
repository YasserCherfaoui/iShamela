import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ishamela/l10n/app_localizations.dart';

import 'package:ishamela/core/models/models.dart';
import 'package:ishamela/core/providers.dart';
import 'package:ishamela/features/catalog/catalog_service.dart';

class CatalogPage extends ConsumerStatefulWidget {
  const CatalogPage({super.key});

  @override
  ConsumerState<CatalogPage> createState() => _CatalogPageState();
}

class _CatalogPageState extends ConsumerState<CatalogPage> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final catalogAsync = ref.watch(catalogRepositoryProvider);
    final syncTick = ref.watch(catalogSyncTickProvider);

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
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: l10n.searchHint,
                      prefixIcon: const Icon(Icons.search),
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (v) => setState(() => _query = v),
                  ),
                ),
                Expanded(
                  child: _query.trim().isEmpty
                      ? _BrowseTabs(catalog: catalog)
                      : _SearchResults(catalog: catalog, query: _query),
                ),
              ],
            );
          },
        ),
      ),
    );
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
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SearchResults extends StatelessWidget {
  const _SearchResults({required this.catalog, required this.query});
  final CatalogRepository catalog;
  final String query;

  @override
  Widget build(BuildContext context) {
    final books = catalog.search(query);
    if (books.isEmpty) {
      return Center(child: Text(AppLocalizations.of(context).noBooks));
    }
    return BookListView(books: books);
  }
}

class BookListPage extends StatelessWidget {
  const BookListPage({super.key, required this.title, required this.books});
  final String title;
  final List<Book> books;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: Text(title)),
        body: BookListView(books: books),
      ),
    );
  }
}

class BookListView extends ConsumerWidget {
  const BookListView({super.key, required this.books});
  final List<Book> books;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final stateAsync = ref.watch(stateDatabaseProvider);
    final downloadsAsync = ref.watch(downloadServiceProvider);

    if (books.isEmpty) {
      return Center(child: Text(l10n.noBooks));
    }

    return ListView.builder(
      itemCount: books.length,
      itemBuilder: (context, i) {
        final book = books[i];
        final installed = stateAsync.maybeWhen(
          data: (s) => s.isInstalled(book.bookId),
          orElse: () => false,
        );
        return ListTile(
          title: Text(book.title),
          subtitle: Text(book.authorName ?? ''),
          trailing: installed
              ? Chip(label: Text(l10n.installed))
              : IconButton(
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
                ),
        );
      },
    );
  }
}
