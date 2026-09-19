import 'package:ishamela/core/format_bytes.dart';

/// Visual / content state for the themed download snackbar (SPEC-020 SB).
enum DownloadSnackPhase { progress, complete, failed, alreadyInstalled }

class DownloadSnackState {
  const DownloadSnackState({
    required this.phase,
    required this.bookIds,
    required this.primaryTitle,
    this.bytesDone = 0,
    this.bytesTotal,
    this.indeterminate = true,
  });

  final DownloadSnackPhase phase;
  final List<int> bookIds;
  final String primaryTitle;
  final int bytesDone;
  final int? bytesTotal;
  final bool indeterminate;

  int get count => bookIds.length;

  double? get progress {
    if (indeterminate || bytesTotal == null || bytesTotal! <= 0) return null;
    return (bytesDone / bytesTotal!).clamp(0.0, 1.0);
  }

  String progressCaption() {
    if (indeterminate || bytesTotal == null) return '…';
    final pct = ((bytesDone / bytesTotal!) * 100).round();
    return '$pct٪ · ${formatBytes(bytesDone)} / ${formatBytes(bytesTotal!)}';
  }
}

/// Coalesce a new enqueue into the visible snackbar (SPEC-020 SB-03).
DownloadSnackState coalesceEnqueue({
  required DownloadSnackState? current,
  required int bookId,
  required String title,
}) {
  if (current == null ||
      current.phase != DownloadSnackPhase.progress ||
      current.bookIds.isEmpty) {
    return DownloadSnackState(
      phase: DownloadSnackPhase.progress,
      bookIds: [bookId],
      primaryTitle: title,
    );
  }
  if (current.bookIds.contains(bookId)) return current;
  final ids = [...current.bookIds, bookId];
  return DownloadSnackState(
    phase: DownloadSnackPhase.progress,
    bookIds: ids,
    primaryTitle: current.primaryTitle,
    bytesDone: current.bytesDone,
    bytesTotal: current.bytesTotal,
    indeterminate: current.indeterminate,
  );
}

DownloadSnackState alreadyInstalledSnack({
  required int bookId,
  required String title,
}) {
  return DownloadSnackState(
    phase: DownloadSnackPhase.alreadyInstalled,
    bookIds: [bookId],
    primaryTitle: title,
    indeterminate: false,
  );
}

DownloadSnackState completeSnack({
  required int bookId,
  required String title,
}) {
  return DownloadSnackState(
    phase: DownloadSnackPhase.complete,
    bookIds: [bookId],
    primaryTitle: title,
    indeterminate: false,
  );
}

DownloadSnackState failedSnack({
  required int bookId,
  required String title,
}) {
  return DownloadSnackState(
    phase: DownloadSnackPhase.failed,
    bookIds: [bookId],
    primaryTitle: title,
    indeterminate: false,
  );
}

DownloadSnackState withLiveProgress(
  DownloadSnackState state, {
  required int bytesDone,
  int? bytesTotal,
}) {
  if (state.phase != DownloadSnackPhase.progress) return state;
  final known = bytesTotal != null && bytesTotal > 0;
  return DownloadSnackState(
    phase: state.phase,
    bookIds: state.bookIds,
    primaryTitle: state.primaryTitle,
    bytesDone: bytesDone,
    bytesTotal: bytesTotal,
    indeterminate: !known,
  );
}
