"""Arabic search normalizer (SPEC-001).

Maps source text to a canonical search form. Applied to ``body_norm`` at
bundle-build time and to user queries at search time — never to displayed
``pages.body``.

Rule order is contractual (SPEC-001): NFC → N1..N9 → N10.
"""

from __future__ import annotations

import unicodedata

NORM_VERSION: str = "1.0.0"

# N1 tashkīl U+064B–U+065F and superscript alef U+0670
# N2 tatweel U+0640
# N3 Quranic annotation U+06D6–U+06ED and U+08D3–U+08FF
# N7 standalone hamza U+0621 is removed (not replaced with a space)
_DELETE = {
    *(chr(cp) for cp in range(0x064B, 0x0660)),
    "\u0670",
    "\u0640",
    *(chr(cp) for cp in range(0x06D6, 0x06EE)),
    *(chr(cp) for cp in range(0x08D3, 0x0900)),
    "\u0621",
}

# N4 alef variants, N5 alef maqsura, N6 ta marbuta, N7 hamza carriers, N8 digits
_REPLACE = {
    "\u0623": "\u0627",  # أ → ا
    "\u0625": "\u0627",  # إ → ا
    "\u0622": "\u0627",  # آ → ا
    "\u0671": "\u0627",  # ٱ → ا
    "\u0649": "\u064A",  # ى → ي
    "\u0629": "\u0647",  # ة → ه
    "\u0624": "\u0648",  # ؤ → و
    "\u0626": "\u064A",  # ئ → ي
    **{chr(0x0660 + i): str(i) for i in range(10)},
    **{chr(0x06F0 + i): str(i) for i in range(10)},
}

_TRANS = str.maketrans(
    {ord(src): ord(dst) for src, dst in _REPLACE.items()}
    | {ord(ch): None for ch in _DELETE}
)


def normalize(text: str) -> str:
    """Return the canonical search form of ``text`` (SPEC-001 N11, N1–N10).

    Pure function: no options, no locale dependence. Idempotent.
    """
    # N11 — NFC before any stripping or folding
    text = unicodedata.normalize("NFC", text)
    # N1–N8 — strip marks / tatweel / Quranic annotation; fold letters; ASCII digits
    text = text.translate(_TRANS)
    # N9 — non-letter symbols (punctuation, brackets, ornaments, format chars) → space
    stripped = [
        ch
        if ch.isspace() or ("0" <= ch <= "9") or unicodedata.category(ch)[0] == "L"
        else " "
        for ch in text
    ]
    # N10 — collapse whitespace runs to one U+0020 and trim
    return " ".join("".join(stripped).split())
