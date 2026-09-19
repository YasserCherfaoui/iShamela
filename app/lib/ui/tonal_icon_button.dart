import 'package:flutter/material.dart';

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
    final t = IshamelaTokens.of(context);
    final btn = IconButton.filledTonal(
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
    return btn;
  }
}
