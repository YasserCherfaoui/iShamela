import 'package:flutter/material.dart';

import 'package:ishamela/ui/app_search_field.dart';

/// Isolated search field so parent `setState` does not steal focus (SPEC-009 UX).
/// Thin wrapper over [AppSearchField] (DESIGN-001).
class CatalogSearchField extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return AppSearchField(
      hintText: hintText,
      initialQuery: initialQuery,
      onChanged: onChanged,
    );
  }
}
