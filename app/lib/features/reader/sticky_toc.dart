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

/// One contents row the pane should draw.
class TocVisibleRow {
  const TocVisibleRow({
    required this.index,
    required this.depth,
    required this.hasChildren,
    required this.expanded,
  });

  final int index;
  final int depth;
  final bool hasChildren;
  final bool expanded;
}

/// Parent ids with a missing third level filled in.
///
/// Shamela stores كتاب → باب, then leaves the following مسألة and فصل rows
/// with a null parent. Those rows belong to the باب they follow. A كتاب,
/// مقدمة, or bracketed heading stays a root and starts a new section.
List<int?> tocInferredParents({
  required List<int> ids,
  required List<int?> parentIds,
  required List<String> titles,
}) {
  assert(ids.length == parentIds.length && ids.length == titles.length);
  final known = ids.toSet();
  final out = List<int?>.filled(ids.length, null);
  int? section;
  for (var i = 0; i < ids.length; i++) {
    final parent = parentIds[i];
    if (parent != null && known.contains(parent)) {
      out[i] = parent;
      section = ids[i];
      continue;
    }
    if (_startsNewSection(titles[i])) {
      out[i] = null;
      section = null;
      continue;
    }
    out[i] = section;
  }
  return out;
}

bool _startsNewSection(String title) {
  final text = title.trim();
  return text.startsWith('كتاب') ||
      text.startsWith('مقدمة') ||
      text.startsWith('[');
}

/// Ids from [index] up through the root.
Set<int> tocPathIds({
  required List<int> ids,
  required List<int?> parentIds,
  required int index,
}) {
  assert(ids.length == parentIds.length);
  final byId = _indexById(ids);
  final path = <int>{};
  int? cur = ids[index];
  while (cur != null && path.add(cur)) {
    final i = byId[cur];
    if (i == null) break;
    cur = parentIds[i];
  }
  return path;
}

/// Rows whose ancestors are expanded.
///
/// A third level is drawn only when both headings above it are open.
///
/// When [matchIds] is set, collapse is ignored and the result is those ids
/// plus every ancestor.
List<TocVisibleRow> visibleTocRows({
  required List<int> ids,
  required List<int?> parentIds,
  required Set<int> expandedIds,
  Set<int>? matchIds,
}) {
  assert(ids.length == parentIds.length);
  final byId = _indexById(ids);
  final childCount = List<int>.filled(ids.length, 0);
  for (var i = 0; i < ids.length; i++) {
    final parent = parentIds[i];
    if (parent == null) continue;
    final pi = byId[parent];
    if (pi != null) childCount[pi]++;
  }
  final depths = tocIndentDepths(ids: ids, parentIds: parentIds);

  final forced = <int>{};
  if (matchIds != null) {
    for (final id in matchIds) {
      final i = byId[id];
      if (i == null) continue;
      forced.addAll(
        tocPathIds(ids: ids, parentIds: parentIds, index: i),
      );
    }
  }
  final showsChild = <int>{};
  if (matchIds != null) {
    for (var i = 0; i < ids.length; i++) {
      final parent = parentIds[i];
      if (parent != null && forced.contains(ids[i])) showsChild.add(parent);
    }
  }

  bool ancestorsOpen(int i) {
    var cur = parentIds[i];
    final seen = <int>{ids[i]};
    while (cur != null) {
      if (!seen.add(cur) || !expandedIds.contains(cur)) return false;
      final pi = byId[cur];
      if (pi == null) return false;
      cur = parentIds[pi];
    }
    return true;
  }

  final rows = <TocVisibleRow>[];
  for (var i = 0; i < ids.length; i++) {
    final id = ids[i];
    final searching = matchIds != null;
    if (searching && !forced.contains(id)) continue;
    if (!searching && !ancestorsOpen(i)) continue;
    rows.add(
      TocVisibleRow(
        index: i,
        depth: depths[i],
        hasChildren: childCount[i] > 0,
        expanded: searching ? showsChild.contains(id) : expandedIds.contains(id),
      ),
    );
  }
  return rows;
}

Map<int, int> _indexById(List<int> ids) {
  final byId = <int, int>{};
  for (var i = 0; i < ids.length; i++) {
    byId[ids[i]] = i;
  }
  return byId;
}
