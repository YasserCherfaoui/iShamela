import 'package:flutter/material.dart';

/// Reading atmosphere (DESIGN-001 §2.2). Persisted as `reading_atmosphere`.
enum ReadingAtmosphere {
  paper,
  sepia,
  night,
  olive,
  gold,
  ink,
  blue,
  wood;

  static const settingsKey = 'reading_atmosphere';

  /// The original three. Extra colors stay behind the settings expand control.
  static const coreThemes = <ReadingAtmosphere>[paper, sepia, night];

  static const moreThemes = <ReadingAtmosphere>[
    olive,
    gold,
    ink,
    blue,
    wood,
  ];

  static const pickerOrder = <ReadingAtmosphere>[
    paper,
    sepia,
    night,
    olive,
    gold,
    ink,
    blue,
    wood,
  ];

  bool get isDark => this == ReadingAtmosphere.night;

  static ReadingAtmosphere fromId(String? raw) {
    switch (raw) {
      case 'sepia':
        return ReadingAtmosphere.sepia;
      case 'night':
        return ReadingAtmosphere.night;
      case 'olive':
        return ReadingAtmosphere.olive;
      case 'gold':
        return ReadingAtmosphere.gold;
      case 'ink':
        return ReadingAtmosphere.ink;
      case 'blue':
        return ReadingAtmosphere.blue;
      case 'wood':
        return ReadingAtmosphere.wood;
      case 'paper':
      default:
        return ReadingAtmosphere.paper;
    }
  }

  String get id {
    switch (this) {
      case ReadingAtmosphere.paper:
        return 'paper';
      case ReadingAtmosphere.sepia:
        return 'sepia';
      case ReadingAtmosphere.night:
        return 'night';
      case ReadingAtmosphere.olive:
        return 'olive';
      case ReadingAtmosphere.gold:
        return 'gold';
      case ReadingAtmosphere.ink:
        return 'ink';
      case ReadingAtmosphere.blue:
        return 'blue';
      case ReadingAtmosphere.wood:
        return 'wood';
    }
  }
}

/// Reader scaffold + role-color defaults for an atmosphere.
@immutable
class ReaderThemeTokens extends ThemeExtension<ReaderThemeTokens> {
  const ReaderThemeTokens({
    required this.atmosphere,
    required this.ground,
    required this.raised,
    required this.hairline,
    required this.body,
    required this.titles,
    required this.quran,
    required this.honorifics,
    required this.muted,
    required this.progressFill,
    required this.highlight,
    required this.highlightUnderline,
  });

  final ReadingAtmosphere atmosphere;
  final Color ground;
  final Color raised;
  final Color hairline;
  final Color body;
  final Color titles;
  final Color quran;
  final Color honorifics;
  final Color muted;
  final Color progressFill;
  final Color highlight;

  /// Night atmospheres use a gold underline with the dark highlight tint.
  final Color? highlightUnderline;

  static const paper = ReaderThemeTokens(
    atmosphere: ReadingAtmosphere.paper,
    ground: Color(0xFFF8F3E6),
    raised: Color(0xFFFFFDF7),
    hairline: Color(0xFFE4DBC8),
    body: Color(0xFF1A1A1A),
    titles: Color(0xFF155744),
    quran: Color(0xFF8F6A1F),
    honorifics: Color(0xFF1B7A4E),
    muted: Color(0xFF6E7A70),
    progressFill: Color(0xFFC6A15B),
    highlight: Color(0xFFF3E2A9),
    highlightUnderline: null,
  );

  static const sepia = ReaderThemeTokens(
    atmosphere: ReadingAtmosphere.sepia,
    ground: Color(0xFFF1E5CC),
    raised: Color(0xFFE9DAB9),
    hairline: Color(0xFFE0D2AF),
    body: Color(0xFF3A3226),
    titles: Color(0xFF6B5220),
    quran: Color(0xFF7A5A16),
    honorifics: Color(0xFF166844),
    muted: Color(0xFF8A7B5C),
    progressFill: Color(0xFFA67C2E),
    highlight: Color(0xFFE8D28A),
    highlightUnderline: null,
  );

  static const night = ReaderThemeTokens(
    atmosphere: ReadingAtmosphere.night,
    ground: Color(0xFF101B17),
    raised: Color(0xFF1B2A24),
    hairline: Color(0xFF223229),
    body: Color(0xFFE7E1D2),
    titles: Color(0xFF8FC7AC),
    quran: Color(0xFFD8B36A),
    honorifics: Color(0xFF79B893),
    muted: Color(0xFF7E9187),
    progressFill: Color(0xFFD8B36A),
    highlight: Color(0xFF3D3421),
    highlightUnderline: Color(0xFFD8B36A),
  );

  static const olive = ReaderThemeTokens(
    atmosphere: ReadingAtmosphere.olive,
    ground: Color(0xFFE7ECDD),
    raised: Color(0xFFF4F6EE),
    hairline: Color(0xFFD0D8C2),
    body: Color(0xFF2A3324),
    titles: Color(0xFF3D4A32),
    quran: Color(0xFF6B5A2A),
    honorifics: Color(0xFF2F6B45),
    muted: Color(0xFF6E7864),
    progressFill: Color(0xFF6B7A4E),
    highlight: Color(0xFFE3E8C4),
    highlightUnderline: null,
  );

