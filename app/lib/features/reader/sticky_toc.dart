/// Sticky TOC selection (SPEC-012) + DESIGN-001 indent depths.
library;

/// Returns the TOC list index that should stay highlighted for [currentPageId].
///
/// [tocPageIds] are `toc.page_id` values in display order. Never returns null
/// when [tocPageIds] is non-empty: last entry with `page_id <= current`, or
/// the first entry if the current page precedes every TOC target.
int stickyTocIndex(List<int> tocPageIds, int currentPageId) {
  if (tocPageIds.isEmpty) {
    throw ArgumentError('tocPageIds must not be empty');
  }
  var best = 0;
  var found = false;
  for (var i = 0; i < tocPageIds.length; i++) {
    if (tocPageIds[i] <= currentPageId) {
      best = i;
      found = true;
    }
  }
  return found ? best : 0;
}

/// Nesting depth for each TOC row from `parent_id` links (0 = root).
List<int> tocIndentDepths({
  required List<int> ids,
  required List<int?> parentIds,
}) {
  assert(ids.length == parentIds.length);
  final byId = <int, int>{};
  for (var i = 0; i < ids.length; i++) {
    byId[ids[i]] = i;
  }
  int depthAt(int i) {
    var d = 0;
    var cur = parentIds[i];
    final seen = <int>{ids[i]};
    while (cur != null) {
      final pi = byId[cur];
      if (pi == null || !seen.add(cur)) break;
      d++;
      cur = parentIds[pi];
    }
    return d;
  }

  return [for (var i = 0; i < ids.length; i++) depthAt(i)];
}
