import 'package:flutter/material.dart';

import 'package:ishamela/ui/glass/glass_surface.dart';
import 'package:ishamela/ui/theme/ishamela_tokens.dart';
import 'package:ishamela/ui/theme/ishamela_theme.dart';

/// Segmented control on [IshamelaTokens.segmentTrack] (DESIGN-001 §3).
class SegmentedPills extends StatelessWidget {
  const SegmentedPills({
    super.key,
    required this.labels,
    required this.selectedIndex,
    required this.onChanged,
    this.fitLabels = false,
  });

  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  /// Longer labels take more of the bar and scale down instead of ellipsizing.
  final bool fitLabels;

  @override
  Widget build(BuildContext context) {
    final t = IshamelaTokens.of(context);
    final glass = glassChromeTokens(context);
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: glass == null
            ? t.segmentTrack
            : glass.activeCapsule.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: glass == null ? null : Border.all(color: glass.stroke),
      ),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              flex: fitLabels ? _labelFlex(labels[i]) : 1,
              child: _Segment(
                label: labels[i],
                selected: i == selectedIndex,
                onTap: () => onChanged(i),
                fitLabel: fitLabels,
              ),
            ),
        ],
      ),
    );
  }
}

int _labelFlex(String label) {
  final n = label.runes.length;
  return n < 1 ? 1 : n;
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.fitLabel,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool fitLabel;

  @override
  Widget build(BuildContext context) {
    final t = IshamelaTokens.of(context);
    final glass = glassChromeTokens(context);
    final selectedColor = glass?.activeCapsule ?? t.card;
    final labelColor = glass == null
        ? (selected ? t.emphasis : t.muted)
        : (selected ? glass.foregroundAccent : glass.foregroundInk);
    final style = TextStyle(
      fontFamily: kFontUi,
      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
      fontSize: 13,
      color: labelColor,
    );
    return Material(
      color: selected ? selectedColor : const Color(0x00000000),
      shape: StadiumBorder(
        side: selected && glass == null
            ? BorderSide(color: t.hairline)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: fitLabel ? 2 : 0,
            vertical: 10,
          ),
          child: fitLabel
              ? FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    style: style,
                  ),
                )
              : Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: style,
                ),
        ),
      ),
    );
  }
}
