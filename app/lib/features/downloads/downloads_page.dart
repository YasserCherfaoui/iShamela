import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ishamela/l10n/app_localizations.dart';

import 'package:ishamela/core/models/models.dart';
import 'package:ishamela/core/providers.dart';
import 'package:ishamela/features/downloads/download_service.dart';

class DownloadsPage extends ConsumerStatefulWidget {
  const DownloadsPage({super.key});

  @override
  ConsumerState<DownloadsPage> createState() => _DownloadsPageState();
}

class _DownloadsPageState extends ConsumerState<DownloadsPage> {
  DownloadService? _svc;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final svcAsync = ref.watch(downloadServiceProvider);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: Text(l10n.tabDownloads)),
        body: svcAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('$e')),
          data: (svc) {
            if (_svc != svc) {
              _svc?.removeListener(_onChange);
              _svc = svc;
              _svc!.addListener(_onChange);
            }
            final tasks = svc.listTasks();
            if (tasks.isEmpty) {
              return Center(child: Text(l10n.noBooks));
            }
            return ListView.builder(
              itemCount: tasks.length,
              itemBuilder: (context, i) {
                final t = tasks[i];
                final progress = t.bytesTotal == null || t.bytesTotal == 0
                    ? null
                    : t.bytesDone / t.bytesTotal!;
                return ListTile(
                  title: Text('book_${t.bookId}'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_statusLabel(l10n, t.status)),
                      if (progress != null)
                        LinearProgressIndicator(value: progress.clamp(0, 1)),
                      if (t.error != null)
                        Text(t.error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                    ],
                  ),
                  isThreeLine: true,
                  trailing: Wrap(
                    children: [
                      if (t.status == DownloadStatus.downloading ||
                          t.status == DownloadStatus.queued)
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
          },
        ),
      ),
    );
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _svc?.removeListener(_onChange);
    super.dispose();
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
