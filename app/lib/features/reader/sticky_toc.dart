/// Sticky TOC selection (SPEC-012).
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
