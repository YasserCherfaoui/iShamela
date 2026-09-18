import 'package:ishamela/features/reader/citation.dart';

enum ExportFormat { markdown, plainText }

class AnnotationExportOptions {
  const AnnotationExportOptions({
    required this.format,
    required this.includeHighlights,
    required this.includeNotes,
    required this.exportedOn,
    this.arabic = true,
  });

  final ExportFormat format;
  final bool includeHighlights;
  final bool includeNotes;
  final DateTime exportedOn;
  final bool arabic;
}

class ExportAnnotation {
  ExportAnnotation({
    required this.pageId,
    required this.startOffset,
    required this.endOffset,
    required this.anchorExcerpt,
    required this.citationLine,
    this.part,
    this.printPage,
    this.color,
    this.noteBody,
    this.isHighlight = true,
  });

  final int pageId;
  final String? part;
  final int? printPage;
  final int startOffset;
  final int endOffset;
  final String anchorExcerpt;
  final String citationLine;
  final String? color;
  final String? noteBody;
  final bool isHighlight;
}

/// Truncate [text] to ≤ [maxChars] on a word boundary with «…».
String truncateAnchor(String text, {int maxChars = 300}) {
  final t = text.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (t.length <= maxChars) return t;
  var cut = maxChars;
  while (cut > 0 && !_isWordBoundary(t, cut)) {
    cut--;
  }
  if (cut < maxChars ~/ 2) cut = maxChars;
  return '${t.substring(0, cut).trimRight()}…';
}

bool _isWordBoundary(String t, int i) {
  if (i <= 0 || i >= t.length) return true;
  final a = t.codeUnitAt(i - 1);
  final b = t.codeUnitAt(i);
  return _isSpace(a) || _isSpace(b);
}

bool _isSpace(int c) =>
    c == 0x20 || c == 0x09 || c == 0x0A || c == 0x0D || c == 0x00A0;

String highlightColorTag(String? color, {required bool arabic}) {
  switch (color) {
    case 'green':
      return arabic ? '#أخضر' : '#green';
    case 'blue':
      return arabic ? '#أزرق' : '#blue';
    case 'pink':
      return arabic ? '#وردي' : '#pink';
    case 'orange':
      return arabic ? '#برتقالي' : '#orange';
    case 'yellow':
    default:
      return arabic ? '#أصفر' : '#yellow';
  }
}

/// Pure export builder (SPEC-019 EX-30).
String buildAnnotationsExport({
  required String title,
  required String? author,
  required List<ExportAnnotation> entries,
  required AnnotationExportOptions options,
  required String notesHeading,
  required String exportedOnLabel,
  required String noteLabel,
  String? edition,
}) {
  final sorted = [...entries]..sort((a, b) {
      final pa = a.part ?? '';
      final pb = b.part ?? '';
      final c = pa.compareTo(pb);
      if (c != 0) return c;
      final pi = a.pageId.compareTo(b.pageId);
      if (pi != 0) return pi;
      return a.startOffset.compareTo(b.startOffset);
    });

  final filtered = sorted.where((e) {
    if (e.isHighlight && !options.includeHighlights) {
      return e.noteBody != null && options.includeNotes;
    }
    if (!e.isHighlight && !options.includeNotes) return false;
    if (e.isHighlight && !options.includeHighlights) return false;
    return true;
  }).toList();

  final md = options.format == ExportFormat.markdown;
  final buf = StringBuffer();
  if (md) {
    buf.writeln('# $notesHeading');
  } else {
    buf.writeln(notesHeading);
  }
  final bits = <String>[
    if (author != null && author.isNotEmpty) author,
    if (edition != null && edition.trim().isNotEmpty) edition.trim(),
    exportedOnLabel,
  ];
  buf.writeln(bits.join(' · '));
  buf.writeln();

  String? lastHeading;
  for (final e in filtered) {
    final page = e.printPage?.toString() ?? '—';
    final part = e.part;
    final heading = (part != null && part.isNotEmpty)
        ? (md ? '## ج $part · ص $page' : 'ج $part · ص $page')
        : (md ? '## ص $page' : 'ص $page');
    if (heading != lastHeading) {
      buf.writeln(heading);
      buf.writeln();
      lastHeading = heading;
    }
    final excerpt = truncateAnchor(e.anchorExcerpt);
    if (md) {
      buf.writeln('> $excerpt');
      buf.writeln();
      final tag = e.isHighlight
          ? '  ${highlightColorTag(e.color, arabic: options.arabic)}'
          : '';
      buf.writeln('— ${e.citationLine}$tag');
      if (e.noteBody != null &&
          e.noteBody!.isNotEmpty &&
          options.includeNotes) {
        buf.writeln();
        buf.writeln('**$noteLabel:** ${e.noteBody}');
      }
    } else {
      buf.writeln(excerpt);
      buf.writeln('— ${e.citationLine}');
      if (e.noteBody != null &&
          e.noteBody!.isNotEmpty &&
          options.includeNotes) {
        buf.writeln('  $noteLabel: ${e.noteBody}');
      }
    }
    buf.writeln();
  }
  return '${buf.toString().trimRight()}\n';
}

String exportFilename({
  required int bookId,
  required DateTime date,
  required ExportFormat format,
}) {
  final ext = format == ExportFormat.markdown ? 'md' : 'txt';
  return 'notes-$bookId.$ext';
}

/// Build citation for an annotation using the shared formatter.
String citationForAnnotation({
  required String excerpt,
  required String title,
  required String author,
  String? part,
  int? pageNumber,
  required bool arabic,
}) {
  return formatCitation(
    excerpt: excerpt,
    title: title,
    author: author,
    part: part,
    pageNumber: pageNumber,
    arabic: arabic,
  );
}
