import 'package:flutter/material.dart';

import 'package:ishamela/features/reader/citation.dart';
import 'package:ishamela/l10n/app_localizations.dart';
import 'package:ishamela/ui/theme/ishamela_tokens.dart';
import 'package:ishamela/ui/theme/reader_theme_tokens.dart';

/// Floating pill selection toolbar (DESIGN-001 §3).
class SelectionToolbar extends StatelessWidget {
  const SelectionToolbar({
    super.key,
    required this.anchors,
    required this.onHighlight,
    required this.onNote,
    required this.onCite,
    this.onClear,
  });

  final TextSelectionToolbarAnchors anchors;
  final ValueChanged<String> onHighlight;
  final VoidCallback onNote;
  final VoidCallback onCite;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final t = IshamelaTokens.of(context);
    final reader = ReaderThemeTokens.of(context);
    final night = reader.atmosphere == ReadingAtmosphere.night;
    final colors = night ? highlightColorsNight : highlightColors;

    // Prefer primary (above selection) then secondary.
    final pos = anchors.primaryAnchor;
    return Stack(
      children: [
        Positioned(
          left: (pos.dx - 140).clamp(8.0, MediaQuery.sizeOf(context).width - 288),
          top: (pos.dy - 56).clamp(8.0, MediaQuery.sizeOf(context).height - 64),
          child: Material(
            elevation: 0,
            color: reader.raised,
            shape: StadiumBorder(side: BorderSide(color: reader.hairline)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final e in colors.entries)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: InkWell(
                        onTap: () => onHighlight(e.key),
                        customBorder: const CircleBorder(),
                        child: Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color: Color(e.value),
                            shape: BoxShape.circle,
                            border: Border.all(color: t.hairline),
                          ),
                        ),
                      ),
                    ),
                  if (onClear != null) ...[
                    const SizedBox(width: 2),
                    Tooltip(
                      message: AppLocalizations.of(context).removeHighlight,
                      child: _ToolBtn(
                        icon: Icons.format_color_reset_outlined,
                        color: reader.body,
                        onTap: onClear!,
                      ),
                    ),
                  ],
                  Container(
                    width: 1,
                    height: 22,
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    color: reader.hairline,
                  ),
                  _ToolBtn(
                    icon: Icons.sticky_note_2_outlined,
                    color: reader.body,
                    onTap: onNote,
                  ),
                  const SizedBox(width: 4),
                  _ToolBtn(
                    icon: Icons.format_quote_rounded,
                    color: reader.body,
                    onTap: onCite,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ToolBtn extends StatelessWidget {
  const _ToolBtn({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Icon(icon, size: 20, color: color),
      ),
    );
  }
}
