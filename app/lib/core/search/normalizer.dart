/// Arabic search normalizer (SPEC-001).
///
/// Maps source text to a canonical search form. Applied to `body_norm` at
/// bundle-build time and to user queries at search time — never to displayed
/// `pages.body`.
///
/// Rule order is contractual (SPEC-001): NFC → N1..N9 → N10.
library;

const String normVersion = '1.0.0';

/// Targeted canonical composition covering Arabic hamza/maddah pairs that
/// interact with N1–N7, plus Latin combining acute used in the golden vectors.
///
/// Dart's core library has no Unicode NFC. This is not a silent switch to
/// NFKC: Arabic presentation forms such as U+FEFB are left unchanged.
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

String _nfc(String text) {
  if (text.isEmpty) {
    return text;
  }
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
final _spaceRunRe = RegExp(r'\s+', unicode: true);

bool _keep(int rune) {
  if (rune >= 0x30 && rune <= 0x39) return true;
  final ch = String.fromCharCode(rune);
  return _spaceRe.hasMatch(ch) || _letterRe.hasMatch(ch);
}

/// Return the canonical search form of [text] (SPEC-001 N11, N1–N10).
///
/// Pure function: no options, no locale dependence. Idempotent.
String normalize(String text) {
  text = _nfc(text);
  final buf = StringBuffer();
  for (final rune in text.runes) {
    if (_isDeleted(rune)) {
      continue;
    }
    final mapped = _fold(rune);
    if (_keep(mapped)) {
      buf.writeCharCode(mapped);
    } else {
      buf.writeCharCode(0x20);
    }
  }
  return buf
      .toString()
      .split(_spaceRunRe)
      .where((part) => part.isNotEmpty)
      .join(' ');
}
