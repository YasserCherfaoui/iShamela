import 'dart:convert';

import 'package:flutter/material.dart';

import 'package:ishamela/features/reader/text_roles.dart';

/// Bundled / system reader fonts (SPEC-011).
enum ReaderFont {
  system('system'),
  amiri('amiri'),
  scheherazade('scheherazade');

  const ReaderFont(this.id);
  final String id;

  String? get familyName {
    switch (this) {
      case ReaderFont.system:
        return null;
      case ReaderFont.amiri:
        return 'Amiri';
      case ReaderFont.scheherazade:
        return 'ScheherazadeNew';
    }
  }

  /// Amiri and the iOS system font lack the Shamela honorific ligatures
  /// (U+FD40–U+FD4F, U+FDFE, U+FDFF). Scheherazade New has them. macOS
  /// substitutes those glyphs from the system; iOS shows tofu unless we
  /// name an explicit fallback.
  List<String>? get glyphFallback {
    switch (this) {
      case ReaderFont.scheherazade:
        return null;
      case ReaderFont.system:
      case ReaderFont.amiri:
        return const ['ScheherazadeNew'];
    }
  }

  static ReaderFont fromId(String? raw) {
    switch (raw) {
      case 'system':
        return ReaderFont.system;
      case 'scheherazade':
        return ReaderFont.scheherazade;
      case 'amiri':
      default:
        return ReaderFont.amiri;
    }
  }
}

/// Per-role paint style (SPEC-011).
class RoleStyle {
  const RoleStyle({required this.color, required this.bold});

  final Color color;
  final bool bold;

  Map<String, Object?> toJson() => {
        'color':
            '#${color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}',
        'bold': bold,
      };

  RoleStyle copyWith({Color? color, bool? bold}) =>
      RoleStyle(color: color ?? this.color, bold: bold ?? this.bold);
}

/// User-configurable reader text styles (SPEC-011).
class ReaderTextStyles {
  ReaderTextStyles({
    required Map<TextRole, RoleStyle> byRole,
    required this.font,
    required this.fontSize,
  }) : _byRole = byRole;

  final Map<TextRole, RoleStyle> _byRole;
  final ReaderFont font;
  final double fontSize;

  static const settingsKey = 'reader_text_styles';

  static ReaderTextStyles defaults() => ReaderTextStyles(
        byRole: {
          TextRole.body:
              const RoleStyle(color: Color(0xFF1A1A1A), bold: false),
          TextRole.title:
              const RoleStyle(color: Color(0xFF0D5C3D), bold: true),
          TextRole.honorific:
              const RoleStyle(color: Color(0xFF1B7A4E), bold: false),
          TextRole.quran:
              const RoleStyle(color: Color(0xFFB8860B), bold: false),
          TextRole.punctuation:
              const RoleStyle(color: Color(0xFF888888), bold: false),
        },
        font: ReaderFont.amiri,
        fontSize: 20,
      );

  RoleStyle styleFor(TextRole role) =>
      _byRole[role] ?? defaults()._byRole[role]!;

  ReaderTextStyles withRole(TextRole role, RoleStyle style) {
    final next = Map<TextRole, RoleStyle>.from(_byRole);
    next[role] = style;
    return ReaderTextStyles(byRole: next, font: font, fontSize: fontSize);
  }

  ReaderTextStyles withFont(ReaderFont f) =>
      ReaderTextStyles(byRole: _byRole, font: f, fontSize: fontSize);

  ReaderTextStyles withFontSize(double size) => ReaderTextStyles(
        byRole: _byRole,
        font: font,
        fontSize: size.clamp(14, 40),
      );

  String toJsonString() {
    final out = <String, Object?>{};
    for (final e in _byRole.entries) {
      out[e.key.id] = e.value.toJson();
    }
    out['font'] = font.id;
    out['font_size'] = fontSize;
    return jsonEncode(out);
  }

  static ReaderTextStyles fromJsonString(String? raw) {
    final base = defaults();
    if (raw == null || raw.trim().isEmpty) return base;
    Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } catch (_) {
      return base;
    }
    if (decoded is! Map) return base;
    final map = Map<TextRole, RoleStyle>.from(base._byRole);
    for (final role in TextRole.values) {
      final entry = decoded[role.id];
      if (entry is! Map) continue;
      map[role] = _roleFromJson(entry, map[role]!);
    }
    // Migrate legacy per-phrase keys → honorific / quran.
    if (decoded['honorific'] is! Map) {
      for (final legacy in [
        'salawat',
        'radiyallah',
        'rahimahullah',
        'azza_wajal',
      ]) {
        final entry = decoded[legacy];
        if (entry is Map) {
          map[TextRole.honorific] =
              _roleFromJson(entry, map[TextRole.honorific]!);
          break;
        }
      }
    }
    if (decoded['quran'] is! Map) {
      final legacy = decoded['quran_mark'];
      if (legacy is Map) {
        map[TextRole.quran] = _roleFromJson(legacy, map[TextRole.quran]!);
      }
    }
    final font = ReaderFont.fromId(decoded['font'] as String?);
    final sizeRaw = decoded['font_size'];
    final size = sizeRaw is num
        ? sizeRaw.toDouble().clamp(14.0, 40.0).toDouble()
        : base.fontSize;
    return ReaderTextStyles(byRole: map, font: font, fontSize: size);
  }

  static RoleStyle _roleFromJson(Map entry, RoleStyle prev) {
    var color = prev.color;
    final c = entry['color'];
    if (c is String) {
      final parsed = _parseHex(c);
      if (parsed != null) color = parsed;
    }
    final bold = entry['bold'] is bool ? entry['bold'] as bool : prev.bold;
    return RoleStyle(color: color, bold: bold);
  }

  static Color? _parseHex(String s) {
    var h = s.trim();
    if (h.startsWith('#')) h = h.substring(1);
    if (h.length == 6) h = 'FF$h';
    if (h.length != 8) return null;
    final v = int.tryParse(h, radix: 16);
    if (v == null) return null;
    return Color(v);
  }
}
