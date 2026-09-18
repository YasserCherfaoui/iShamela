import 'package:flutter/material.dart';

import 'package:ishamela/ui/theme/ishamela_tokens.dart';

/// Compact circular progress (download trailing affordance).
class ProgressRing extends StatelessWidget {
  const ProgressRing({
    super.key,
    required this.value,
    this.size = 42,
    this.strokeWidth = 3.5,
  });

  final double value;
  final double size;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    final t = IshamelaTokens.of(context);
    final v = value.clamp(0.0, 1.0);
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: v,
            strokeWidth: strokeWidth,
            backgroundColor: t.segmentTrack,
            color: t.green700,
          ),
          Text(
            '${(v * 100).round()}',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: t.muted,
            ),
          ),
        ],
      ),
    );
  }
}
