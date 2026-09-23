import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ishamela/l10n/app_localizations.dart';

import 'package:ishamela/core/providers.dart';
import 'package:ishamela/features/reader/reader_page.dart';
import 'package:ishamela/ui/book_card.dart';
import 'package:ishamela/ui/empty_state.dart';
import 'package:ishamela/ui/theme/ishamela_theme.dart';
import 'package:ishamela/ui/theme/ishamela_tokens.dart';

/// All text notes across books (SPEC-023 quick action).
class NotesListPage extends ConsumerWidget {
  const NotesListPage({super.key});

  static Future<void> open(BuildContext context) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const NotesListPage()),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final t = IshamelaTokens.of(context);
    final stateAsync = ref.watch(stateDatabaseProvider);
    final catalogAsync = ref.watch(catalogRepositoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          l10n.notesListTitle,
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
          final notes = state.listAllNotes();
          if (notes.isEmpty) {
            return EmptyState(message: l10n.notesListEmpty);
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            itemCount: notes.length,
            itemBuilder: (context, i) {
              final n = notes[i];
              final bookId = n['book_id'] as int;
              final pageId = n['page_id'] as int;
              final body = (n['note'] as String?) ?? '';
              final book = catalog?.bookById(bookId);
              final title = book?.title ?? 'book_$bookId';
              final installed = state.isInstalled(bookId);
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: BookCard(
                  title: title,
                  categoryId: book?.categoryId ?? 0,
                  author: body,
                  meta: ['ص$pageId'],
                  available: installed,
                  unavailableLabel: installed ? null : l10n.notInstalled,
                  onTap: installed
                      ? () => ReaderPage.open(
                            context,
                            bookId: bookId,
                            title: book?.title,
                            authorName: book?.authorName,
                            initialPageId: pageId,
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