  static const gold = ReaderThemeTokens(
    atmosphere: ReadingAtmosphere.gold,
    ground: Color(0xFFF8E8C4),
    raised: Color(0xFFFBF3DC),
    hairline: Color(0xFFE6D3A4),
    body: Color(0xFF3A2C12),
    titles: Color(0xFF6A4E16),
    quran: Color(0xFF8A6418),
    honorifics: Color(0xFF2E6B45),
    muted: Color(0xFF8A7350),
    progressFill: Color(0xFFC4922A),
    highlight: Color(0xFFF0D48A),
    highlightUnderline: null,
  );

  static const ink = ReaderThemeTokens(
    atmosphere: ReadingAtmosphere.ink,
    ground: Color(0xFFFFFFFF),
    raised: Color(0xFFF4F4F4),
    hairline: Color(0xFFE2E2E2),
    body: Color(0xFF111111),
    titles: Color(0xFF111111),
    quran: Color(0xFF111111),
    honorifics: Color(0xFF222222),
    muted: Color(0xFF6B6B6B),
    progressFill: Color(0xFF222222),
    highlight: Color(0xFFE8E8E8),
    highlightUnderline: null,
  );

  static const blue = ReaderThemeTokens(
    atmosphere: ReadingAtmosphere.blue,
    ground: Color(0xFFE4EEF4),
    raised: Color(0xFFF4F8FB),
    hairline: Color(0xFFD0DEE8),
    body: Color(0xFF1C2C38),
    titles: Color(0xFF2A4A62),
    quran: Color(0xFF6A5830),
    honorifics: Color(0xFF1E6A58),
    muted: Color(0xFF6A7C8A),
    progressFill: Color(0xFF5E88A8),
    highlight: Color(0xFFD4E4F0),
    highlightUnderline: null,
  );

  static const wood = ReaderThemeTokens(
    atmosphere: ReadingAtmosphere.wood,
    ground: Color(0xFFE8D2B4),
    raised: Color(0xFFF3E4CE),
    hairline: Color(0xFFD4B892),
    body: Color(0xFF3A2A1C),
    titles: Color(0xFF5C3E28),
    quran: Color(0xFF7A5420),
    honorifics: Color(0xFF2A6244),
    muted: Color(0xFF8A7058),
    progressFill: Color(0xFFA67C4E),
    highlight: Color(0xFFE4C48A),
    highlightUnderline: null,
  );

  static ReaderThemeTokens forAtmosphere(ReadingAtmosphere a) {
    switch (a) {
      case ReadingAtmosphere.paper:
        return paper;
      case ReadingAtmosphere.sepia:
        return sepia;
      case ReadingAtmosphere.night:
        return night;
      case ReadingAtmosphere.olive:
        return olive;
      case ReadingAtmosphere.gold:
        return gold;
      case ReadingAtmosphere.ink:
        return ink;
      case ReadingAtmosphere.blue:
        return blue;
      case ReadingAtmosphere.wood:
        return wood;
    }
  }

  static ReaderThemeTokens of(BuildContext context) {
    return Theme.of(context).extension<ReaderThemeTokens>() ?? paper;
  }

  @override
  ReaderThemeTokens copyWith({
    ReadingAtmosphere? atmosphere,
    Color? ground,
    Color? raised,
    Color? hairline,
    Color? body,
    Color? titles,
    Color? quran,
    Color? honorifics,
    Color? muted,
    Color? progressFill,
    Color? highlight,
    Color? highlightUnderline,
  }) {
    return ReaderThemeTokens(
      atmosphere: atmosphere ?? this.atmosphere,
      ground: ground ?? this.ground,
      raised: raised ?? this.raised,
      hairline: hairline ?? this.hairline,
      body: body ?? this.body,
      titles: titles ?? this.titles,
      quran: quran ?? this.quran,
      honorifics: honorifics ?? this.honorifics,
      muted: muted ?? this.muted,
      progressFill: progressFill ?? this.progressFill,
      highlight: highlight ?? this.highlight,
      highlightUnderline: highlightUnderline ?? this.highlightUnderline,
    );
  }

  @override
  ReaderThemeTokens lerp(ThemeExtension<ReaderThemeTokens>? other, double t) {
    if (other is! ReaderThemeTokens) return this;
    return ReaderThemeTokens(
      atmosphere: t < 0.5 ? atmosphere : other.atmosphere,
      ground: Color.lerp(ground, other.ground, t)!,
      raised: Color.lerp(raised, other.raised, t)!,
      hairline: Color.lerp(hairline, other.hairline, t)!,
      body: Color.lerp(body, other.body, t)!,
      titles: Color.lerp(titles, other.titles, t)!,
      quran: Color.lerp(quran, other.quran, t)!,
      honorifics: Color.lerp(honorifics, other.honorifics, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      progressFill: Color.lerp(progressFill, other.progressFill, t)!,
      highlight: Color.lerp(highlight, other.highlight, t)!,
      highlightUnderline: Color.lerp(
        highlightUnderline,
        other.highlightUnderline,
        t,
      ),
    );
  }
}
