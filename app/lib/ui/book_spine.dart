import 'package:flutter/material.dart';

import 'package:ishamela/ui/theme/ishamela_theme.dart';
import 'package:ishamela/ui/theme/ishamela_tokens.dart';

/// First meaningful title token for generated spines (DESIGN-001 §8).
String spineWordFromTitle(String title) {
  final cleaned = title
      .replaceAll(RegExp(r'<[^>]*>'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  if (cleaned.isEmpty) return '•';
  const stop = {
    'ال',
    'و',
    'في',
    'من',
    'على',
    'إلى',
    'عن',
    'مع',
    'هذا',
    'هذه',
    'ذلك',
    'كتاب',
    'باب',
  };
  for (final raw in cleaned.split(' ')) {
    var tok = raw.trim();
    if (tok.isEmpty) continue;
    // Strip leading ال for stop check only when whole token is stop.
    if (stop.contains(tok)) continue;
    if (tok.startsWith('ال') && tok.length > 2) {
      final rest = tok.substring(2);
      if (stop.contains(rest)) continue;
    }
    if (tok.length > 8) tok = '${tok.substring(0, 7)}…';
    return tok;
  }
  final fallback = cleaned.split(' ').first;
  return fallback.length > 8 ? '${fallback.substring(0, 7)}…' : fallback;
}

/// Generated book spine (44×62) — no cover art dependency.
class BookSpine extends StatelessWidget {
  const BookSpine({
    super.key,
    required this.title,
    required this.categoryId,
    this.available = true,
    this.width = 44,
    this.height = 62,
  });

  final String title;
  final int categoryId;
  final bool available;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final t = IshamelaTokens.of(context);
    final base = t.spineForCategory(categoryId);
    final bg = available ? base : Color.lerp(base, t.muted, 0.55)!;
    final word = spineWordFromTitle(title);
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: available
            ? null
            : Border.all(color: t.hairline, style: BorderStyle.solid),
      ),
      child: Stack(
        children: [
          Positioned(
            left: 6,
            right: 6,
            top: 8,
            child: Container(height: 1, color: t.goldSoft.withValues(alpha: 0.7)),
          ),
          Positioned(
            left: 6,
            right: 6,
            top: 12,
            child: Container(height: 1, color: t.goldSoft.withValues(alpha: 0.45)),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                word,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: kFontAmiri,
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                  height: 1.15,
                  color: Colors.white.withValues(alpha: available ? 0.95 : 0.55),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
