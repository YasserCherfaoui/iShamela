/// SPEC-009 whitelist HTML display for `pages.body` (storage stays verbatim).
library;

import 'package:flutter/material.dart';

final _tagRe = RegExp(
  r'<!--.*?-->|</?([a-zA-Z][\w:-]*)(\s[^>]*)?>',
  dotAll: true,
);

/// Renders [raw] with a small HTML whitelist; unknown tags are stripped
/// (inner text kept). Does not mutate stored body elsewhere.
Widget buildBodyDisplay(
  String raw, {
  TextStyle? style,
  TextAlign textAlign = TextAlign.justify,
}) {
  return Text.rich(
    TextSpan(children: parseBodySpans(raw, style: style)),
    textAlign: textAlign,
  );
}

List<InlineSpan> parseBodySpans(String raw, {TextStyle? style}) {
  final base = style ?? const TextStyle(fontSize: 20, height: 1.8);
  final titleStyle = base.copyWith(
    fontWeight: FontWeight.bold,
    fontSize: (base.fontSize ?? 20) + 2,
  );
  final bold = base.copyWith(fontWeight: FontWeight.bold);
  final italic = base.copyWith(fontStyle: FontStyle.italic);

  final out = <InlineSpan>[];
  var cursor = 0;
  var titleDepth = 0;
  var boldDepth = 0;
  var italicDepth = 0;
  final spanTitleStack = <bool>[];

  TextStyle current() {
    var s = base;
    if (titleDepth > 0) s = titleStyle;
    if (boldDepth > 0) s = s.merge(bold);
    if (italicDepth > 0) s = s.merge(italic);
    return s;
  }

  void emitText(String text) {
    if (text.isEmpty) return;
    out.add(TextSpan(text: text, style: current()));
  }

  for (final m in _tagRe.allMatches(raw)) {
    if (m.start > cursor) {
      emitText(raw.substring(cursor, m.start));
    }
    cursor = m.end;
    final whole = m.group(0)!;
    if (whole.startsWith('<!--')) continue;
    final name = (m.group(1) ?? '').toLowerCase();
    final closing = whole.startsWith('</');
    final attrs = m.group(2) ?? '';

    switch (name) {
      case 'br':
        if (!closing) out.add(const TextSpan(text: '\n'));
      case 'span':
        if (closing) {
          if (spanTitleStack.isNotEmpty && spanTitleStack.removeLast()) {
            titleDepth = (titleDepth - 1).clamp(0, 999);
          }
        } else {
          final isTitleSpan =
              attrs.contains('data-type="title"') ||
              attrs.contains("data-type='title'");
          spanTitleStack.add(isTitleSpan);
          if (isTitleSpan) titleDepth++;
        }
      case 'b':
      case 'strong':
        if (closing) {
          boldDepth = (boldDepth - 1).clamp(0, 999);
        } else {
          boldDepth++;
        }
      case 'i':
      case 'em':
        if (closing) {
          italicDepth = (italicDepth - 1).clamp(0, 999);
        } else {
          italicDepth++;
        }
      default:
        // strip tag; inner text handled by surrounding matches
        break;
    }
  }
  if (cursor < raw.length) {
    emitText(raw.substring(cursor));
  }
  if (out.isEmpty) {
    out.add(TextSpan(text: raw, style: base));
  }
  return out;
}

/// True when [raw] would show angle-bracket tags to the user without parsing.
bool bodyContainsHtmlTags(String raw) => _tagRe.hasMatch(raw);
