/// Maps whitelist-stripped display text ↔ verbatim `pages.body` offsets.
library;

final _tagRe = RegExp(
  r'<!--.*?-->|</?([a-zA-Z][\w:-]*)(\s[^>]*)?>',
  dotAll: true,
);

class BodyDisplayMap {
  BodyDisplayMap._(this.display, this.displayToBody);

  final String display;

  /// For each display UTF-16 index, the corresponding body index.
  final List<int> displayToBody;

  factory BodyDisplayMap.fromBody(String body) {
    final buf = StringBuffer();
    final map = <int>[];

    void emitBodyChar(int bodyIndex, int codeUnit) {
      // SPEC-011: normalize legacy CR / CRLF to LF for visible breaks.
      if (codeUnit == 0x0D) {
        final next = bodyIndex + 1 < body.length
            ? body.codeUnitAt(bodyIndex + 1)
            : null;
        if (next == 0x0A) {
          // Skip CR; LF will emit `\n`.
          return;
        }
        buf.write('\n');
        map.add(bodyIndex);
        return;
      }
      buf.writeCharCode(codeUnit);
      map.add(bodyIndex);
    }

    var cursor = 0;
    for (final m in _tagRe.allMatches(body)) {
      for (var i = cursor; i < m.start; i++) {
        emitBodyChar(i, body.codeUnitAt(i));
      }
      final whole = m.group(0)!;
      if (!whole.startsWith('<!--')) {
        final name = (m.group(1) ?? '').toLowerCase();
        final closing = whole.startsWith('</');
        if (name == 'br' && !closing) {
          buf.write('\n');
          map.add(m.start);
        }
      }
      cursor = m.end;
    }
    for (var i = cursor; i < body.length; i++) {
      emitBodyChar(i, body.codeUnitAt(i));
    }
    return BodyDisplayMap._(buf.toString(), map);
  }

  /// Convert a display selection `[start, end)` to body `[start, end)`.
  (int, int) toBodyRange(int displayStart, int displayEnd) {
    if (display.isEmpty || displayToBody.isEmpty) {
      return (0, 0);
    }
    final a = displayStart.clamp(0, displayToBody.length);
    final b = displayEnd.clamp(0, displayToBody.length);
    if (a >= b) return (0, 0);
    final bodyStart = displayToBody[a];
    final bodyEnd = displayToBody[b - 1] + 1;
    if (bodyEnd <= bodyStart) return (0, 0);
    return (bodyStart, bodyEnd);
  }

  /// Body `[start, end)` → display `[start, end)` (best-effort).
  (int, int) toDisplayRange(int bodyStart, int bodyEnd) {
    var dStart = -1;
    var dEnd = -1;
    for (var i = 0; i < displayToBody.length; i++) {
      final b = displayToBody[i];
      if (dStart < 0 && b >= bodyStart) dStart = i;
      if (b < bodyEnd) dEnd = i + 1;
    }
    if (dStart < 0) return (0, 0);
    if (dEnd < dStart) dEnd = dStart;
    return (dStart, dEnd.clamp(dStart, display.length));
  }
}
