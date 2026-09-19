import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ishamela/l10n/app_localizations.dart';

import 'package:ishamela/core/models/models.dart';
import 'package:ishamela/core/providers.dart';
import 'package:ishamela/features/downloads/download_service.dart';
import 'package:ishamela/features/downloads/download_snack_state.dart';
import 'package:ishamela/features/downloads/enqueue_result.dart';
import 'package:ishamela/features/reader/reader_page.dart';
import 'package:ishamela/ui/theme/ishamela_theme.dart';
import 'package:ishamela/ui/theme/ishamela_tokens.dart';
import 'package:ishamela/ui/theme/reader_theme_tokens.dart';

/// App-wide themed download snackbar host (SPEC-020 SB-06).
class DownloadSnackController extends Notifier<DownloadSnackState?> {
  Timer? _hide;
  final Map<int, DateTime> _debounce = {};

  @override
  DownloadSnackState? build() {
    ref.onDispose(() => _hide?.cancel());
    return null;
  }

  bool _debounced(int bookId) {
    final now = DateTime.now();
    final prev = _debounce[bookId];
    _debounce[bookId] = now;
    if (prev != null && now.difference(prev) < const Duration(milliseconds: 300)) {
      return true;
    }
    return false;
  }

  Future<EnqueueResult> enqueueBook(int bookId) async {
    if (_debounced(bookId)) return EnqueueResult.alreadyQueued;
    final svc = await ref.read(downloadServiceProvider.future);
    final catalog = await ref.read(catalogRepositoryProvider.future);
    final book = catalog.bookById(bookId);
    final title = book?.title ?? 'book_$bookId';
    final result = await svc.enqueue(bookId);
    switch (result) {
      case EnqueueResult.started:
        state = coalesceEnqueue(
          current: state,
          bookId: bookId,
          title: title,
        );
        _armHide(const Duration(seconds: 4));
        _watchProgress(bookId);
      case EnqueueResult.alreadyInstalled:
        state = alreadyInstalledSnack(bookId: bookId, title: title);
        _armHide(const Duration(seconds: 4));
      case EnqueueResult.alreadyQueued:
      case EnqueueResult.rejected:
        break;
    }
    return result;
  }

  void _watchProgress(int bookId) {
    // Poll lightly via download service listener for the visible snack lifetime.
    ref.read(downloadServiceProvider).whenData((svc) {
      void tick() {
        final cur = state;
        if (cur == null || cur.phase != DownloadSnackPhase.progress) return;
        if (!cur.bookIds.contains(bookId)) return;
        final tasks = svc.listTasks().where((t) => t.bookId == bookId);
        if (tasks.isEmpty) return;
        final t = tasks.first;
        if (t.status == DownloadStatus.done) {
          final catalog = ref.read(catalogRepositoryProvider).maybeWhen(
                data: (c) => c,
                orElse: () => null,
              );
          final title =
              catalog?.bookById(bookId)?.title ?? cur.primaryTitle;
          state = completeSnack(bookId: bookId, title: title);
          _armHide(const Duration(seconds: 3));
          return;
        }
        if (t.status == DownloadStatus.error) {
          final catalog = ref.read(catalogRepositoryProvider).maybeWhen(
                data: (c) => c,
                orElse: () => null,
              );
          final title =
              catalog?.bookById(bookId)?.title ?? cur.primaryTitle;
          state = failedSnack(bookId: bookId, title: title);
          _armHide(const Duration(seconds: 4));
          return;
        }
        state = withLiveProgress(
          cur,
          bytesDone: t.bytesDone,
          bytesTotal: t.bytesTotal,
        );
      }

      svc.addListener(tick);
      ref.onDispose(() => svc.removeListener(tick));
    });
  }

  void _armHide(Duration d) {
    _hide?.cancel();
    _hide = Timer(d, () {
      state = null;
    });
  }

  void dismiss() {
    _hide?.cancel();
    state = null;
  }

