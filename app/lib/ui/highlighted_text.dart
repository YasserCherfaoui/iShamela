import 'package:flutter/material.dart';

import 'package:ishamela/ui/theme/ishamela_tokens.dart';
import 'package:ishamela/ui/theme/ishamela_theme.dart';

/// Marks case-insensitive [query] token substrings with the design highlight.
class HighlightedText extends StatelessWidget {
  const HighlightedText({
    super.key,
    required this.text,
    required this.query,
    this.style,
    this.maxLines = 2,
  });

  final String text;
  final String query;
  final TextStyle? style;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final t = IshamelaTokens.of(context);
    final base = style ??
        TextStyle(
          fontFamily: kFontAmiri,
          fontWeight: FontWeight.w700,
          fontSize: 16,
          color: t.ink,
          height: 1.35,
        );
    final tokens = query
        .trim()
        .split(RegExp(r'\s+'))
        .where((s) => s.isNotEmpty)
        .toList();
    if (tokens.isEmpty) {
      return Text(
        text,
        maxLines: maxLines,
        overflow: TextOverflow.ellipsis,
        style: base,
      );
    }
    final lower = text.toLowerCase();
    final ranges = <({int start, int end})>[];
    for (final tok in tokens) {
      final needle = tok.toLowerCase();
      var from = 0;
      while (from < lower.length) {
        final i = lower.indexOf(needle, from);
        if (i < 0) break;
        ranges.add((start: i, end: i + needle.length));
        from = i + needle.length;
      }
    }
    if (ranges.isEmpty) {
      return Text(
        text,
        maxLines: maxLines,
        overflow: TextOverflow.ellipsis,
        style: base,
      );
    }
    ranges.sort((a, b) => a.start.compareTo(b.start));
    final merged = <({int start, int end})>[];
    for (final r in ranges) {
      if (merged.isEmpty || r.start > merged.last.end) {
        merged.add(r);
      } else if (r.end > merged.last.end) {
        merged[merged.length - 1] = (start: merged.last.start, end: r.end);
      }
    }
    final spans = <TextSpan>[];
    var cursor = 0;
    final hi = base.copyWith(backgroundColor: t.highlight);
    for (final r in merged) {
      if (r.start > cursor) {
        spans.add(TextSpan(text: text.substring(cursor, r.start)));
      }
      spans.add(TextSpan(text: text.substring(r.start, r.end), style: hi));
      cursor = r.end;
    }
    if (cursor < text.length) {
      spans.add(TextSpan(text: text.substring(cursor)));
    }
    return Text.rich(
      TextSpan(style: base, children: spans),
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
    );
  }
}
