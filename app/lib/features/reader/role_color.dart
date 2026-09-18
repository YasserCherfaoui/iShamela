import 'package:flutter/material.dart';

import 'package:ishamela/features/reader/reader_styles.dart';
import 'package:ishamela/features/reader/text_roles.dart';
import 'package:ishamela/ui/theme/reader_theme_tokens.dart';

/// Resolve paint color: `userOverride ?? themeDefault` (DESIGN-001 §8).
///
/// Stock paper defaults are treated as “no override” so atmosphere changes
/// recolor roles until the user picks an explicit swatch.
Color resolveRoleColor(
  TextRole role,
  RoleStyle user,
  ReaderThemeTokens theme,
) {
  final paperDefault = ReaderTextStyles.defaults().styleFor(role);
  if (user.color.toARGB32() == paperDefault.color.toARGB32() &&
      user.bold == paperDefault.bold) {
    switch (role) {
      case TextRole.body:
        return theme.body;
      case TextRole.title:
        return theme.titles;
      case TextRole.honorific:
        return theme.honorifics;
      case TextRole.quran:
        return theme.quran;
      case TextRole.punctuation:
        return theme.muted;
    }
  }
  return user.color;
}
