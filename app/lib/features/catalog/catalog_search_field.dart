import 'package:flutter/material.dart';

/// Isolated search field so parent `setState` does not steal focus (SPEC-009 UX).
class CatalogSearchField extends StatefulWidget {
  const CatalogSearchField({
    super.key,
    required this.hintText,
    required this.onChanged,
    this.initialQuery = '',
  });

  final String hintText;
  final String initialQuery;
  final ValueChanged<String> onChanged;

  @override
  State<CatalogSearchField> createState() => _CatalogSearchFieldState();
}

class _CatalogSearchFieldState extends State<CatalogSearchField> {
  late final TextEditingController _ctrl;
  late final FocusNode _focus;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialQuery);
    _focus = FocusNode();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _ctrl,
      focusNode: _focus,
      decoration: InputDecoration(
        hintText: widget.hintText,
        prefixIcon: const Icon(Icons.search),
        border: const OutlineInputBorder(),
        suffixIcon: IconButton(
          icon: Icon(_ctrl.text.isEmpty ? Icons.search : Icons.clear),
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
        setState(() {}); // refresh clear affordance only
        widget.onChanged(v);
      },
    );
  }
}
