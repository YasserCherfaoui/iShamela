import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ishamela/l10n/app_localizations.dart';

import 'package:ishamela/core/format_bytes.dart';
import 'package:ishamela/core/models/models.dart';
import 'package:ishamela/core/providers.dart';
import 'package:ishamela/features/downloads/download_service.dart';
import 'package:ishamela/features/downloads/download_tabs.dart';
import 'package:ishamela/features/reader/reader_page.dart';
import 'package:ishamela/ui/download_card.dart';
import 'package:ishamela/ui/empty_state.dart';
import 'package:ishamela/ui/section_label.dart';
import 'package:ishamela/ui/segmented_pills.dart';
import 'package:ishamela/ui/theme/ishamela_theme.dart';
import 'package:ishamela/ui/theme/ishamela_tokens.dart';
import 'package:ishamela/ui/tonal_icon_button.dart';

class DownloadsPage extends ConsumerStatefulWidget {
  const DownloadsPage({super.key});

  @override
  ConsumerState<DownloadsPage> createState() => _DownloadsPageState();
}

class _DownloadsPageState extends ConsumerState<DownloadsPage> {
  DownloadService? _svc;
  int _tabIndex = 0;
  bool _selecting = false;
  final Set<int> _selected = {};

  @override
  void dispose() {
    _svc?.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  DownloadsTab get _currentTab {
    switch (_tabIndex) {
      case 1:
        return DownloadsTab.failed;
      case 2:
        return DownloadsTab.completed;
      default:
        return DownloadsTab.active;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final t = IshamelaTokens.of(context);
    final svcAsync = ref.watch(downloadServiceProvider);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: svcAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('$e')),
          data: (svc) {
            if (_svc != svc) {
              _svc?.removeListener(_onChange);
              _svc = svc;
              _svc!.addListener(_onChange);
            }
            final all = svc.listTasks();
            final active =
                filterDownloadTasks(all, DownloadsTab.active).length;
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              l10n.tabDownloads,
                              style: TextStyle(
                                fontFamily: kFontAmiri,
                                fontWeight: FontWeight.w700,
                                fontSize: 26,
                                color: t.ink,
                              ),
                            ),
                          ),
                          if (_selecting) ...[
                            IconButton(
                              tooltip: l10n.selectAll,
                              icon: const Icon(Icons.select_all),
                              onPressed: () {
                                final tasks = filterDownloadTasks(
                                  svc.listTasks(),
                                  _currentTab,
                                );
                                setState(() {
                                  _selected
                                    ..clear()
                                    ..addAll(tasks.map((x) => x.bookId));
                                });
                              },
                            ),
                            ..._bulkActions(l10n, svc),
                            IconButton(
                              tooltip: l10n.cancel,
                              icon: const Icon(Icons.close),
                              onPressed: () => setState(() {
                                _selecting = false;
                                _selected.clear();
                              }),
                            ),
                          ] else
                            IconButton(
                              tooltip: l10n.select,
                              icon: const Icon(Icons.checklist),
                              onPressed: () =>
                                  setState(() => _selecting = true),
                            ),
                        ],
                      ),
                      if (active > 0)
                        Text(
                          l10n.activeDownloadsCount(active),
                          style: TextStyle(
                            fontFamily: kFontUi,
                            color: t.muted,
                            fontSize: 12,
                          ),
                        ),
                      const SizedBox(height: 12),
                      SegmentedPills(
                        labels: [
                          l10n.downloadsActive,
                          l10n.downloadsFailed,
                          l10n.downloadsCompleted,
                        ],
                        selectedIndex: _tabIndex,
                        onChanged: (i) => setState(() {
                          _tabIndex = i;
                          _selected.clear();
                          _selecting = false;
                        }),
                      ),
                    ],
                  ),
                ),
                Expanded(child: _taskList(l10n, svc, _currentTab)),
              ],
            );
          },
        ),
      ),
    );
  }

  List<Widget> _bulkActions(AppLocalizations l10n, DownloadService svc) {
    if (_selected.isEmpty) return const [];
    final ids = _selected.toList();
    switch (_currentTab) {
      case DownloadsTab.active:
        return [
          IconButton(
            tooltip: l10n.pause,
            icon: const Icon(Icons.pause),
            onPressed: () async {
              await svc.pauseMany(ids);
              setState(() {
                _selected.clear();
                _selecting = false;
              });
            },
          ),
          IconButton(
            tooltip: l10n.resume,
            icon: const Icon(Icons.play_arrow),
            onPressed: () async {
              await svc.resumeMany(ids);
              setState(() {
                _selected.clear();
                _selecting = false;
              });
            },
          ),
          IconButton(
            tooltip: l10n.cancel,
            icon: const Icon(Icons.close),
            onPressed: () async {
              await svc.cancelMany(ids);
              setState(() {
                _selected.clear();
                _selecting = false;
              });
            },
          ),
        ];
      case DownloadsTab.failed:
        return [
          IconButton(
            tooltip: l10n.redownload,
            icon: const Icon(Icons.refresh),
            onPressed: () async {
              await svc.redownloadMany(ids);
              setState(() {
                _selected.clear();
                _selecting = false;
              });
            },
          ),
          IconButton(
            tooltip: l10n.cancel,
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              await svc.cancelMany(ids);
              setState(() {
                _selected.clear();
                _selecting = false;
              });
            },
          ),
        ];
      case DownloadsTab.completed:
        return [
          IconButton(
            tooltip: l10n.redownload,
            icon: const Icon(Icons.refresh),
            onPressed: () async {
              await svc.redownloadMany(ids);
              setState(() {
                _selected.clear();
                _selecting = false;
              });
            },
          ),
          IconButton(
            tooltip: l10n.delete,
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              final ok = await _confirmDelete(l10n);
              if (ok != true) return;
              await svc.deleteInstalledMany(ids);
              setState(() {
                _selected.clear();
                _selecting = false;
              });
            },
          ),
        ];
    }
  }

  Future<bool?> _confirmDelete(AppLocalizations l10n) {
    final t = IshamelaTokens.of(context);
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: t.card,
        title: Text(
          l10n.delete,
          style: TextStyle(
            fontFamily: kFontAmiri,
            fontWeight: FontWeight.w700,
            color: t.ink,
          ),
        ),
        content: Text(l10n.confirmBulkDelete),
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
  }

  Widget _taskList(
    AppLocalizations l10n,
    DownloadService svc,
    DownloadsTab tab,
  ) {
    final tasks = filterDownloadTasks(svc.listTasks(), tab);
    if (tasks.isEmpty) {
      return EmptyState(message: l10n.downloadsEmpty);
    }
    final catalog = ref.watch(catalogRepositoryProvider).maybeWhen(
          data: (c) => c,
          orElse: () => null,
        );

    final todayStart = DateTime.now();
    final startMs = DateTime(todayStart.year, todayStart.month, todayStart.day)
        .millisecondsSinceEpoch;
    final todayDone = tab == DownloadsTab.completed
        ? tasks.where((t) => t.updatedAt >= startMs).toList()
        : const <DownloadTask>[];
    final rest = tab == DownloadsTab.completed
        ? tasks.where((t) => t.updatedAt < startMs).toList()
        : tasks;

    Widget cardFor(DownloadTask task) {
      final book = catalog?.bookById(task.bookId);
      final title = book?.title ?? 'book_${task.bookId}';
      final showBar = showDownloadProgress(task.status) &&
          task.bytesTotal != null &&
          task.bytesTotal! > 0;
      final progress =
          showBar ? (task.bytesDone / task.bytesTotal!).clamp(0.0, 1.0) : null;
      final tone = switch (task.status) {
        DownloadStatus.paused => DownloadCardTone.paused,
        DownloadStatus.error => DownloadCardTone.failed,
        DownloadStatus.done => DownloadCardTone.completed,
        _ => DownloadCardTone.active,
      };
      String? caption;
      if (showBar && task.bytesTotal != null) {
        caption =
            '${formatBytes(task.bytesDone)} / ${formatBytes(task.bytesTotal!)}';
      }

      Widget? primary;
      Widget? secondary;
      if (task.status == DownloadStatus.downloading ||
          task.status == DownloadStatus.queued ||
          task.status == DownloadStatus.verifying ||
          task.status == DownloadStatus.installing) {
        primary = TonalIconButton(
          tooltip: l10n.pause,
          icon: Icons.pause,
          onPressed: () => svc.pause(task.bookId),
        );
        secondary = TonalIconButton(
          tooltip: l10n.cancel,
          icon: Icons.close,
          onPressed: () => svc.cancel(task.bookId),
        );
      } else if (task.status == DownloadStatus.paused) {
        primary = TonalIconButton(
          tooltip: l10n.resume,
          icon: Icons.play_arrow,
          onPressed: () => svc.resume(task.bookId),
        );
        secondary = TonalIconButton(
          tooltip: l10n.cancel,
          icon: Icons.close,
          onPressed: () => svc.cancel(task.bookId),
        );
      } else if (task.status == DownloadStatus.error) {
        primary = TonalIconButton(
          tooltip: l10n.redownload,
          icon: Icons.refresh,
          onPressed: () => svc.redownload(task.bookId),
        );
        secondary = TonalIconButton(
          tooltip: l10n.cancel,
          icon: Icons.close,
          onPressed: () => svc.cancel(task.bookId),
        );
      } else if (task.status == DownloadStatus.done) {
        primary = TonalIconButton(
          tooltip: l10n.openBook,
          icon: Icons.menu_book,
          onPressed: () => ReaderPage.open(
            context,
            bookId: task.bookId,
            title: book?.title,
            authorName: book?.authorName,
          ),
        );
        secondary = TonalIconButton(
          tooltip: l10n.delete,
          icon: Icons.delete_outline,
          onPressed: () async {
            final ok = await _confirmDelete(l10n);
            if (ok == true) await svc.deleteInstalled(task.bookId);
          },
        );
      }

      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: DownloadCard(
          title: title,
          statusLabel: _statusLabel(l10n, task.status),
          tone: tone,
          progress: progress,
          caption: caption,
          errorText: tab == DownloadsTab.failed ? task.error : null,
          primaryAction: primary,
          secondaryAction: secondary,
          selected: _selecting ? _selected.contains(task.bookId) : null,
          onSelectedChanged: _selecting
              ? (_) => setState(() {
                    if (_selected.contains(task.bookId)) {
                      _selected.remove(task.bookId);
                    } else {
                      _selected.add(task.bookId);
                    }
                  })
              : null,
          onTap: task.status == DownloadStatus.done
              ? () => ReaderPage.open(
                    context,
                    bookId: task.bookId,
                    title: book?.title,
                    authorName: book?.authorName,
                  )
              : null,
          onLongPress: () => setState(() {
            _selecting = true;
            _selected.add(task.bookId);
          }),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      children: [
        if (todayDone.isNotEmpty) ...[
          SectionLabel(label: l10n.completedToday),
          for (final t in todayDone) cardFor(t),
          if (rest.isNotEmpty) const SizedBox(height: 8),
        ],
        for (final t in rest) cardFor(t),
      ],
    );
  }

  String _statusLabel(AppLocalizations l10n, DownloadStatus s) {
    switch (s) {
      case DownloadStatus.queued:
        return l10n.statusQueued;
      case DownloadStatus.downloading:
        return l10n.statusDownloading;
      case DownloadStatus.verifying:
        return l10n.statusVerifying;
      case DownloadStatus.installing:
        return l10n.statusInstalling;
      case DownloadStatus.done:
        return l10n.statusDone;
      case DownloadStatus.error:
        return l10n.statusError;
      case DownloadStatus.paused:
        return l10n.statusPaused;
    }
  }
}
