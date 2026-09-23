import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ishamela/l10n/app_localizations.dart';

import 'package:ishamela/core/providers.dart';
import 'package:ishamela/features/reader/reader_page.dart';
import 'package:ishamela/ui/book_card.dart';
import 'package:ishamela/ui/empty_state.dart';
import 'package:ishamela/ui/theme/ishamela_theme.dart';
import 'package:ishamela/ui/theme/ishamela_tokens.dart';

/// All bookmarks across installed books (SPEC-023 quick action).
class BookmarksPage extends ConsumerStatefulWidget {
  const BookmarksPage({super.key});

  static Future<void> open(BuildContext context) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const BookmarksPage()),
    );
  }

  @override
  ConsumerState<BookmarksPage> createState() => _BookmarksPageState();
}

class _BookmarksPageState extends ConsumerState<BookmarksPage> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final t = IshamelaTokens.of(context);
    final stateAsync = ref.watch(stateDatabaseProvider);
    final catalogAsync = ref.watch(catalogRepositoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          l10n.bookmarksListTitle,
          style: TextStyle(
            fontFamily: kFontAmiri,
            fontWeight: FontWeight.w700,
            color: t.ink,
          ),
        ),
      ),
      body: stateAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (state) {
          final catalog = catalogAsync.maybeWhen(
            data: (c) => c,
            orElse: () => null,
          );
          final bookmarks = state.listAllBookmarks();
          if (bookmarks.isEmpty) {
            return EmptyState(message: l10n.bookmarksEmpty);
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            itemCount: bookmarks.length,
            itemBuilder: (context, i) {
              final b = bookmarks[i];
              final book = catalog?.bookById(b.bookId);
              final title = book?.title ?? 'book_${b.bookId}';
              final installed = state.isInstalled(b.bookId);
              final printNo = b.printPage?.toString() ?? '—';
              final line2 = [
                if (b.label != null && b.label!.isNotEmpty) b.label!,
                if (b.part.isNotEmpty) 'ج${b.part}',
                'ص$printNo',
              ].join(' · ');
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: BookCard(
                  title: title,
                  categoryId: book?.categoryId ?? 0,
                  author: line2.isEmpty ? null : line2,
                  available: installed,
                  unavailableLabel: installed ? null : l10n.notInstalled,
                  onTap: installed
                      ? () => ReaderPage.open(
                            context,
                            bookId: b.bookId,
                            title: book?.title,
                            authorName: book?.authorName,
                            initialPageId: b.pageId,
                            initialPrintPage: b.printPage,
                          )
                      : null,
                ),
              );
            },
          );
        },
      ),
    );
  }
}
