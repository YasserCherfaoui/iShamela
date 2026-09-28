import 'package:flutter/material.dart';

import 'package:ishamela/ui/glass/glass_surface.dart';
import 'package:ishamela/ui/theme/ishamela_tokens.dart';

class TonalIconButton extends StatelessWidget {
  const TonalIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.enabled = true,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final glass = glassChromeTokens(context);
    final t = IshamelaTokens.of(context);
    if (glass == null) {
      return IconButton.filledTonal(
        tooltip: tooltip,
        onPressed: enabled ? onPressed : null,
        style: IconButton.styleFrom(
          foregroundColor: t.emphasis,
          disabledForegroundColor: t.muted.withValues(alpha: 0.4),
          backgroundColor: enabled ? t.green100 : t.segmentTrack,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          minimumSize: const Size(44, 44),
        ),
        icon: Icon(icon, size: 22),
      );
    }
    return IconButton(
      tooltip: tooltip,
      onPressed: enabled ? onPressed : null,
      style: IconButton.styleFrom(
        foregroundColor: enabled
            ? glass.foregroundAccent
            : glass.foregroundInk.withValues(alpha: 0.4),
        disabledForegroundColor: glass.foregroundInk.withValues(alpha: 0.4),
        backgroundColor: enabled ? glass.activeCapsule : const Color(0x00000000),
        side: BorderSide(
          color: enabled ? glass.stroke : glass.stroke.withValues(alpha: 0.4),
        ),
        shape: const CircleBorder(),
        minimumSize: const Size(44, 44),
      ),
      icon: Icon(icon, size: 22),
    );
  }
}
