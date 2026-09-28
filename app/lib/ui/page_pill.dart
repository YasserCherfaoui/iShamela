import 'package:flutter/material.dart';

import 'package:ishamela/ui/glass/glass_surface.dart';
import 'package:ishamela/ui/theme/ishamela_tokens.dart';
import 'package:ishamela/ui/theme/ishamela_theme.dart';

/// Center page pill for reader bottom bar (DESIGN-001 §3).
class PagePill extends StatelessWidget {
  const PagePill({
    super.key,
    required this.label,
    this.onTap,
  });

  /// e.g. `ج ١ · ص ١٢ · 12/745` or `ص — · 3/100`
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = IshamelaTokens.of(context);
    final glass = glassChromeTokens(context);
    final reduce = MediaQuery.disableAnimationsOf(context);
    final color = glass?.foregroundInk ?? t.ink;
    return Material(
      color: glass == null ? t.card : const Color(0x00000000),
      shape: StadiumBorder(
        side: BorderSide(
          color: glass == null ? t.hairline : const Color(0x00000000),
        ),
      ),
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: AnimatedSwitcher(
            duration: reduce ? Duration.zero : const Duration(milliseconds: 150),
            child: Text(
              label,
              key: ValueKey(label),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: kFontUi,
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: color,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
