import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ishamela/l10n/app_localizations.dart';

import 'package:ishamela/core/db/state_database.dart';
import 'package:ishamela/core/models/models.dart';
import 'package:ishamela/core/providers.dart';
import 'package:ishamela/core/search/normalizer.dart';
import 'package:ishamela/features/reader/reader_page.dart';
import 'package:ishamela/ui/app_search_field.dart';
import 'package:ishamela/ui/book_card.dart';
import 'package:ishamela/ui/empty_state.dart';
import 'package:ishamela/ui/theme/ishamela_theme.dart';
import 'package:ishamela/ui/theme/ishamela_tokens.dart';
import 'package:ishamela/ui/tonal_icon_button.dart';

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
  int _tick = 0;
  String _query = '';

  Future<void> _renameBookmark(
    AppLocalizations l10n,
    StateDatabase state,
    Bookmark b,
  ) async {
    final ctrl = TextEditingController(text: b.label ?? '');
    final String? renamed;
    try {
      renamed = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(l10n.renameBookmark),
          content: TextField(controller: ctrl, autofocus: true),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
              child: Text(l10n.confirm),
            ),
          ],
        ),
      );
    } finally {
      ctrl.dispose();
    }
    if (!mounted || renamed == null) return;
    state.updateBookmarkLabel(b.id, renamed);
    setState(() => _tick++);
  }

  void _deleteBookmark(
    AppLocalizations l10n,
    StateDatabase state,
    Bookmark b,
  ) {
    state.deleteBookmark(b.id);
    setState(() => _tick++);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.bookmarkRemoved),
        action: SnackBarAction(
          label: l10n.undo,
          onPressed: () {
            state.toggleBookmark(
              bookId: b.bookId,
              pageId: b.pageId,
              part: b.part,
              printPage: b.printPage,
              label: b.label,
              createdAt: b.createdAt,
            );
            if (mounted) setState(() => _tick++);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final t = IshamelaTokens.of(context);
    final width = MediaQuery.sizeOf(context).width;
    final stateAsync = ref.watch(stateDatabaseProvider);
    final catalogAsync = ref.watch(catalogRepositoryProvider);
    final downloadsAsync = ref.watch(downloadServiceProvider);

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
          final _ = _tick;
          final catalog = catalogAsync.maybeWhen(
            data: (c) => c,
            orElse: () => null,
          );
          final all = state.listAllBookmarks();
          if (all.isEmpty) {
            return EmptyState(message: l10n.bookmarksEmpty);
          }
          final q = normalize(_query.trim());
          final bookmarks = q.isEmpty
              ? all
              : all.where((b) {
                  final title = catalog?.bookById(b.bookId)?.title ?? '';
                  final label = b.label ?? '';
                  return normalize(title).contains(q) ||
                      normalize(label).contains(q);
                }).toList();

          final content = Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                child: AppSearchField(
                  hintText: l10n.searchHint,
                  onChanged: (v) => setState(() => _query = v),
                ),
              ),
              Expanded(
                child: bookmarks.isEmpty
                    ? EmptyState(message: l10n.bookmarksEmpty)
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                        itemCount: bookmarks.length,
                        itemBuilder: (context, i) {
                          final b = bookmarks[i];
                          final book = catalog?.bookById(b.bookId);
                          final title = book?.title ?? 'book_${b.bookId}';
                          final installed = state.isInstalled(b.bookId);
                          final printNo = b.printPage?.toString() ?? '—';
                          final line2 = [
                            if (b.label != null && b.label!.isNotEmpty)
                              b.label!,
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
                              unavailableLabel: installed
                                  ? null
                                  : l10n.notInstalled,
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (!installed)
                                    TonalIconButton(
                                      tooltip: l10n.download,
                                      icon: Icons.download,
                                      onPressed: () async {
                                        final svc = downloadsAsync.maybeWhen(
                                          data: (s) => s,
                                          orElse: () => null,
                                        );
                                        await svc?.enqueue(b.bookId);
                                        if (mounted) setState(() => _tick++);
                                      },
                                    ),
                                  PopupMenuButton<String>(
                                    onSelected: (v) {
                                      if (v == 'rename') {
                                        _renameBookmark(l10n, state, b);
                                      } else if (v == 'delete') {
                                        _deleteBookmark(l10n, state, b);
                                      }
                                    },
                                    itemBuilder: (_) => [
                                      PopupMenuItem(
                                        value: 'rename',
                                        child: Text(l10n.renameBookmark),
                                      ),
                                      PopupMenuItem(
                                        value: 'delete',
                                        child: Text(l10n.delete),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              onTap: installed
                                  ? () async {
                                      await ReaderPage.open(
                                        context,
                                        bookId: b.bookId,
                                        title: book?.title,
                                        authorName: book?.authorName,
                                        authorId: book?.authorId,
                                        initialPageId: b.pageId,
                                        initialPrintPage: b.printPage,
                                        initialPart: b.part,
                                      );
                                      if (mounted) setState(() => _tick++);
                                    }
                                  : null,
                            ),
                          );
                        },
                      ),
              ),
            ],
          );

          if (width >= 800) {
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: content,
              ),
            );
          }
          return content;
        },
      ),
    );
  }
}
