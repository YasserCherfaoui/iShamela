import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:ishamela/ui/theme/ishamela_tokens.dart';

/// Four-point gold rosette ornament (DESIGN-001 §2.4).
class RosetteDivider extends StatelessWidget {
  const RosetteDivider({super.key, this.size = 18});

  final double size;

  @override
  Widget build(BuildContext context) {
    final t = IshamelaTokens.of(context);
    return Row(
      children: [
        Expanded(child: Divider(color: t.hairline)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: CustomPaint(
            size: Size(size, size),
            painter: _RosettePainter(color: t.gold),
          ),
        ),
        Expanded(child: Divider(color: t.hairline)),
      ],
    );
  }
}

class RosetteMark extends StatelessWidget {
  const RosetteMark({super.key, this.size = 14});

  final double size;

  @override
  Widget build(BuildContext context) {
    final t = IshamelaTokens.of(context);
    return CustomPaint(
      size: Size(size, size),
      painter: _RosettePainter(color: t.gold),
    );
  }
}

class _RosettePainter extends CustomPainter {
  _RosettePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.shortestSide / 2;
    for (var i = 0; i < 4; i++) {
      final angle = i * (math.pi / 2);
      final tip = Offset(c.dx + r * math.cos(angle), c.dy + r * math.sin(angle));
      final left = Offset(
        c.dx + (r * 0.35) * math.cos(angle - 0.6),
        c.dy + (r * 0.35) * math.sin(angle - 0.6),
      );
      final right = Offset(
        c.dx + (r * 0.35) * math.cos(angle + 0.6),
        c.dy + (r * 0.35) * math.sin(angle + 0.6),
      );
      final path = Path()
        ..moveTo(c.dx, c.dy)
        ..lineTo(left.dx, left.dy)
        ..lineTo(tip.dx, tip.dy)
        ..lineTo(right.dx, right.dy)
        ..close();
      canvas.drawPath(path, paint);
    }
    canvas.drawCircle(c, r * 0.18, paint);
  }

  @override
  bool shouldRepaint(covariant _RosettePainter oldDelegate) =>
      oldDelegate.color != color;
}
