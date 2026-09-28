/// SPEC-029. Slice of `pages.body` for the highlights list.
///
/// Tags are dropped the same way the reader keeps inner text. The stored
/// body string is not modified.
library;

final _tagRe = RegExp(
  r'<!--.*?-->|</?([a-zA-Z][\w:-]*)(\s[^>]*)?>',
  dotAll: true,
);

String highlightListExcerpt(String body, int start, int end) {
  if (body.isEmpty) return '';
  final from = start.clamp(0, body.length);
  final to = end.clamp(0, body.length);
  if (to <= from) return '';
  final stripped = _stripTags(body.substring(from, to));
  return stripped.trim().replaceAll(RegExp(r'\s+'), ' ');
}

String _stripTags(String raw) {
  final buf = StringBuffer();
  var cursor = 0;
  for (final m in _tagRe.allMatches(raw)) {
    if (m.start > cursor) {
      buf.write(raw.substring(cursor, m.start));
    }
    cursor = m.end;
    final whole = m.group(0)!;
    if (whole.startsWith('<!--')) continue;
    final name = (m.group(1) ?? '').toLowerCase();
    final closing = whole.startsWith('</');
    if (name == 'br' && !closing) buf.write('\n');
  }
  if (cursor < raw.length) {
    buf.write(raw.substring(cursor));
  }
  return buf.toString();
}
