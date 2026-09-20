import 'package:flutter/material.dart';

import 'package:ishamela/ui/theme/ishamela_tokens.dart';
import 'package:ishamela/ui/theme/ishamela_theme.dart';

/// Shared pill search field (DESIGN-001 §3).
class AppSearchField extends StatefulWidget {
  const AppSearchField({
    super.key,
    required this.hintText,
    required this.onChanged,
    this.initialQuery = '',
    this.onSubmitted,
    this.autofocus = false,
  });

  final String hintText;
  final String initialQuery;
  final ValueChanged<String> onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool autofocus;

  @override
  State<AppSearchField> createState() => _AppSearchFieldState();
}

class _AppSearchFieldState extends State<AppSearchField> {
  late final TextEditingController _ctrl;
  late final FocusNode _focus;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialQuery);
    _focus = FocusNode()..addListener(() => setState(() {}));
  }

  @override
  void didUpdateWidget(covariant AppSearchField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Sync external query updates (e.g. catalog pending jump) without
    // remounting — remounting via ValueKey(query) steals focus on each key.
    if (widget.initialQuery != oldWidget.initialQuery &&
        widget.initialQuery != _ctrl.text) {
      _ctrl.value = TextEditingValue(
        text: widget.initialQuery,
        selection: TextSelection.collapsed(offset: widget.initialQuery.length),
      );
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = IshamelaTokens.of(context);
    final focused = _focus.hasFocus;
    return TextField(
      controller: _ctrl,
      focusNode: _focus,
      autofocus: widget.autofocus,
      style: const TextStyle(
        fontFamily: kFontUi,
        fontWeight: FontWeight.w500,
        fontSize: 14,
      ),
      decoration: InputDecoration(
        hintText: widget.hintText,
        prefixIcon: Icon(Icons.search, color: t.muted),
        filled: true,
        fillColor: t.card,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(999),
          borderSide: BorderSide(color: t.hairline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(999),
          borderSide: BorderSide(color: t.hairline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(999),
          borderSide: BorderSide(
            color: t.green700,
            width: focused ? 1.5 : 1,
          ),
        ),
        suffixIcon: IconButton(
          icon: Icon(
            _ctrl.text.isEmpty ? Icons.search : Icons.clear,
            color: t.muted,
          ),
          onPressed: _ctrl.text.isEmpty
              ? null
              : () {
                  _ctrl.clear();
                  widget.onChanged('');
                  setState(() {});
                  _focus.requestFocus();
                },
        ),
      ),
      textInputAction: TextInputAction.search,
      onChanged: (v) {
        setState(() {});
        widget.onChanged(v);
      },
      onSubmitted: widget.onSubmitted,
    );
  }
}