  Future<void> retry(int bookId) async {
    dismiss();
    await enqueueBook(bookId);
  }
}

final downloadSnackProvider =
    NotifierProvider<DownloadSnackController, DownloadSnackState?>(
  DownloadSnackController.new,
);

/// Overlay that paints the themed snackbar above bottom chrome (SPEC-020 SB-01).
class DownloadSnackHost extends ConsumerWidget {
  const DownloadSnackHost({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snack = ref.watch(downloadSnackProvider);
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    // Above bottom nav (~64) or reader chrome; keep 16 margin.
    final lift = bottomInset + 72;

    return Stack(
      children: [
        child,
        if (snack != null)
          Positioned(
            left: 16,
            right: 16,
            bottom: lift,
            child: _DownloadSnackBar(state: snack),
          ),
      ],
    );
  }
}

class _DownloadSnackBar extends ConsumerWidget {
  const _DownloadSnackBar({required this.state});

  final DownloadSnackState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final t = IshamelaTokens.of(context);
    final night =
        ReaderThemeTokens.of(context).atmosphere == ReadingAtmosphere.night;
    final bg = night ? const Color(0xFF1B2A24) : t.green900;
    final paper = const Color(0xFFF2E8CF);
    final errorTint = const Color(0xFFE08A76);
    final reduce = MediaQuery.disableAnimationsOf(context);

    final (String message, String actionLabel, VoidCallback onAction, IconData icon, Color accent) =
        switch (state.phase) {
      DownloadSnackPhase.progress => (
          state.count > 1
              ? l10n.downloadingNBooks(state.count)
              : l10n.downloadingBook(state.primaryTitle),
          l10n.viewDownloads,
          () {
            ref.read(homeTabIndexProvider.notifier).go(2);
            ref.read(downloadSnackProvider.notifier).dismiss();
          },
          Icons.download,
          t.goldSoft,
        ),
      DownloadSnackPhase.complete => (
          l10n.downloadCompleteSnack(state.primaryTitle),
          l10n.open,
          () {
            final id = state.bookIds.first;
            ref.read(downloadSnackProvider.notifier).dismiss();
            ReaderPage.open(
              context,
              bookId: id,
              title: state.primaryTitle,
            );
          },
          Icons.check_circle_outline,
          t.goldSoft,
        ),
      DownloadSnackPhase.failed => (
          l10n.downloadFailedSnack(state.primaryTitle),
          l10n.retry,
          () => ref
              .read(downloadSnackProvider.notifier)
              .retry(state.bookIds.first),
          Icons.error_outline,
          errorTint,
        ),
      DownloadSnackPhase.alreadyInstalled => (
          l10n.alreadyInstalled(state.primaryTitle),
          l10n.open,
          () {
            final id = state.bookIds.first;
            ref.read(downloadSnackProvider.notifier).dismiss();
            ReaderPage.open(
              context,
              bookId: id,
              title: state.primaryTitle,
            );
          },
          Icons.check,
          t.goldSoft,
        ),
    };

    final bar = Material(
      color: bg,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(icon, color: accent, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    message,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: kFontUi,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: paper,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: onAction,
                  child: Text(
                    actionLabel,
                    style: TextStyle(
                      fontFamily: kFontUi,
                      fontWeight: FontWeight.w700,
                      color: accent,
                    ),
                  ),
                ),
              ],
            ),
            if (state.phase == DownloadSnackPhase.progress) ...[
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: state.progress,
                  minHeight: 3,
                  backgroundColor: const Color(0xFF1E5040),
                  color: t.goldSoft,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                state.progressCaption(),
                style: TextStyle(
                  fontFamily: kFontUi,
                  fontSize: 11,
                  color: paper.withValues(alpha: 0.75),
                ),
              ),
            ],
          ],
        ),
      ),
    );

    return Semantics(
      liveRegion: true,
      label: message,
      child: reduce
          ? bar
          : TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 180),
              builder: (context, v, child) => Opacity(opacity: v, child: child),
              child: bar,
            ),
    );
  }
}
