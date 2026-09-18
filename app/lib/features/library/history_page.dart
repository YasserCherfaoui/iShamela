import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ishamela/l10n/app_localizations.dart';

import 'package:ishamela/core/db/state_database.dart';
import 'package:ishamela/core/models/models.dart';
import 'package:ishamela/core/providers.dart';
import 'package:ishamela/features/reader/reader_page.dart';
import 'package:ishamela/ui/book_card.dart';
import 'package:ishamela/ui/empty_state.dart';
import 'package:ishamela/ui/section_label.dart';
import 'package:ishamela/ui/theme/ishamela_theme.dart';
import 'package:ishamela/ui/theme/ishamela_tokens.dart';
import 'package:ishamela/ui/tonal_icon_button.dart';

/// SPEC-014 reading history screen.
class HistoryPage extends ConsumerStatefulWidget {
  const HistoryPage({super.key});

  static Future<void> open(BuildContext context) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const HistoryPage()),
    );
  }

  @override
  ConsumerState<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends ConsumerState<HistoryPage> {
  int _tick = 0;

  Future<void> _clear(AppLocalizations l10n, StateDatabase state) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.historyClear),
        content: Text(l10n.historyClearConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              l10n.confirm,
              style: const TextStyle(color: Color(0xFFA6402E)),
            ),
          ),
        ],
      ),
    );
    if (ok == true) {
      state.clearReadingHistory();
      setState(() => _tick++);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final t = IshamelaTokens.of(context);
    final width = MediaQuery.sizeOf(context).width;
    final stateAsync = ref.watch(stateDatabaseProvider);
    final catalogAsync = ref.watch(catalogRepositoryProvider);
    final downloadsAsync = ref.watch(downloadServiceProvider);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            l10n.historyTitle,
            style: TextStyle(
              fontFamily: kFontAmiri,
              fontWeight: FontWeight.w700,
              fontSize: 22,
              color: t.ink,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                final state = stateAsync.maybeWhen(
                  data: (s) => s,
                  orElse: () => null,
                );
                if (state != null) _clear(l10n, state);
              },
              child: Text(
                l10n.historyClear,
                style: const TextStyle(color: Color(0xFFA6402E)),
              ),
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
            final entries = state.listReadingHistory();
            if (entries.isEmpty) {
              return EmptyState(message: l10n.historyEmpty);
            }
            final groups = groupHistoryByDay(entries, DateTime.now());
            final list = ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              children: [
                for (final g in groups) ...[
                  SectionLabel(label: _dayLabel(l10n, g.key)),
                  for (final e in g.entries)
                    _HistoryRow(
                      entry: e,
                      book: catalog?.bookById(e.bookId),
                      installed: state.isInstalled(e.bookId),
                      onRemoved: () => setState(() => _tick++),
                      onEnqueue: () async {
                        final svc = downloadsAsync.maybeWhen(
                          data: (s) => s,
                          orElse: () => null,
                        );
                        await svc?.enqueue(e.bookId);
                        setState(() => _tick++);
                      },
                    ),
                ],
              ],
            );
            if (width >= 800) {
              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: list,
                ),
              );
            }
            return list;
          },
        ),
      ),
    );
  }

  String _dayLabel(AppLocalizations l10n, HistoryDayBucket b) {
    switch (b) {
      case HistoryDayBucket.today:
        return l10n.today;
      case HistoryDayBucket.yesterday:
        return l10n.yesterday;
      case HistoryDayBucket.thisWeek:
        return l10n.thisWeek;
      case HistoryDayBucket.older:
        return l10n.older;
    }
  }
}

enum HistoryDayBucket { today, yesterday, thisWeek, older }

class HistoryDayGroup {
  HistoryDayGroup(this.key, this.entries);
  final HistoryDayBucket key;
  final List<ReadingHistoryEntry> entries;
}

