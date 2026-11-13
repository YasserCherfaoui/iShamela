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

/// Same transforms as [normalize], tracking source UTF-16 indices (SPEC-005).
NormResult normalizeWithMap(String original) {
  if (original.isEmpty) {
    return NormResult(norm: '', map: const []);
  }

  final nfcRunes = <int>[];
  final nfcOrigStarts = <int>[];
  var oi = 0;
  for (final rune in original.runes) {
    final len = rune > 0xFFFF ? 2 : 1;
    if (nfcRunes.isNotEmpty) {
      final composed = _compose(nfcRunes.last, rune);
      if (composed != null) {
        nfcRunes[nfcRunes.length - 1] = composed;
        oi += len;
        continue;
      }
    }
    nfcRunes.add(rune);
    nfcOrigStarts.add(oi);
    oi += len;
  }

  final buf = StringBuffer();
  final map = <int>[];
  var lastWasSpace = false;

  for (var k = 0; k < nfcRunes.length; k++) {
    final r = nfcRunes[k];
    if (_isDeleted(r)) continue;
    final origIdx = nfcOrigStarts[k];
    final mapped = _fold(r);
    final ch = String.fromCharCode(mapped);
    final isSpace = !_keep(mapped) || _spaceRe.hasMatch(ch);
    if (isSpace) {
      if (buf.isNotEmpty && !lastWasSpace) {
        buf.writeCharCode(0x20);
        map.add(origIdx);
        lastWasSpace = true;
      }
      continue;
    }
    for (final cu in ch.codeUnits) {
      buf.writeCharCode(cu);
      map.add(origIdx);
    }
    lastWasSpace = false;
  }

  var norm = buf.toString();
  if (lastWasSpace && norm.isNotEmpty) {
    norm = norm.substring(0, norm.length - 1);
    map.removeLast();
  }

  assert(norm == normalize(original));
  return NormResult(norm: norm, map: map);
}

int? _compose(int starter, int mark) {
  if (starter == 0x0627) {
    if (mark == 0x0653) return 0x0622; // ا + maddah → آ
    if (mark == 0x0654) return 0x0623; // ا + hamza above → أ
    if (mark == 0x0655) return 0x0625; // ا + hamza below → إ
  } else if (starter == 0x0648 && mark == 0x0654) {
    return 0x0624; // و + hamza above → ؤ
  } else if (starter == 0x064A && mark == 0x0654) {
    return 0x0626; // ي + hamza above → ئ
  } else if (starter == 0x0065 && mark == 0x0301) {
    return 0x00E9; // e + acute → é
  }
  return null;
}

bool _isDeleted(int rune) {
  // N1 tashkīl
  if (rune >= 0x064B && rune <= 0x065F) return true;
  if (rune == 0x0670) return true; // superscript alef
  // N2 tatweel
  if (rune == 0x0640) return true;
  // N3 Quranic annotation
  if (rune >= 0x06D6 && rune <= 0x06ED) return true;
  if (rune >= 0x08D3 && rune <= 0x08FF) return true;
  // N7 standalone hamza
  if (rune == 0x0621) return true;
  return false;
}

int _fold(int rune) {
  switch (rune) {
    case 0x0623: // أ
    case 0x0625: // إ
    case 0x0622: // آ
    case 0x0671: // ٱ
      return 0x0627;
    case 0x0649: // ى
      return 0x064A;
    case 0x0629: // ة
      return 0x0647;
    case 0x0624: // ؤ
      return 0x0648;
    case 0x0626: // ئ
      return 0x064A;
    default:
      if (rune >= 0x0660 && rune <= 0x0669) {
        return 0x30 + (rune - 0x0660);
      }
      if (rune >= 0x06F0 && rune <= 0x06F9) {
        return 0x30 + (rune - 0x06F0);
      }
      return rune;
  }
}

final _letterRe = RegExp(r'\p{L}', unicode: true);
final _spaceRe = RegExp(r'\s', unicode: true);

bool _keep(int rune) {
  if (rune >= 0x30 && rune <= 0x39) return true;
  final ch = String.fromCharCode(rune);
  return _spaceRe.hasMatch(ch) || _letterRe.hasMatch(ch);
}

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
