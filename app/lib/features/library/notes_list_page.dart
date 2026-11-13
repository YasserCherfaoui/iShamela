import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ishamela/l10n/app_localizations.dart';

import 'package:ishamela/core/db/paths.dart';
import 'package:ishamela/core/db/state_database.dart';
import 'package:ishamela/core/providers.dart';
import 'package:ishamela/core/search/normalizer.dart';
import 'package:ishamela/features/reader/book_database.dart';
import 'package:ishamela/features/reader/citation.dart';
import 'package:ishamela/features/reader/highlight_excerpt.dart';
import 'package:ishamela/features/reader/reader_page.dart';
import 'package:ishamela/ui/app_search_field.dart';
import 'package:ishamela/ui/book_card.dart';
import 'package:ishamela/ui/empty_state.dart';
import 'package:ishamela/ui/segmented_pills.dart';
import 'package:ishamela/ui/theme/ishamela_theme.dart';
import 'package:ishamela/ui/theme/ishamela_tokens.dart';
import 'package:ishamela/ui/theme/reader_theme_tokens.dart';
import 'package:ishamela/ui/tonal_icon_button.dart';

/// All text notes and highlights across books (SPEC-023 quick action).
class NotesListPage extends ConsumerStatefulWidget {
  const NotesListPage({super.key});

  static Future<void> open(BuildContext context) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const NotesListPage()),
    );
  }

  @override
  ConsumerState<NotesListPage> createState() => _NotesListPageState();
}

class _NotesListPageState extends ConsumerState<NotesListPage> {
  int _tick = 0;
  int _tab = 0;
  String _query = '';
  final Map<(int, int), BookPage?> _pageCache = {};

  void _warmPageCache(
    AppPaths? paths,
    StateDatabase state,
    List<Map<String, Object?>> rows,
  ) {
    if (paths == null) return;
    final missingByBook = <int, Set<int>>{};
    for (final r in rows) {
      final bookId = r['book_id'] as int;
      final pageId = r['page_id'] as int;
      if (_pageCache.containsKey((bookId, pageId))) continue;
      if (!state.isInstalled(bookId)) {
        _pageCache[(bookId, pageId)] = null;
        continue;
      }
      missingByBook.putIfAbsent(bookId, () => <int>{}).add(pageId);
    }
    for (final entry in missingByBook.entries) {
      BookDatabase? db;
      try {
        db = BookDatabase.open(paths, entry.key);
        for (final pageId in entry.value) {
          _pageCache[(entry.key, pageId)] = db.pageById(pageId);
        }
      } catch (_) {
        for (final pageId in entry.value) {
          _pageCache[(entry.key, pageId)] = null;
        }
      } finally {
        db?.close();
      }
    }
  }

  String _pageLabel(BookPage? page) {
    if (page == null) return '—';
    final printNo = page.pageNumber?.toString() ?? '—';
    final part = page.part;
    if (part != null && part.isNotEmpty) {
      return 'ج$part · ص$printNo';
    }
    return 'ص$printNo';
  }

