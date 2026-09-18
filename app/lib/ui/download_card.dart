import 'package:flutter/material.dart';

import 'package:ishamela/ui/theme/ishamela_tokens.dart';
import 'package:ishamela/ui/theme/ishamela_theme.dart';

enum DownloadCardTone { active, paused, failed, completed }

/// Download queue row card (DESIGN-001 §3) — layout only; ≤2 trailing actions.
class DownloadCard extends StatelessWidget {
  const DownloadCard({
    super.key,
    required this.title,
    required this.statusLabel,
    this.tone = DownloadCardTone.active,
    this.progress,
    this.caption,
    this.errorText,
    this.primaryAction,
    this.secondaryAction,
    this.onTap,
    this.onLongPress,
    this.selected,
    this.onSelectedChanged,
  });

  final String title;
  final String statusLabel;
  final DownloadCardTone tone;
  final double? progress;
  final String? caption;
  final String? errorText;
  final Widget? primaryAction;
  final Widget? secondaryAction;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool? selected;
  final ValueChanged<bool?>? onSelectedChanged;

  @override
  Widget build(BuildContext context) {
    final t = IshamelaTokens.of(context);
    final selecting = selected != null;
    final statusColor = switch (tone) {
      DownloadCardTone.active => t.green700,
      DownloadCardTone.paused => t.gold,
      DownloadCardTone.failed => const Color(0xFFA6402E),
      DownloadCardTone.completed => t.green900,
    };
    final barColor = switch (tone) {
      DownloadCardTone.active => t.green700,
      DownloadCardTone.paused => t.gold,
      DownloadCardTone.failed => null,
      DownloadCardTone.completed => null,
    };

    return Material(
      color: t.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: t.hairline),
      ),
      child: InkWell(
        onTap: selecting
            ? () => onSelectedChanged?.call(!(selected ?? false))
            : onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              if (selecting) ...[
                Checkbox(
                  value: selected,
                  onChanged: onSelectedChanged,
                ),
                const SizedBox(width: 4),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: kFontAmiri,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: t.ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      statusLabel,
                      style: TextStyle(
                        fontFamily: kFontUi,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                        color: statusColor,
                      ),
                    ),
                    if (barColor != null && progress != null) ...[
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          value: progress!.clamp(0.0, 1.0),
                          minHeight: 5,
                          backgroundColor: t.segmentTrack,
                          color: barColor,
                        ),
                      ),
                    ],
                    if (caption != null && caption!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        caption!,
                        style: TextStyle(
                          fontFamily: kFontUi,
                          fontSize: 11,
                          color: t.muted,
                        ),
                      ),
                    ],
                    if (errorText != null && errorText!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        errorText!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: kFontUi,
                          fontSize: 11,
                          color: Color(0xFFA6402E),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (!selecting) ...[
                if (primaryAction != null) primaryAction!,
                if (secondaryAction != null) secondaryAction!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}
