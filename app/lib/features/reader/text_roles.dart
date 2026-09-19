import 'package:ishamela/features/reader/body_display_map.dart';

/// Semantic text roles for reader display (SPEC-011).
enum TextRole {
  body('body'),
  title('title'),
  honorific('honorific'),
  quran('quran'),
  punctuation('punctuation');

  const TextRole(this.id);
  final String id;
}

/// Longest-first phrase table — all map to [TextRole.honorific] (SPEC-011).
///
/// Includes expanded Arabic strings and Shamela Unicode ligatures (U+FD40–U+FD4F,
/// U+FDFA/U+FDFB/U+FDFD–U+FDFF) attested in SPEC-006 `d1_codepoints.tsv`.
const honorificPhrases = <String>[
  'صلى الله عليه وآله وسلم',
  'رضي الله عنهم أجمعين',
  'رحمه الله تعالى',
  'سبحانه وتعالى',
  'تبارك وتعالى',
  'صلى الله عليه وسلم',
  'عليه الصلاة والسلام',
  'رضي الله عنهما',
  'رضي الله عنهم',
  'رضي الله عنها',
  'رضي الله عنه',
  'رحمهما الله',
  'رحمهم الله',
  'رحمها الله',
  'رحمه الله',
  'عز وجل',
  'عزوجل',
  // Unicode ligatures (one code point each).
  '\uFDFA', // ﷺ sallallahu alayhe wasallam
  '\uFDFB', // ﷻ jalla jalaluhu
  '\uFDFD', // ﷽ basmala
  '\uFDFE', // ﷻ-class: subhanahu wa taala
  '\uFDFF', // ﷿ azza wa jall
  '\uFD40', // ؒ rahimahu allah
  '\uFD41', // ؓ radi allahu anh
  '\uFD42', // ؓ radi allahu anha
  '\uFD43', // ؓ radi allahu anhum
  '\uFD44', // ؓ radi allahu anhuma
  '\uFD45', // ؓ radi allahu anhunna
  '\uFD46', // ؐ sallallahu alayhi wa-aalih
  '\uFD47', // ؑ alayhi as-salaam
  '\uFD48', // ؓ alayhim as-salaam
  '\uFD49', // ؓ alayhimaa as-salaam
  '\uFD4A', // ؓ alayhi as-salaatu was-salaam
  '\uFD4B', // ؓ quddisa sirrah
  '\uFD4C', // ؐ sallallahu alayhi wa-aalihee wa-sallam
  '\uFD4D', // ؑ alayhaa as-salaam
  '\uFD4E', // ؓ tabaaraka wa-taaalaa
  '\uFD4F', // ؓ rahimahum allah
];

final _punctuation = <int>{
  for (final c in r'''.\,;:!?\'"()[]{}/\-–—…،؛؟٪٫٬«»“”‘’'''.codeUnits) c,
};

bool _isDisplayFoldStrip(int cu) =>
    (cu >= 0x064B && cu <= 0x065F) || cu == 0x0670 || cu == 0x0640;

/// Result of classifying display text into roles.
class TextRoleMap {
  TextRoleMap({required this.display, required this.roles});

  final String display;
  final List<TextRole> roles;

  TextRole roleAt(int i) =>
      (i >= 0 && i < roles.length) ? roles[i] : TextRole.body;
}

