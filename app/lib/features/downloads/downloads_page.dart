import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ishamela/l10n/app_localizations.dart';

import 'package:ishamela/core/models/models.dart';
import 'package:ishamela/core/providers.dart';
import 'package:ishamela/features/downloads/download_service.dart';
import 'package:ishamela/features/downloads/download_tabs.dart';
import 'package:ishamela/features/reader/reader_page.dart';

class DownloadsPage extends ConsumerStatefulWidget {
  const DownloadsPage({super.key});

  @override
  ConsumerState<DownloadsPage> createState() => _DownloadsPageState();
}

class _DownloadsPageState extends ConsumerState<DownloadsPage>
    with SingleTickerProviderStateMixin {
  DownloadService? _svc;
  late final TabController _tabs;
  bool _selecting = false;
  final Set<int> _selected = {};

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _tabs.addListener(() {
      if (_tabs.indexIsChanging) return;
      setState(() {
        _selected.clear();
        _selecting = false;
      });
    });
  }

  @override
  void dispose() {
    _svc?.removeListener(_onChange);
    _tabs.dispose();
    super.dispose();
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  DownloadsTab get _currentTab {
    switch (_tabs.index) {
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
    final svcAsync = ref.watch(downloadServiceProvider);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.tabDownloads),
          bottom: TabBar(
            controller: _tabs,
            tabs: [
              Tab(text: l10n.downloadsActive),
              Tab(text: l10n.downloadsFailed),
              Tab(text: l10n.downloadsCompleted),
            ],
          ),
          actions: [
            if (_selecting) ...[
              IconButton(
                tooltip: l10n.selectAll,
                icon: const Icon(Icons.select_all),
                onPressed: () {
                  final tasks = _visibleTasks(svcAsync);
                  setState(() {
                    _selected
                      ..clear()
                      ..addAll(tasks.map((t) => t.bookId));
                  });
                },
              ),
              IconButton(
                tooltip: l10n.deselectAll,
                icon: const Icon(Icons.deselect),
                onPressed: () => setState(() => _selected.clear()),
              ),
              ..._bulkActions(l10n, svcAsync),
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
                onPressed: () => setState(() => _selecting = true),
              ),
          ],
        ),
        body: svcAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('$e')),
          data: (svc) {
            if (_svc != svc) {
              _svc?.removeListener(_onChange);
              _svc = svc;
              _svc!.addListener(_onChange);
            }
            return TabBarView(
              controller: _tabs,
              children: [
                _taskList(l10n, svc, DownloadsTab.active),
                _taskList(l10n, svc, DownloadsTab.failed),
                _taskList(l10n, svc, DownloadsTab.completed),
              ],
            );
          },
        ),
      ),
    );
  }

  List<DownloadTask> _visibleTasks(AsyncValue<DownloadService> svcAsync) {
    final svc = svcAsync.maybeWhen(data: (s) => s, orElse: () => null);
    if (svc == null) return const [];
    return filterDownloadTasks(svc.listTasks(), _currentTab);
  }

  List<Widget> _bulkActions(
    AppLocalizations l10n,
    AsyncValue<DownloadService> svcAsync,
  ) {
    final svc = svcAsync.maybeWhen(data: (s) => s, orElse: () => null);
    if (svc == null || _selected.isEmpty) return const [];
    final tab = _currentTab;
    final ids = _selected.toList();
    switch (tab) {
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
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.delete),
        content: Text(l10n.confirmBulkDelete),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.confirm),
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
      return Center(child: Text(l10n.downloadsEmpty));
    }
    final catalog = ref.watch(catalogRepositoryProvider).maybeWhen(
          data: (c) => c,
          orElse: () => null,
        );

    return ListView.builder(
      itemCount: tasks.length,
      itemBuilder: (context, i) {
        final t = tasks[i];
        final book = catalog?.bookById(t.bookId);
        final title = book?.title ?? 'book_${t.bookId}';
        final showBar = showDownloadProgress(t.status) &&
            t.bytesTotal != null &&
            t.bytesTotal! > 0;
        final progress =
            showBar ? (t.bytesDone / t.bytesTotal!).clamp(0.0, 1.0) : null;

        if (_selecting) {
          return CheckboxListTile(
            value: _selected.contains(t.bookId),
            onChanged: (_) => setState(() {
              if (_selected.contains(t.bookId)) {
                _selected.remove(t.bookId);
              } else {
                _selected.add(t.bookId);
              }
            }),
            title: Text(title),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_statusLabel(l10n, t.status)),
                if (progress != null) LinearProgressIndicator(value: progress),
                if (t.error != null && tab == DownloadsTab.failed)
                  Text(
                    t.error!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
              ],
            ),
            isThreeLine: progress != null || t.error != null,
          );
        }

        return ListTile(
          title: Text(title),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_statusLabel(l10n, t.status)),
              if (progress != null) LinearProgressIndicator(value: progress),
              if (t.error != null && tab == DownloadsTab.failed)
                Text(
                  t.error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
            ],
          ),
          isThreeLine: progress != null || t.error != null,
          onLongPress: () => setState(() {
            _selecting = true;
            _selected.add(t.bookId);
          }),
          onTap: t.status == DownloadStatus.done
              ? () => ReaderPage.open(
                    context,
                    bookId: t.bookId,
                    title: book?.title,
                    authorName: book?.authorName,
                  )
              : null,
          trailing: Wrap(
            children: [
              if (t.status == DownloadStatus.downloading ||
                  t.status == DownloadStatus.queued ||
                  t.status == DownloadStatus.verifying ||
                  t.status == DownloadStatus.installing)
                IconButton(
                  tooltip: l10n.pause,
                  icon: const Icon(Icons.pause),
                  onPressed: () => svc.pause(t.bookId),
                ),
              if (t.status == DownloadStatus.paused)
                IconButton(
                  tooltip: l10n.resume,
                  icon: const Icon(Icons.play_arrow),
                  onPressed: () => svc.resume(t.bookId),
                ),
              if (t.status == DownloadStatus.error ||
                  t.status == DownloadStatus.done)
                IconButton(
                  tooltip: l10n.redownload,
                  icon: const Icon(Icons.refresh),
                  onPressed: () => svc.redownload(t.bookId),
                ),
              if (t.status == DownloadStatus.done)
                IconButton(
                  tooltip: l10n.openBook,
                  icon: const Icon(Icons.menu_book),
                  onPressed: () => ReaderPage.open(
                    context,
                    bookId: t.bookId,
                    title: book?.title,
                    authorName: book?.authorName,
                  ),
                ),
              if (t.status == DownloadStatus.done)
                IconButton(
                  tooltip: l10n.delete,
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () async {
                    final ok = await _confirmDelete(l10n);
                    if (ok == true) await svc.deleteInstalled(t.bookId);
                  },
                )
              else
                IconButton(
                  tooltip: l10n.cancel,
                  icon: const Icon(Icons.close),
                  onPressed: () => svc.cancel(t.bookId),
                ),
            ],
          ),
        );
      },
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
