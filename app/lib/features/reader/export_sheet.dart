import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ishamela/l10n/app_localizations.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'package:ishamela/core/providers.dart';
import 'package:ishamela/features/reader/annotations_export.dart';
import 'package:ishamela/features/reader/book_database.dart';
import 'package:ishamela/ui/segmented_pills.dart';
import 'package:ishamela/ui/theme/ishamela_theme.dart';
import 'package:ishamela/ui/theme/ishamela_tokens.dart';

/// SPEC-019 export sheet.
Future<void> showAnnotationsExportSheet(
  BuildContext context, {
  required int bookId,
  required String title,
  String? authorName,
}) async {
  final container = ProviderScope.containerOf(context);
  final state = await container.read(stateDatabaseProvider.future);
  final highlights = state.highlightsForBook(bookId);
  final notes = state.notesForBook(bookId);
  if (!context.mounted) return;
  if (highlights.isEmpty && notes.isEmpty) return;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: IshamelaTokens.of(context).card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) => _ExportSheet(
      bookId: bookId,
      title: title,
      authorName: authorName,
      highlightCount: highlights.length,
      noteCount: notes.length,
    ),
  );
}

class _ExportSheet extends ConsumerStatefulWidget {
  const _ExportSheet({
    required this.bookId,
    required this.title,
    required this.authorName,
    required this.highlightCount,
    required this.noteCount,
  });

  final int bookId;
  final String title;
  final String? authorName;
  final int highlightCount;
  final int noteCount;

  @override
  ConsumerState<_ExportSheet> createState() => _ExportSheetState();
}

class _ExportSheetState extends ConsumerState<_ExportSheet> {
  int _formatIndex = 0; // 0 md, 1 txt
  late bool _includeHighlights;
  late bool _includeNotes;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _includeHighlights = widget.highlightCount > 0;
    _includeNotes = widget.noteCount > 0;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final t = IshamelaTokens.of(context);
    final canExport = (_includeHighlights && widget.highlightCount > 0) ||
        (_includeNotes && widget.noteCount > 0);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        20,
        24,
        24 + MediaQuery.paddingOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.title,
            style: TextStyle(
              fontFamily: kFontAmiri,
              fontWeight: FontWeight.w700,
              fontSize: 20,
              color: t.ink,
            ),
          ),
          if (widget.authorName != null && widget.authorName!.isNotEmpty)
            Text(
              widget.authorName!,
              style: TextStyle(
                fontFamily: kFontUi,
                fontSize: 13,
                color: t.muted,
              ),
            ),
          const SizedBox(height: 16),
          SegmentedPills(
            labels: [
              l10n.exportFormatMarkdown,
              l10n.exportFormatText,
            ],
            selectedIndex: _formatIndex,
            onChanged: (i) => setState(() => _formatIndex = i),
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              '${l10n.includeHighlights} ${widget.highlightCount}',
            ),
            value: _includeHighlights && widget.highlightCount > 0,
            onChanged: widget.highlightCount == 0
                ? null
                : (v) => setState(() => _includeHighlights = v),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('${l10n.includeNotes} ${widget.noteCount}'),
            value: _includeNotes && widget.noteCount > 0,
            onChanged: widget.noteCount == 0
                ? null
                : (v) => setState(() => _includeNotes = v),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: !canExport || _busy ? null : _export,
            child: Text(l10n.export),
          ),
        ],
      ),
    );
  }

  Future<void> _export() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    final arabic = Localizations.localeOf(context).languageCode == 'ar';
    setState(() => _busy = true);
    try {
      final state = await ref.read(stateDatabaseProvider.future);
      final paths = await ref.read(appPathsProvider.future);
      final now = DateTime.now();
      final format = _formatIndex == 0
          ? ExportFormat.markdown
          : ExportFormat.plainText;

      BookDatabase? db;
      final entries = <ExportAnnotation>[];
      String? edition;
      try {
        db = BookDatabase.open(paths, widget.bookId);
        edition = db.meta('betaka');
        if (edition != null && edition.length > 120) {
          edition = '${edition.substring(0, 117)}…';
        }
        final highlights = state.highlightsForBook(widget.bookId);
        final notes = state.notesForBook(widget.bookId);
        final notesByKey = <String, List<Map<String, Object?>>>{};
        for (final n in notes) {
          final key =
              '${n['page_id']}:${n['start_offset']}:${n['end_offset']}';
          notesByKey.putIfAbsent(key, () => []).add(n);
        }

        for (final h in highlights) {
          final pageId = h['page_id'] as int;
          final start = h['start_offset'] as int;
          final end = h['end_offset'] as int;
          final page = db.pageById(pageId);
          final body = page?.body ?? '';
          final excerpt = body.isEmpty
              ? ''
              : body.substring(
                  start.clamp(0, body.length),
                  end.clamp(0, body.length),
                );
          final citation = citationForAnnotation(
            excerpt: truncateAnchor(excerpt),
            title: widget.title,
            author: widget.authorName ?? '',
            part: page?.part,
            pageNumber: page?.pageNumber,
            arabic: arabic,
          );
          final key = '$pageId:$start:$end';
          final attached = notesByKey.remove(key);
          entries.add(
            ExportAnnotation(
              pageId: pageId,
              part: page?.part,
              printPage: page?.pageNumber,
              startOffset: start,
              endOffset: end,
              anchorExcerpt: excerpt,
              citationLine: citation,
              color: h['color'] as String?,
              noteBody: attached?.map((n) => n['note'] as String).join('\n'),
              isHighlight: true,
            ),
          );
        }
        for (final list in notesByKey.values) {
          for (final n in list) {
            final pageId = n['page_id'] as int;
            final start = n['start_offset'] as int;
            final end = n['end_offset'] as int;
            final page = db.pageById(pageId);
            final body = page?.body ?? '';
            final excerpt = body.isEmpty
                ? ''
                : body.substring(
                    start.clamp(0, body.length),
                    end.clamp(0, body.length),
                  );
            final citation = citationForAnnotation(
              excerpt: truncateAnchor(excerpt),
              title: widget.title,
              author: widget.authorName ?? '',
              part: page?.part,
              pageNumber: page?.pageNumber,
              arabic: arabic,
            );
            entries.add(
              ExportAnnotation(
                pageId: pageId,
                part: page?.part,
                printPage: page?.pageNumber,
                startOffset: start,
                endOffset: end,
                anchorExcerpt: excerpt,
                citationLine: citation,
                noteBody: n['note'] as String?,
                isHighlight: false,
              ),
            );
          }
        }
      } finally {
        db?.close();
      }

      final dateStr =
          '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final text = buildAnnotationsExport(
        title: widget.title,
        author: widget.authorName,
        entries: entries,
        options: AnnotationExportOptions(
          format: format,
          includeHighlights: _includeHighlights,
          includeNotes: _includeNotes,
          exportedOn: now,
          arabic: arabic,
        ),
        notesHeading: l10n.notesFileHeading(widget.title),
        exportedOnLabel: l10n.exportedOn(dateStr),
        noteLabel: l10n.noteLabel,
        edition: edition,
      );

      final dir = await getTemporaryDirectory();
      final name = exportFilename(
        bookId: widget.bookId,
        date: now,
        format: format,
      );
      final file = File(p.join(dir.path, name));
      await file.writeAsString(text, flush: true);
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          subject: l10n.notesFileHeading(widget.title),
        ),
      );
      if (!mounted) return;
      nav.pop();
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.exportDone)),
      );
    } catch (_) {
      // Share cancel or platform failure — silent per EX-32 except unexpected.
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
