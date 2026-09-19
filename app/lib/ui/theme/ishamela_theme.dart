import 'package:flutter/material.dart';

import 'package:ishamela/ui/theme/ishamela_tokens.dart';
import 'package:ishamela/ui/theme/reader_theme_tokens.dart';

const kFontAmiri = 'Amiri';
const kFontUi = 'IBMPlexSansArabic';

/// Hand-authored Warm Manuscript [ThemeData] (DESIGN-001 §2 — not fromSeed).
ThemeData buildIshamelaTheme(ReadingAtmosphere atmosphere) {
  final reader = ReaderThemeTokens.forAtmosphere(atmosphere);
  final chrome = _chromeFor(atmosphere);
  final brightness = atmosphere == ReadingAtmosphere.night
      ? Brightness.dark
      : Brightness.light;

  final scheme = ColorScheme(
    brightness: brightness,
    primary: chrome.green700,
    onPrimary: Colors.white,
    primaryContainer: chrome.green100,
    onPrimaryContainer: chrome.emphasis,
    secondary: chrome.green100,
    onSecondary: chrome.emphasis,
    secondaryContainer: chrome.green100,
    onSecondaryContainer: chrome.emphasis,
    tertiary: chrome.gold,
    onTertiary: Colors.white,
    tertiaryContainer: chrome.goldPale,
    onTertiaryContainer: chrome.emphasis,
    error: const Color(0xFFA6402E),
    onError: Colors.white,
    surface: chrome.card,
    onSurface: chrome.ink,
    onSurfaceVariant: chrome.muted,
    outline: chrome.hairline,
    outlineVariant: chrome.hairline,
    surfaceContainerLowest: chrome.paper,
    surfaceContainerLow: chrome.card,
    surfaceContainer: chrome.chipBg,
    surfaceContainerHigh: chrome.chipBg,
    surfaceContainerHighest: chrome.segmentTrack,
  );

  final textTheme = _textTheme(chrome.ink, chrome.muted);

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: chrome.paper,
    textTheme: textTheme,
    primaryTextTheme: textTheme,
    appBarTheme: AppBarTheme(
      backgroundColor: chrome.card,
      foregroundColor: chrome.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: TextStyle(
        fontFamily: kFontAmiri,
        fontWeight: FontWeight.w700,
        fontSize: 22,
        color: chrome.ink,
      ),
      shape: Border(bottom: BorderSide(color: chrome.hairline)),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: chrome.card,
      indicatorColor: chrome.green100,
      elevation: 0,
      height: 64,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return TextStyle(
          fontFamily: kFontUi,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          fontSize: 12,
          color: selected ? chrome.emphasis : chrome.muted,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return IconThemeData(
          color: selected ? chrome.emphasis : chrome.muted,
          size: 22,
        );
      }),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: chrome.card,
      indicatorColor: chrome.green100,
      selectedIconTheme: IconThemeData(color: chrome.emphasis),
      unselectedIconTheme: IconThemeData(color: chrome.muted),
      selectedLabelTextStyle: TextStyle(
        fontFamily: kFontUi,
        fontWeight: FontWeight.w700,
        color: chrome.emphasis,
      ),
      unselectedLabelTextStyle: TextStyle(
        fontFamily: kFontUi,
        fontWeight: FontWeight.w500,
        color: chrome.muted,
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: chrome.chipBg,
      selectedColor: chrome.green100,
      side: BorderSide(color: chrome.hairline),
      labelStyle: TextStyle(
        fontFamily: kFontUi,
        fontWeight: FontWeight.w500,
        fontSize: 12,
        color: chrome.ink,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: chrome.green700,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(
          fontFamily: kFontUi,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: chrome.ink,
        side: BorderSide(color: chrome.hairline),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(
          fontFamily: kFontUi,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: chrome.card,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(999),
        borderSide: BorderSide(color: chrome.hairline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(999),
        borderSide: BorderSide(color: chrome.hairline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(999),
        borderSide: BorderSide(color: chrome.green700, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      hintStyle: TextStyle(
        fontFamily: kFontUi,
        color: chrome.muted,
        fontWeight: FontWeight.w500,
      ),
    ),
    dividerTheme: DividerThemeData(color: chrome.hairline, thickness: 1),
    extensions: <ThemeExtension<dynamic>>[chrome, reader],
  );
}

IshamelaTokens _chromeFor(ReadingAtmosphere atmosphere) {
  switch (atmosphere) {
    case ReadingAtmosphere.paper:
      return IshamelaTokens.paperLight;
    case ReadingAtmosphere.sepia:
      return IshamelaTokens.paperLight.copyWith(
        paper: const Color(0xFFF1E5CC),
        readerPaper: const Color(0xFFF1E5CC),
        card: const Color(0xFFE9DAB9),
        hairline: const Color(0xFFE0D2AF),
        ink: const Color(0xFF3A3226),
        muted: const Color(0xFF8A7B5C),
        chipBg: const Color(0xFFE9DAB9),
        segmentTrack: const Color(0xFFE0D2AF),
      );
    case ReadingAtmosphere.night:
      // green900 stays brand-deep (hero fill). emphasis = night titles mint
      // for selected chrome text (DESIGN-001 §2.1 fill vs §2.2 titles).
      return IshamelaTokens.paperLight.copyWith(
        paper: const Color(0xFF101B17),
        readerPaper: const Color(0xFF101B17),
        card: const Color(0xFF1B2A24),
        hairline: const Color(0xFF223229),
        ink: const Color(0xFFE7E1D2),
        muted: const Color(0xFF7E9187),
        green900: const Color(0xFF0E3B30),
        green700: const Color(0xFF2A6B56),
        green100: const Color(0xFF1E3A30),
        emphasis: const Color(0xFF8FC7AC),
        gold: const Color(0xFFD8B36A),
        goldSoft: const Color(0xFFD8B36A),
        goldPale: const Color(0xFF3D3421),
        highlight: const Color(0xFF3D3421),
        chipBg: const Color(0xFF1B2A24),
        segmentTrack: const Color(0xFF223229),
      );
  }
}

TextTheme _textTheme(Color ink, Color muted) {
  TextStyle ui({
    double size = 14,
    FontWeight weight = FontWeight.w500,
    Color? color,
  }) =>
      TextStyle(
        fontFamily: kFontUi,
        fontSize: size,
        fontWeight: weight,
        color: color ?? ink,
        height: 1.35,
      );

  TextStyle amiri({
    double size = 22,
    FontWeight weight = FontWeight.w700,
    Color? color,
  }) =>
      TextStyle(
        fontFamily: kFontAmiri,
        fontSize: size,
        fontWeight: weight,
        color: color ?? ink,
        height: 1.4,
      );

  return TextTheme(
    displayLarge: amiri(size: 26),
    displayMedium: amiri(size: 24),
    displaySmall: amiri(size: 22),
    headlineLarge: amiri(size: 22),
    headlineMedium: amiri(size: 20),
    headlineSmall: amiri(size: 18),
    titleLarge: amiri(size: 17),
    titleMedium: ui(size: 15, weight: FontWeight.w600),
    titleSmall: ui(size: 13, weight: FontWeight.w600),
    bodyLarge: ui(size: 15),
    bodyMedium: ui(size: 14),
    bodySmall: ui(size: 12, color: muted),
    labelLarge: ui(size: 13, weight: FontWeight.w600),
    labelMedium: ui(size: 11.5, weight: FontWeight.w500, color: muted),
    labelSmall: ui(size: 10.5, weight: FontWeight.w500, color: muted),
  );
}