  Future<void> _editNote(
    AppLocalizations l10n,
    StateDatabase state,
    int id,
    String current,
  ) async {
    final ctrl = TextEditingController(text: current);
    final String? updated;
    try {
      updated = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(l10n.addNote),
          content: TextField(controller: ctrl, maxLines: 4, autofocus: true),
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
    if (!mounted || updated == null) return;
    if (updated.isEmpty) {
      state.deleteNote(id);
    } else {
      state.updateNote(id, updated);
    }
    setState(() => _tick++);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final t = IshamelaTokens.of(context);
    final width = MediaQuery.sizeOf(context).width;
    final stateAsync = ref.watch(stateDatabaseProvider);
    final catalogAsync = ref.watch(catalogRepositoryProvider);
    final pathsAsync = ref.watch(appPathsProvider);
    final downloadsAsync = ref.watch(downloadServiceProvider);

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
          final _ = _tick;
          final catalog = catalogAsync.maybeWhen(
            data: (c) => c,
            orElse: () => null,
          );
          final paths = pathsAsync.maybeWhen(
            data: (p) => p,
            orElse: () => null,
          );
          final allNotes = state.listAllNotes();
          final allHighlights = state.listAllHighlights();
          _warmPageCache(paths, state, _tab == 0 ? allNotes : allHighlights);

          final q = normalize(_query.trim());
          final notes = q.isEmpty
              ? allNotes
              : allNotes.where((n) {
                  final title =
                      catalog?.bookById(n['book_id'] as int)?.title ?? '';
                  final body = (n['note'] as String?) ?? '';
                  return normalize(title).contains(q) ||
                      normalize(body).contains(q);
                }).toList();
          final highlights = q.isEmpty
              ? allHighlights
              : allHighlights.where((h) {
                  final bookId = h['book_id'] as int;
                  final pageId = h['page_id'] as int;
                  final title = catalog?.bookById(bookId)?.title ?? '';
                  final page = _pageCache[(bookId, pageId)];
                  final excerpt = page == null
                      ? ''
                      : highlightListExcerpt(
                          page.body,
                          h['start_offset'] as int,
                          h['end_offset'] as int,
                        );
                  return normalize(title).contains(q) ||
                      normalize(excerpt).contains(q);
                }).toList();

          final night =
              ReaderThemeTokens.of(context).atmosphere ==
              ReadingAtmosphere.night;
          final palette = night ? highlightColorsNight : highlightColors;

          final content = Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                child: SegmentedPills(
                  fitLabels: true,
                  labels: [l10n.notesTab, l10n.highlightsTab],
                  selectedIndex: _tab,
                  onChanged: (i) => setState(() => _tab = i),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: AppSearchField(
                  hintText: l10n.searchHint,
                  onChanged: (v) => setState(() => _query = v),
                ),
              ),
              Expanded(
                child: _tab == 0
                    ? (notes.isEmpty
                          ? EmptyState(message: l10n.notesListEmpty)
                          : ListView.builder(
                              padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                              itemCount: notes.length,
                              itemBuilder: (context, i) {
                                final n = notes[i];
                                final id = n['id'] as int;
                                final bookId = n['book_id'] as int;
                                final pageId = n['page_id'] as int;
                                final body = (n['note'] as String?) ?? '';
                                final book = catalog?.bookById(bookId);
                                final title = book?.title ?? 'book_$bookId';
                                final installed = state.isInstalled(bookId);
                                final page = _pageCache[(bookId, pageId)];
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: BookCard(
                                    title: title,
                                    categoryId: book?.categoryId ?? 0,
                                    author: body,
                                    meta: [_pageLabel(page)],
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
                                              final svc = downloadsAsync
                                                  .maybeWhen(
                                                    data: (s) => s,
                                                    orElse: () => null,
                                                  );
                                              await svc?.enqueue(bookId);
                                              if (mounted) {
                                                setState(() => _tick++);
                                              }
                                            },
                                          ),
                                        PopupMenuButton<String>(
                                          onSelected: (v) {
                                            if (v == 'edit') {
                                              _editNote(l10n, state, id, body);
                                            } else if (v == 'delete') {
                                              state.deleteNote(id);
                                              setState(() => _tick++);
                                            }
                                          },
                                          itemBuilder: (_) => [
                                            PopupMenuItem(
                                              value: 'edit',
                                              child: Text(l10n.addNote),
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
                                              bookId: bookId,
                                              title: book?.title,
                                              authorName: book?.authorName,
                                              authorId: book?.authorId,
                                              initialPageId: pageId,
                                            );
                                            if (mounted) {
                                              _pageCache.clear();
                                              setState(() => _tick++);
                                            }
                                          }
                                        : null,
                                  ),
                                );
                              },
                            ))
                    : (highlights.isEmpty
                          ? EmptyState(message: l10n.highlightsEmpty)
                          : ListView.builder(
                              padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                              itemCount: highlights.length,
                              itemBuilder: (context, i) {
                                final h = highlights[i];
                                final id = h['id'] as int;
                                final bookId = h['book_id'] as int;
                                final pageId = h['page_id'] as int;
                                final start = h['start_offset'] as int;
                                final end = h['end_offset'] as int;
                                final colorName =
                                    h['color'] as String? ?? 'yellow';
                                final argb =
                                    palette[colorName] ?? palette['yellow']!;
                                final book = catalog?.bookById(bookId);
                                final title = book?.title ?? 'book_$bookId';
                                final installed = state.isInstalled(bookId);
                                final page = _pageCache[(bookId, pageId)];
                                final excerpt = page == null
                                    ? '—'
                                    : highlightListExcerpt(
                                        page.body,
                                        start,
                                        end,
                                      );
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: BookCard(
                                    title: title,
                                    categoryId: book?.categoryId ?? 0,
                                    author: excerpt,
                                    meta: [_pageLabel(page)],
                                    available: installed,
                                    unavailableLabel: installed
                                        ? null
                                        : l10n.notInstalled,
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          width: 10,
                                          height: 10,
                                          decoration: BoxDecoration(
                                            color: Color(argb),
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        if (!installed)
                                          TonalIconButton(
                                            tooltip: l10n.download,
                                            icon: Icons.download,
                                            onPressed: () async {
                                              final svc = downloadsAsync
                                                  .maybeWhen(
                                                    data: (s) => s,
                                                    orElse: () => null,
                                                  );
                                              await svc?.enqueue(bookId);
                                              if (mounted) {
                                                setState(() => _tick++);
                                              }
                                            },
                                          ),
                                        IconButton(
                                          tooltip: l10n.delete,
                                          icon: const Icon(
                                            Icons.delete_outline,
                                            size: 20,
                                          ),
                                          onPressed: () {
                                            state.deleteHighlight(id);
                                            setState(() => _tick++);
                                          },
                                        ),
                                      ],
                                    ),
                                    onTap: installed
                                        ? () async {
                                            await ReaderPage.open(
                                              context,
                                              bookId: bookId,
                                              title: book?.title,
                                              authorName: book?.authorName,
                                              authorId: book?.authorId,
                                              initialPageId: pageId,
                                            );
                                            if (mounted) {
                                              _pageCache.clear();
                                              setState(() => _tick++);
                                            }
                                          }
                                        : null,
                                  ),
                                );
                              },
                            )),
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