/// Groups history rows by local calendar day buckets (SPEC-014).
List<HistoryDayGroup> groupHistoryByDay(
  List<ReadingHistoryEntry> entries,
  DateTime now,
) {
  final today = DateTime(now.year, now.month, now.day);
  final yesterday = today.subtract(const Duration(days: 1));
  final weekFloor = today.subtract(const Duration(days: 6));
  final map = <HistoryDayBucket, List<ReadingHistoryEntry>>{};
  for (final e in entries) {
    final d = DateTime.fromMillisecondsSinceEpoch(e.openedAt);
    final day = DateTime(d.year, d.month, d.day);
    HistoryDayBucket bucket;
    if (day == today) {
      bucket = HistoryDayBucket.today;
    } else if (day == yesterday) {
      bucket = HistoryDayBucket.yesterday;
    } else if (!day.isBefore(weekFloor)) {
      bucket = HistoryDayBucket.thisWeek;
    } else {
      bucket = HistoryDayBucket.older;
    }
    map.putIfAbsent(bucket, () => []).add(e);
  }
  return [
    for (final b in HistoryDayBucket.values)
      if (map[b] != null && map[b]!.isNotEmpty) HistoryDayGroup(b, map[b]!),
  ];
}

String relativeOpenedLabel(int openedAtMs, DateTime now) {
  final diff = now.difference(DateTime.fromMillisecondsSinceEpoch(openedAtMs));
  if (diff.inMinutes < 1) return '…';
  if (diff.inHours < 1) return '${diff.inMinutes}m';
  if (diff.inHours < 24) return '${diff.inHours}h';
  if (diff.inDays < 7) return '${diff.inDays}d';
  return '${diff.inDays}d';
}

class _HistoryRow extends ConsumerWidget {
  const _HistoryRow({
    required this.entry,
    required this.book,
    required this.installed,
    required this.onRemoved,
    required this.onEnqueue,
  });

  final ReadingHistoryEntry entry;
  final Book? book;
  final bool installed;
  final VoidCallback onRemoved;
  final Future<void> Function() onEnqueue;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final title = book?.title ?? 'book_${entry.bookId}';
    final printNo = entry.printPage?.toString() ?? '—';
    final line2 = [
      if (entry.sectionTitle != null && entry.sectionTitle!.isNotEmpty)
        entry.sectionTitle!,
      if (entry.part != null && entry.part!.isNotEmpty) 'ج${entry.part}',
      'ص$printNo',
    ].join(' · ');
    final caption = relativeOpenedLabel(
      entry.openedAt,
      DateTime.now(),
    );

    Widget? trailing;
    if (!installed) {
      trailing = TonalIconButton(
        tooltip: l10n.download,
        icon: Icons.download,
        onPressed: () => onEnqueue(),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: BookCard(
        title: title,
        categoryId: book?.categoryId ?? 0,
        author: line2.isEmpty ? null : line2,
        meta: [
          caption,
          if (!installed) l10n.notInstalled,
        ],
        available: installed,
        unavailableLabel: installed ? null : l10n.notInstalled,
        trailing: trailing ??
            PopupMenuButton<String>(
              onSelected: (v) async {
                final state = await ref.read(stateDatabaseProvider.future);
                if (v == 'remove') {
                  state.deleteReadingHistory(entry.id);
                  onRemoved();
                } else if (v == 'card' && book != null && context.mounted) {
                  await showDialog<void>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: Text(book!.title),
                      content: Text(
                        book!.betakaText?.trim().isNotEmpty == true
                            ? book!.betakaText!
                            : (book!.authorName ?? ''),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: Text(l10n.cancel),
                        ),
                      ],
                    ),
                  );
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'remove',
                  child: Text(l10n.removeFromHistory),
                ),
                PopupMenuItem(value: 'card', child: Text(l10n.bookCard)),
              ],
            ),
        onTap: installed
            ? () => ReaderPage.open(
                  context,
                  bookId: entry.bookId,
                  title: book?.title,
                  authorName: book?.authorName,
                  initialPageId: entry.pageId,
                  initialPrintPage: entry.printPage,
                )
            : null,
      ),
    );
  }
}