/// Classify [body] (verbatim) into per-display-index roles.
TextRoleMap classifyTextRoles(String body) {
  final map = BodyDisplayMap.fromBody(body);
  final display = map.display;
  final roles = List<TextRole>.filled(display.length, TextRole.body);

  for (final (a, b) in _titleDisplayRanges(body, map)) {
    for (var i = a; i < b && i < roles.length; i++) {
      roles[i] = TextRole.title;
    }
  }

  final foldBuf = StringBuffer();
  final foldToDisplay = <int>[];
  for (var i = 0; i < display.length; i++) {
    final cu = display.codeUnitAt(i);
    if (_isDisplayFoldStrip(cu)) continue;
    foldBuf.writeCharCode(cu);
    foldToDisplay.add(i);
  }
  final folded = foldBuf.toString();
  final phrases = [...honorificPhrases]
    ..sort((a, b) => b.length.compareTo(a.length));

  for (final phrase in phrases) {
    final foldedPhrase = _displayFold(phrase);
    if (foldedPhrase.isEmpty) continue;
    var from = 0;
    while (true) {
      final at = folded.indexOf(foldedPhrase, from);
      if (at < 0) break;
      final dStart = foldToDisplay[at];
      final dEnd = foldToDisplay[at + foldedPhrase.length - 1] + 1;
      var free = true;
      for (var i = dStart; i < dEnd; i++) {
        if (roles[i] != TextRole.body) {
          free = false;
          break;
        }
      }
      if (free) {
        for (var i = dStart; i < dEnd; i++) {
          roles[i] = TextRole.honorific;
        }
      }
      from = at + foldedPhrase.length;
    }
  }

  // Quran spans: pair ornate parentheses (either order) and color inclusive.
  final markIdx = <int>[];
  for (var mi = 0; mi < display.length; mi++) {
    final cu = display.codeUnitAt(mi);
    if (cu == 0xFD3E || cu == 0xFD3F) markIdx.add(mi);
  }
  for (var m = 0; m + 1 < markIdx.length; m += 2) {
    final a = markIdx[m];
    final b = markIdx[m + 1];
    for (var k = a; k <= b; k++) {
      if (roles[k] == TextRole.body || roles[k] == TextRole.punctuation) {
        roles[k] = TextRole.quran;
      }
    }
  }
  if (markIdx.length.isOdd) {
    final last = markIdx.last;
    if (roles[last] == TextRole.body || roles[last] == TextRole.punctuation) {
      roles[last] = TextRole.quran;
    }
  }

  for (var p = 0; p < display.length; p++) {
    if (roles[p] != TextRole.body) continue;
    final cu = display.codeUnitAt(p);
    if (_punctuation.contains(cu)) {
      roles[p] = TextRole.punctuation;
    }
  }

  return TextRoleMap(display: display, roles: roles);
}

String _displayFold(String s) {
  final buf = StringBuffer();
  for (final cu in s.codeUnits) {
    if (_isDisplayFoldStrip(cu)) continue;
    buf.writeCharCode(cu);
  }
  return buf.toString();
}

final _tagRe = RegExp(
  r'<!--.*?-->|</?([a-zA-Z][\w:-]*)(\s[^>]*)?>',
  dotAll: true,
);

List<(int, int)> _titleDisplayRanges(String body, BodyDisplayMap map) {
  final out = <(int, int)>[];
  var titleDepth = 0;
  int? titleBodyStart;

  void flushTitle(int bodyEnd) {
    final start = titleBodyStart;
    if (start == null) return;
    final (ds, de) = map.toDisplayRange(start, bodyEnd);
    if (de > ds) out.add((ds, de));
    titleBodyStart = null;
  }

  for (final m in _tagRe.allMatches(body)) {
    final whole = m.group(0)!;
    if (whole.startsWith('<!--')) continue;
    final name = (m.group(1) ?? '').toLowerCase();
    if (name != 'span') continue;
    final closing = whole.startsWith('</');
    final attrs = m.group(2) ?? '';
    if (!closing &&
        (attrs.contains('data-type="title"') ||
            attrs.contains("data-type='title'"))) {
      titleDepth++;
      titleBodyStart ??= m.end;
    } else if (closing && titleDepth > 0) {
      titleDepth--;
      if (titleDepth == 0) {
        flushTitle(m.start);
      }
    }
  }
  if (titleDepth > 0 && titleBodyStart != null) {
    flushTitle(body.length);
  }
  return out;
}
