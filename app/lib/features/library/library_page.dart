import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ishamela/l10n/app_localizations.dart';

import 'package:ishamela/core/providers.dart';
import 'package:ishamela/features/downloads/download_service.dart';
import 'package:ishamela/features/reader/reader_page.dart';

class LibraryPage extends ConsumerStatefulWidget {
  const LibraryPage({super.key});

  @override
  ConsumerState<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends ConsumerState<LibraryPage> {
  DownloadService? _svc;

  void _onDownloadsChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _svc?.removeListener(_onDownloadsChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final stateAsync = ref.watch(stateDatabaseProvider);
    final catalogAsync = ref.watch(catalogRepositoryProvider);
    final downloadsAsync = ref.watch(downloadServiceProvider);

    downloadsAsync.whenData((svc) {
      if (_svc != svc) {
        _svc?.removeListener(_onDownloadsChanged);
        _svc = svc;
        _svc!.addListener(_onDownloadsChanged);
      }
    });

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: Text(l10n.tabLibrary)),
        body: stateAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('$e')),
          data: (state) {
            final ids = state.installedBookIds();
            if (ids.isEmpty) {
              return Center(child: Text(l10n.noBooks));
            }
            return catalogAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('$e')),
              data: (catalog) {
                return ListView.builder(
                  itemCount: ids.length,
                  itemBuilder: (context, i) {
                    final id = ids[i];
                    final book = catalog.bookById(id);
                    return ListTile(
                      title: Text(book?.title ?? 'book_$id'),
                      subtitle: Text(book?.authorName ?? ''),
                      onTap: () => ReaderPage.open(
                        context,
                        bookId: id,
                        title: book?.title,
                        authorName: book?.authorName,
                      ),
                      trailing: IconButton(
                        tooltip: l10n.delete,
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () async {
                          final svc = await downloadsAsync.maybeWhen(
                            data: (s) async => s,
                            orElse: () async => null,
                          );
                          await svc?.deleteInstalled(id);
                          setState(() {});
                        },
                      ),
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}
