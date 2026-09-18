import 'package:flutter/material.dart';

/// Reading atmosphere (DESIGN-001 §2.2). Persisted as `reading_atmosphere`.
enum ReadingAtmosphere {
  paper,
  sepia,
  night;

  static const settingsKey = 'reading_atmosphere';

  static ReadingAtmosphere fromId(String? raw) {
    switch (raw) {
      case 'sepia':
        return ReadingAtmosphere.sepia;
      case 'night':
        return ReadingAtmosphere.night;
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

  static ReaderThemeTokens forAtmosphere(ReadingAtmosphere a) {
    switch (a) {
      case ReadingAtmosphere.paper:
        return paper;
      case ReadingAtmosphere.sepia:
        return sepia;
      case ReadingAtmosphere.night:
        return night;
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
