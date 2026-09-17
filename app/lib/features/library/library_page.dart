import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ishamela/l10n/app_localizations.dart';

import 'package:ishamela/core/providers.dart';

class LibraryPage extends ConsumerWidget {
  const LibraryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final stateAsync = ref.watch(stateDatabaseProvider);
    final catalogAsync = ref.watch(catalogRepositoryProvider);
    final downloadsAsync = ref.watch(downloadServiceProvider);

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
                      trailing: IconButton(
                        tooltip: l10n.delete,
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () async {
                          final svc = await downloadsAsync.maybeWhen(
                            data: (s) async => s,
                            orElse: () async => null,
                          );
                          await svc?.deleteInstalled(id);
                          ref.invalidate(stateDatabaseProvider);
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
