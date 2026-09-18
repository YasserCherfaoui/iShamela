import 'package:flutter/material.dart';

/// Warm Manuscript chrome tokens (DESIGN-001 §2.1 / §8).
@immutable
class IshamelaTokens extends ThemeExtension<IshamelaTokens> {
  const IshamelaTokens({
    required this.paper,
    required this.readerPaper,
    required this.card,
    required this.hairline,
    required this.ink,
    required this.muted,
    required this.green900,
    required this.green700,
    required this.green100,
    required this.gold,
    required this.goldSoft,
    required this.goldPale,
    required this.highlight,
    required this.chipBg,
    required this.segmentTrack,
    required this.spinePalette,
  });

  final Color paper;
  final Color readerPaper;
  final Color card;
  final Color hairline;
  final Color ink;
  final Color muted;
  final Color green900;
  final Color green700;
  final Color green100;
  final Color gold;
  final Color goldSoft;
  final Color goldPale;
  final Color highlight;
  final Color chipBg;
  final Color segmentTrack;

  /// Category-hued spine fills (length 5).
  final List<Color> spinePalette;

  static const paperLight = IshamelaTokens(
    paper: Color(0xFFF6F1E7),
    readerPaper: Color(0xFFF8F3E6),
    card: Color(0xFFFFFDF7),
    hairline: Color(0xFFE4DBC8),
    ink: Color(0xFF1F2A24),
    muted: Color(0xFF6E7A70),
    green900: Color(0xFF0E3B30),
    green700: Color(0xFF17614E),
    green100: Color(0xFFDFEBE2),
    gold: Color(0xFFA67C2E),
    goldSoft: Color(0xFFC6A15B),
    goldPale: Color(0xFFF4E9CF),
    highlight: Color(0xFFF3E2A9),
    chipBg: Color(0xFFF0EADB),
    segmentTrack: Color(0xFFEDE6D4),
    spinePalette: [
      Color(0xFF0E3B30),
      Color(0xFF114437),
      Color(0xFF5A4520),
      Color(0xFF1E4A56),
      Color(0xFF6E3A2C),
    ],
  );

  Color spineForCategory(int categoryId) =>
      spinePalette[categoryId.abs() % spinePalette.length];

  static IshamelaTokens of(BuildContext context) {
    return Theme.of(context).extension<IshamelaTokens>() ?? paperLight;
  }

  @override
  IshamelaTokens copyWith({
    Color? paper,
    Color? readerPaper,
    Color? card,
    Color? hairline,
    Color? ink,
    Color? muted,
    Color? green900,
    Color? green700,
    Color? green100,
    Color? gold,
    Color? goldSoft,
    Color? goldPale,
    Color? highlight,
    Color? chipBg,
    Color? segmentTrack,
    List<Color>? spinePalette,
  }) {
    return IshamelaTokens(
      paper: paper ?? this.paper,
      readerPaper: readerPaper ?? this.readerPaper,
      card: card ?? this.card,
      hairline: hairline ?? this.hairline,
      ink: ink ?? this.ink,
      muted: muted ?? this.muted,
      green900: green900 ?? this.green900,
      green700: green700 ?? this.green700,
      green100: green100 ?? this.green100,
      gold: gold ?? this.gold,
      goldSoft: goldSoft ?? this.goldSoft,
      goldPale: goldPale ?? this.goldPale,
      highlight: highlight ?? this.highlight,
      chipBg: chipBg ?? this.chipBg,
      segmentTrack: segmentTrack ?? this.segmentTrack,
      spinePalette: spinePalette ?? this.spinePalette,
    );
  }

  @override
  IshamelaTokens lerp(ThemeExtension<IshamelaTokens>? other, double t) {
    if (other is! IshamelaTokens) return this;
    return IshamelaTokens(
      paper: Color.lerp(paper, other.paper, t)!,
      readerPaper: Color.lerp(readerPaper, other.readerPaper, t)!,
      card: Color.lerp(card, other.card, t)!,
      hairline: Color.lerp(hairline, other.hairline, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      green900: Color.lerp(green900, other.green900, t)!,
      green700: Color.lerp(green700, other.green700, t)!,
      green100: Color.lerp(green100, other.green100, t)!,
      gold: Color.lerp(gold, other.gold, t)!,
      goldSoft: Color.lerp(goldSoft, other.goldSoft, t)!,
      goldPale: Color.lerp(goldPale, other.goldPale, t)!,
      highlight: Color.lerp(highlight, other.highlight, t)!,
      chipBg: Color.lerp(chipBg, other.chipBg, t)!,
      segmentTrack: Color.lerp(segmentTrack, other.segmentTrack, t)!,
      spinePalette: [
        for (var i = 0; i < spinePalette.length; i++)
          Color.lerp(
            spinePalette[i],
            other.spinePalette[i % other.spinePalette.length],
            t,
          )!,
      ],
    );
  }
}
