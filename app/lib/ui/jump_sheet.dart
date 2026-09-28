import 'package:flutter/material.dart';

import 'package:ishamela/ui/glass/chrome/glass_sheet.dart';
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
  return showGlassSheet<void>(
    context: context,
    showDragHandle: true,
    backgroundColor: IshamelaTokens.of(context).card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) {
      return _JumpSheetBody(
        title: title,
        fieldHint: fieldHint,
        goLabel: goLabel,
        cancelLabel: cancelLabel,
        tocLabel: tocLabel,
        initialValue: initialValue,
        onGo: onGo,
        onOpenToc: onOpenToc,
      );
    },
  );
}

class _JumpSheetBody extends StatefulWidget {
  const _JumpSheetBody({
    required this.title,
    required this.fieldHint,
    required this.goLabel,
    required this.cancelLabel,
    required this.initialValue,
    required this.onGo,
    this.tocLabel,
    this.onOpenToc,
  });

  final String title;
  final String fieldHint;
  final String goLabel;
  final String cancelLabel;
  final String? tocLabel;
  final String? initialValue;
  final Future<bool> Function(String raw) onGo;
  final VoidCallback? onOpenToc;

  @override
  State<_JumpSheetBody> createState() => _JumpSheetBodyState();
}

class _JumpSheetBodyState extends State<_JumpSheetBody> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialValue ?? '');
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = IshamelaTokens.of(context);
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          8,
          20,
          20 + MediaQuery.paddingOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.title,
              style: TextStyle(
                fontFamily: kFontAmiri,
                fontWeight: FontWeight.w700,
                fontSize: 20,
                color: t.ink,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _ctrl,
              keyboardType: TextInputType.number,
              autofocus: true,
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                hintText: widget.fieldHint,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(widget.cancelLabel),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _submit,
                    child: Text(widget.goLabel),
                  ),
                ),
              ],
            ),
            if (widget.tocLabel != null && widget.onOpenToc != null) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: () {
                  final openToc = widget.onOpenToc;
                  Navigator.pop(context);
                  openToc?.call();
                },
                child: Text(widget.tocLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final ok = await widget.onGo(_ctrl.text);
    if (ok && mounted) Navigator.pop(context);
  }
}
