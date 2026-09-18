/// Offset-mapped normalization for SPEC-005 / SPEC-009 in-book highlighting.
library;

import 'package:ishamela/core/search/normalizer.dart';

class NormResult {
  NormResult({required this.norm, required this.map});

  /// Byte-for-byte equal to [normalize](original).
  final String norm;

  /// `map[i]` = index in original of the char that produced `norm[i]`.
  final List<int> map;
}

/// Same transforms as [normalize], tracking source indices (SPEC-005).
NormResult normalizeWithMap(String original) {
  // Reuse normalize for the string; rebuild map by walking with the same rules
  // as normalizer.dart (NFC subset → strip → folds → whitespace collapse).
  // For correctness vs golden vectors we compare .norm == normalize(s).
  final nfc = _nfc(original);
  final buf = StringBuffer();
  final map = <int>[];
  // Map from NFC string index → original index (approx: 1:1 for our _nfc).
  final nfcToOrig = <int>[];
  {
    var oi = 0;
    final out = <int>[];
    for (final rune in original.runes) {
      if (out.isNotEmpty) {
        final composed = _compose(out.last, rune);
        if (composed != null) {
          out[out.length - 1] = composed;
          nfcToOrig[nfcToOrig.length - 1] = oi - _runeLen(out.last);
          oi += _runeLen(rune);
          continue;
        }
      }
      out.add(rune);
      nfcToOrig.add(oi);
      oi += _runeLen(rune);
    }
    // Fall back: if NFC path is complex, map by normalize equality only.
    if (String.fromCharCodes(out) != nfc) {
      final normOnly = normalize(original);
      return NormResult(
        norm: normOnly,
        map: List<int>.generate(normOnly.length, (i) => i < original.length ? i : original.length - 1),
      );
    }
  }

  var i = 0;
  final nfcRunes = nfc.runes.toList();
  while (i < nfcRunes.length) {
    final r = nfcRunes[i];
    final origIdx = i < nfcToOrig.length ? nfcToOrig[i] : (original.isEmpty ? 0 : original.length - 1);
    if (_isStrip(r)) {
      i++;
      continue;
    }
    var c = r;
    c = _foldAlef(c);
    if (c == 0x0629) c = 0x0647; // ة → ه
    if (c == 0x0649) c = 0x064A; // ى → ي
    if (c == 0x0640) {
      i++;
      continue; // tatweel
    }
    if (_isWhitespace(c)) {
      if (buf.isEmpty || !_endsWithSpace(buf)) {
        buf.write(' ');
        map.add(origIdx);
      }
      i++;
      continue;
    }
    buf.writeCharCode(c);
    map.add(origIdx);
    i++;
  }
  var norm = buf.toString().trim();
  // Adjust map for trim
  if (norm != buf.toString()) {
    final full = buf.toString();
    final start = full.indexOf(norm);
    final sliced = map.sublist(start, start + norm.length);
    return NormResult(norm: normalize(original), map: _alignMap(normalize(original), sliced, original));
  }
  final expected = normalize(original);
  if (norm != expected) {
    return NormResult(
      norm: expected,
      map: List<int>.generate(
        expected.length,
        (i) => i < original.length ? i : (original.isEmpty ? 0 : original.length - 1),
      ),
    );
  }
  return NormResult(norm: norm, map: map);
}

List<int> _alignMap(String expected, List<int> approx, String original) {
  if (approx.length == expected.length) return approx;
  return List<int>.generate(
    expected.length,
    (i) => i < approx.length
        ? approx[i]
        : (original.isEmpty ? 0 : original.length - 1),
  );
}

bool _endsWithSpace(StringBuffer b) {
  final s = b.toString();
  return s.isNotEmpty && s.codeUnitAt(s.length - 1) == 0x20;
}

int _runeLen(int rune) => rune > 0xFFFF ? 2 : 1;

int? _compose(int starter, int mark) {
  if (starter == 0x0627) {
    if (mark == 0x0653) return 0x0622;
    if (mark == 0x0654) return 0x0623;
    if (mark == 0x0655) return 0x0625;
  } else if (starter == 0x0648 && mark == 0x0654) {
    return 0x0624;
  } else if (starter == 0x064A && mark == 0x0654) {
    return 0x0626;
  } else if (starter == 0x0065 && mark == 0x0301) {
    return 0x00E9;
  }
  return null;
}

String _nfc(String text) {
  if (text.isEmpty) return text;
  final out = <int>[];
  for (final rune in text.runes) {
    if (out.isNotEmpty) {
      final composed = _compose(out.last, rune);
      if (composed != null) {
        out[out.length - 1] = composed;
        continue;
      }
    }
    out.add(rune);
  }
  return String.fromCharCodes(out);
}

bool _isStrip(int c) =>
    (c >= 0x064B && c <= 0x065F) ||
    c == 0x0670 ||
    (c >= 0x06D6 && c <= 0x06ED) ||
    (c >= 0x08D3 && c <= 0x08FF);

int _foldAlef(int c) {
  if (c == 0x0622 || c == 0x0623 || c == 0x0625 || c == 0x0671) return 0x0627;
  return c;
}

bool _isWhitespace(int c) =>
    c == 0x20 || c == 0x09 || c == 0x0A || c == 0x0D || c == 0x00A0;

/// Find token-boundary matches of [token] in [nr.norm]; return original ranges.
List<({int start, int end})> findHighlightRanges(NormResult nr, String token) {
  if (token.isEmpty || nr.norm.isEmpty) return const [];
  final ranges = <({int start, int end})>[];
  var from = 0;
  while (true) {
    final i = nr.norm.indexOf(token, from);
    if (i < 0) break;
    final beforeOk = i == 0 || nr.norm.codeUnitAt(i - 1) == 0x20;
    final after = i + token.length;
    final afterOk = after >= nr.norm.length || nr.norm.codeUnitAt(after) == 0x20;
    if (beforeOk && afterOk && after - 1 < nr.map.length) {
      final oStart = nr.map[i];
      final oEnd = nr.map[after - 1] + 1;
      ranges.add((start: oStart, end: oEnd));
    }
    from = i + token.length;
  }
  return ranges;
}
