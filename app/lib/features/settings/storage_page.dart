import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ishamela/l10n/app_localizations.dart';

import 'package:ishamela/core/auth/auth_state.dart';
import 'package:ishamela/core/format_bytes.dart';
import 'package:ishamela/core/models/models.dart';
import 'package:ishamela/core/providers.dart';
import 'package:ishamela/core/storage_size.dart';
import 'package:ishamela/features/catalog/author_page.dart';
import 'package:ishamela/features/library/library_sync_sheets.dart';
import 'package:ishamela/features/reader/reader_page.dart';
import 'package:ishamela/ui/book_card.dart';
import 'package:ishamela/ui/empty_state.dart';
import 'package:ishamela/ui/theme/ishamela_theme.dart';
import 'package:ishamela/ui/theme/ishamela_tokens.dart';

/// SPEC-015 storage manager screen.
class StoragePage extends ConsumerStatefulWidget {
  const StoragePage({super.key});

  static Future<void> open(BuildContext context) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const StoragePage()),
    );
  }

  @override
  ConsumerState<StoragePage> createState() => _StoragePageState();
}

class _StoragePageState extends ConsumerState<StoragePage> {
  bool _selecting = false;
  final Set<int> _selected = {};
  int? _freeBytes;
  int _tick = 0;
  bool _backfilling = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final paths = await ref.read(appPathsProvider.future);
    final state = await ref.read(stateDatabaseProvider.future);
    setState(() => _backfilling = state.hasUnknownInstalledSizes);
    await backfillInstalledSizes(paths, state);
    final free = await deviceFreeBytes(paths);
    if (!mounted) return;
    setState(() {
      _freeBytes = free;
      _backfilling = false;
      _tick++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final t = IshamelaTokens.of(context);
    final stateAsync = ref.watch(stateDatabaseProvider);
    final catalogAsync = ref.watch(catalogRepositoryProvider);
    final downloadsAsync = ref.watch(downloadServiceProvider);
    final width = MediaQuery.sizeOf(context).width;

    return Directionality(
      textDirection: Directionality.of(context),
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            l10n.manageStorage,
            style: TextStyle(
              fontFamily: kFontAmiri,
              fontWeight: FontWeight.w700,
              fontSize: 22,
              color: t.ink,
            ),
          ),
          actions: [
            if (_selecting) ...[
              TextButton(
                onPressed: () {
                  final rows = stateAsync.maybeWhen(
                    data: (s) => s.installedBooksBySizeDesc(),
                    orElse: () => <({int bookId, int? sizeBytes})>[],
                  );
                  setState(() {
                    _selected
                      ..clear()
                      ..addAll(rows.map((r) => r.bookId));
                  });
                },
                child: Text(l10n.selectAll),
              ),
              TextButton(
                onPressed: _selected.isEmpty
                    ? null
                    : () async {
                        final state =
                            await ref.read(stateDatabaseProvider.future);
                        if (!context.mounted) return;
                        final size = _selected.fold<int>(
                          0,
                          (a, id) => a + (state.installedSizeBytes(id) ?? 0),
                        );
                        final ok = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: Text(l10n.delete),
                            content: Text(
                              '${l10n.confirmBulkDelete}\n'
                              '${l10n.uninstallConfirmSize(formatBytes(size))}',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: Text(l10n.cancel),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                child: Text(
                                  l10n.confirm,
                                  style: const TextStyle(
                                    color: Color(0xFFA6402E),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                        if (ok != true || !context.mounted) return;
                        final signedIn = ref.read(authProvider).isVerified;
                        final choice = await showBookRemovalSheet(
                          context,
                          signedIn: signedIn,
                        );
                        if (choice == null || !context.mounted) return;
                        final svc = downloadsAsync.maybeWhen(
                          data: (s) => s,
                          orElse: () => null,
                        );
                        final db = ref.read(stateDatabaseProvider).maybeWhen(
                              data: (s) => s,
                              orElse: () => null,
                            );
                        if (svc != null && db != null) {
                          for (final id in _selected.toList()) {
                            await applyBookRemoval(
                              choice: choice,
                              signedIn: signedIn,
                              bookId: id,
                              title: '',
                              sizeBytes: 0,
                              catalogVersion: 0,
                              state: db,
                              downloads: svc,
                              pushRemoved: (docs) => ref
                                  .read(authProvider.notifier)
                                  .pushLibrary(docs),
                            );
                          }
                        }
                        if (!mounted) return;
                        setState(() {
                          _selected.clear();
                          _selecting = false;
                          _tick++;
                        });
                      },
                child: Text(l10n.uninstallSelected(_selected.length)),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => setState(() {
                  _selecting = false;
                  _selected.clear();
                }),
              ),
            ] else
              TextButton(
                onPressed: () => setState(() => _selecting = true),
                child: Text(l10n.select),
              ),
          ],
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
            final rows = state.installedBooksBySizeDesc();
            final used = state.installedSizeBytesTotal;
            final free = _freeBytes;

            Widget body = Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (free != null && free + used > 0) ...[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            value: used / (used + free),
                            minHeight: 5,
                            backgroundColor: t.segmentTrack,
                            color: t.green700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          l10n.freeUpSpace(
                            formatBytes(used),
                            formatBytes(free),
                          ),
                          style: TextStyle(
                            fontFamily: kFontUi,
                            fontSize: 12,
                            color: t.muted,
                          ),
                        ),
                      ] else
                        Text(
                          l10n.storageUsed(formatBytes(used), rows.length),
                          style: TextStyle(
                            fontFamily: kFontUi,
                            fontSize: 12,
                            color: t.muted,
                          ),
                        ),
                      if (_backfilling)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            l10n.calculatingSizes,
                            style: TextStyle(
                              fontFamily: kFontUi,
                              fontSize: 11,
                              color: t.muted,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: rows.isEmpty
                      ? EmptyState(
                          message: l10n.noInstalledBooks,
                          actionLabel: l10n.browseCatalog,
                          onAction: () {
                            ref
                                .read(homeTabIndexProvider.notifier)
                                .go(HomeTabs.catalog);
                            Navigator.pop(context);
                          },
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                          itemCount: rows.length,
                          itemBuilder: (context, i) {
                            final row = rows[i];
                            final book = catalog?.bookById(row.bookId);
                            final title =
                                book?.title ?? 'book_${row.bookId}';
                            final sizeLabel = row.sizeBytes == null
                                ? '—'
                                : formatBytes(row.sizeBytes!);
                            final meta = <String>[
                              if (book?.volumeCount != null &&
                                  book!.volumeCount! > 0)
                                l10n.volumesCount(book.volumeCount!),
                              sizeLabel,
                            ];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: BookCard(
                                title: title,
                                categoryId: book?.categoryId ?? 0,
                                author: book?.authorName,
                                onAuthorTap: book?.authorId == null
                                    ? null
                                    : () => AuthorPage.open(
                                          context,
                                          authorId: book!.authorId!,
                                          author: Author(
                                            id: book.authorId!,
                                            name: book.authorName ?? '',
                                            deathYearHijri:
                                                book.authorDeathYearHijri,
                                          ),
                                        ),
                                meta: meta,
                                trailing: _selecting
                                    ? null
                                    : Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            sizeLabel,
                                            style: TextStyle(
                                              fontFamily: kFontUi,
                                              fontWeight: FontWeight.w600,
                                              fontSize: 13,
                                              color: t.ink,
                                            ),
                                          ),
                                          PopupMenuButton<String>(
                                            onSelected: (v) async {
                                              if (v == 'uninstall') {
                                                final messenger =
                                                    ScaffoldMessenger.of(context);
                                                final signedIn = ref
                                                    .read(authProvider)
                                                    .isVerified;
                                                final choice =
                                                    await showBookRemovalSheet(
                                                  context,
                                                  signedIn: signedIn,
                                                );
                                                if (choice == null || !mounted) {
                                                  return;
                                                }
                                                final svc =
                                                    downloadsAsync.maybeWhen(
                                                  data: (s) => s,
                                                  orElse: () => null,
                                                );
                                                final db = ref
                                                    .read(stateDatabaseProvider)
                                                    .maybeWhen(
                                                      data: (s) => s,
                                                      orElse: () => null,
                                                    );
                                                if (svc != null && db != null) {
                                                  await applyBookRemoval(
                                                    choice: choice,
                                                    signedIn: signedIn,
                                                    bookId: row.bookId,
                                                    title: title,
                                                    sizeBytes: row.sizeBytes ?? 0,
                                                    catalogVersion: 0,
                                                    state: db,
                                                    downloads: svc,
                                                    pushRemoved: (docs) => ref
                                                        .read(authProvider
                                                            .notifier)
                                                        .pushLibrary(docs),
                                                  );
                                                }
                                                if (!mounted) return;
                                                setState(() => _tick++);
                                                messenger.showSnackBar(
                                                  SnackBar(
                                                    content: Text(
                                                      l10n.uninstallConfirmSize(
                                                        sizeLabel,
                                                      ),
                                                    ),
                                                  ),
                                                );
                                              } else if (v == 'card' &&
                                                  book != null) {
                                                await showDialog<void>(
                                                  context: context,
                                                  builder: (ctx) => AlertDialog(
                                                    title: Text(book.title),
                                                    content: Text(
                                                      book.betakaText
                                                                  ?.trim()
                                                                  .isNotEmpty ==
                                                              true
                                                          ? book.betakaText!
                                                          : (book.authorName ??
                                                              ''),
                                                    ),
                                                    actions: [
                                                      TextButton(
                                                        onPressed: () =>
                                                            Navigator.pop(ctx),
                                                        child: Text(l10n.cancel),
                                                      ),
                                                    ],
                                                  ),
                                                );
                                              }
                                            },
                                            itemBuilder: (_) => [
                                              PopupMenuItem(
                                                value: 'uninstall',
                                                child: Text(l10n.delete),
                                              ),
                                              PopupMenuItem(
                                                value: 'card',
                                                child: Text(l10n.bookCard),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                selected: _selecting
                                    ? _selected.contains(row.bookId)
                                    : null,
                                onSelectedChanged: _selecting
                                    ? (_) => setState(() {
                                          if (_selected.contains(row.bookId)) {
                                            _selected.remove(row.bookId);
                                          } else {
                                            _selected.add(row.bookId);
                                          }
                                        })
                                    : null,
                                onTap: _selecting
                                    ? null
                                    : () => ReaderPage.open(
                                          context,
                                          bookId: row.bookId,
                                          title: book?.title,
                                          authorName: book?.authorName,
                                          authorId: book?.authorId,
                                        ),
                                onLongPress: () => setState(() {
                                  _selecting = true;
                                  _selected.add(row.bookId);
                                }),
                              ),
                            );
                          },
                        ),
                ),
              ],
            );
            if (width >= 800) {
              body = Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: body,
                ),
              );
            }
            return body;
          },
        ),
      ),
    );
  }
}
