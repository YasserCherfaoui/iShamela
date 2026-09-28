import 'package:flutter/material.dart';

import 'package:ishamela/ui/glass/glass_surface.dart';
import 'package:ishamela/ui/theme/ishamela_theme.dart';

/// Filter chip that turns into a soft glass capsule when it sits on glass chrome.
/// Manuscript styling is unchanged.
class GlassFilterChip extends StatelessWidget {
  const GlassFilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onSelected,
    this.selectedColor,
    this.checkmarkColor,
    this.labelColor,
    this.side,
  });

  final Widget label;
  final bool selected;
  final ValueChanged<bool> onSelected;
  final Color? selectedColor;
  final Color? checkmarkColor;
  final Color? labelColor;
  final BorderSide? side;

  @override
  Widget build(BuildContext context) {
    final glass = glassChromeTokens(context);
    final fg = glass == null
        ? labelColor
        : (selected ? glass.foregroundAccent : glass.foregroundInk);
    return FilterChip(
      label: fg == null
          ? label
          : DefaultTextStyle.merge(
              style: TextStyle(
                fontFamily: kFontUi,
                fontWeight: FontWeight.w600,
                color: fg,
              ),
              child: label,
            ),
      selected: selected,
      onSelected: onSelected,
      backgroundColor: glass == null ? null : const Color(0x00000000),
      selectedColor: glass?.activeCapsule ?? selectedColor,
      checkmarkColor: glass?.foregroundAccent ?? checkmarkColor,
      side: glass == null ? side : BorderSide(color: glass.stroke),
      labelStyle: fg == null
          ? null
          : TextStyle(
              fontFamily: kFontUi,
              fontWeight: FontWeight.w600,
              color: fg,
            ),
    );
  }
}
