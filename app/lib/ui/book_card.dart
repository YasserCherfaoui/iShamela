import 'package:flutter/material.dart';

import 'package:ishamela/ui/book_spine.dart';
import 'package:ishamela/ui/highlighted_text.dart';
import 'package:ishamela/ui/meta_chip.dart';
import 'package:ishamela/ui/theme/ishamela_tokens.dart';
import 'package:ishamela/ui/theme/ishamela_theme.dart';

/// Book row card with generated spine (DESIGN-001 §3).
class BookCard extends StatelessWidget {
  const BookCard({
    super.key,
    required this.title,
    required this.categoryId,
    this.author,
    this.meta = const [],
    this.trailing,
    this.onTap,
    this.onLongPress,
    this.available = true,
    this.unavailableLabel,
    this.progress,
    this.selected,
    this.onSelectedChanged,
    this.highlightQuery,
  });

  final String title;
  final int categoryId;
  final String? author;
  final List<String> meta;
  final Widget? trailing;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool available;
  final String? unavailableLabel;

  /// 0–1 optional thin progress under the title row.
  final double? progress;
  final bool? selected;
  final ValueChanged<bool?>? onSelectedChanged;
  final String? highlightQuery;

  @override
  Widget build(BuildContext context) {
    final t = IshamelaTokens.of(context);
    final selecting = selected != null;
    return Material(
      color: t.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: t.hairline,
          style: available ? BorderStyle.solid : BorderStyle.none,
        ),
      ),
      child: InkWell(
        onTap: selecting
            ? () => onSelectedChanged?.call(!(selected ?? false))
            : onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(14),
        child: CustomPaint(
          painter: available
              ? null
              : _DashedBorderPainter(color: t.hairline, radius: 14),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (selecting) ...[
                  Checkbox(
                    value: selected,
                    onChanged: available ? onSelectedChanged : null,
                  ),
                  const SizedBox(width: 4),
                ],
                BookSpine(
                  title: title,
                  categoryId: categoryId,
                  available: available,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                    if (highlightQuery != null &&
                        highlightQuery!.trim().isNotEmpty)
                      HighlightedText(
                        text: title,
                        query: highlightQuery!,
                        style: TextStyle(
                          fontFamily: kFontAmiri,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          color: available ? t.ink : t.muted,
                          height: 1.35,
                        ),
                      )
                    else
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: kFontAmiri,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          color: available ? t.ink : t.muted,
                          height: 1.35,
                        ),
                      ),
                      if (author != null && author!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          author!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: kFontUi,
                            fontWeight: FontWeight.w500,
                            fontSize: 12,
                            color: t.muted,
                          ),
                        ),
                      ],
                      if (meta.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            for (final m in meta) MetaChip(label: m),
                          ],
                        ),
                      ],
                      if (!available && unavailableLabel != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          unavailableLabel!,
                          style: TextStyle(
                            fontFamily: kFontUi,
                            fontSize: 11,
                            color: t.muted,
                          ),
                        ),
                      ],
                      if (progress != null) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(999),
                                child: LinearProgressIndicator(
                                  value: progress!.clamp(0.0, 1.0),
                                  minHeight: 3,
                                  backgroundColor: t.segmentTrack,
                                  color: t.goldSoft,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${(progress!.clamp(0.0, 1.0) * 100).round()}٪',
                              style: TextStyle(
                                fontFamily: kFontUi,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: t.muted,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                if (!selecting && trailing != null) ...[
                  const SizedBox(width: 8),
                  trailing!,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  _DashedBorderPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final r = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );
    final path = Path()..addRRect(r);
    for (final metric in path.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        final next = (d + 4).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(d, next), paint);
        d += 8;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.radius != radius;
}
