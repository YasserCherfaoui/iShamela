import 'package:flutter/material.dart';

import 'package:ishamela/ui/theme/ishamela_tokens.dart';

/// Compact circular progress (download trailing affordance). SPEC-020 DL-01.
class ProgressRing extends StatelessWidget {
  const ProgressRing({
    super.key,
    this.value,
    this.size = 42,
    this.strokeWidth = 3.5,
    this.goldArc = false,
    this.onTap,
  });

  /// Null → indeterminate.
  final double? value;
  final double size;
  final double strokeWidth;
  final bool goldArc;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = IshamelaTokens.of(context);
    final color = goldArc ? t.goldSoft : t.green700;
    final child = SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: value,
            strokeWidth: strokeWidth,
            backgroundColor: t.segmentTrack,
            color: color,
          ),
          if (value != null)
            Text(
              '${(value!.clamp(0.0, 1.0) * 100).round()}',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: t.muted,
              ),
            ),
        ],
      ),
    );
    if (onTap == null) return child;
    return InkWell(
      customBorder: const CircleBorder(),
      onTap: onTap,
      child: child,
    );
  }
}
