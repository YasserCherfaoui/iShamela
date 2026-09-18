import 'package:flutter/material.dart';

import 'package:ishamela/ui/theme/ishamela_tokens.dart';
import 'package:ishamela/ui/theme/ishamela_theme.dart';

/// Jump-to-print-page sheet (DESIGN-001 §3 / §8). Caller supplies jump logic.
Future<void> showJumpSheet({
  required BuildContext context,
  required String title,
  required String fieldHint,
  required String goLabel,
  required String cancelLabel,
  String? tocLabel,
  String? initialValue,
  required Future<bool> Function(String raw) onGo,
  VoidCallback? onOpenToc,
}) {
  final ctrl = TextEditingController(text: initialValue ?? '');
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    backgroundColor: IshamelaTokens.of(context).card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) {
      final t = IshamelaTokens.of(ctx);
      return Directionality(
        textDirection: TextDirection.rtl,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            8,
            20,
            20 + MediaQuery.paddingOf(ctx).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontFamily: kFontAmiri,
                  fontWeight: FontWeight.w700,
                  fontSize: 20,
                  color: t.ink,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: ctrl,
                keyboardType: TextInputType.number,
                autofocus: true,
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  hintText: fieldHint,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onSubmitted: (_) async {
                  final ok = await onGo(ctrl.text);
                  if (ok && ctx.mounted) Navigator.pop(ctx);
                },
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: Text(cancelLabel),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () async {
                        final ok = await onGo(ctrl.text);
                        if (ok && ctx.mounted) Navigator.pop(ctx);
                      },
                      child: Text(goLabel),
                    ),
                  ),
                ],
              ),
              if (tocLabel != null && onOpenToc != null) ...[
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    onOpenToc();
                  },
                  child: Text(tocLabel),
                ),
              ],
            ],
          ),
        ),
      );
    },
  ).whenComplete(ctrl.dispose);
}
