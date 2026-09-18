/// Citation formatter (SPEC-005 / SPEC-010).
library;

String formatCitation({
  required String excerpt,
  required String title,
  required String author,
  String? part,
  int? pageNumber,
  required bool arabic,
}) {
  final ex = excerpt.trim().replaceAll(RegExp(r'\s+'), ' ');
  final page = pageNumber?.toString() ?? '—';
  if (arabic) {
    final partBit =
        (part != null && part.isNotEmpty) ? '، ج$part' : '';
    return '«$ex» — $title، $author$partBit، ص$page';
  }
  final partBit =
      (part != null && part.isNotEmpty) ? ', vol. $part' : '';
  return '"$ex" — $title, $author$partBit, p. $page';
}

const highlightColors = <String, int>{
  'yellow': 0xFFFFE082, // amber.200-ish
  'green': 0xFFA5D6A7,
  'blue': 0xFF81D4FA,
  'pink': 0xFFF48FB1,
  'orange': 0xFFFFCC80,
};
