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

/// One Shamela contents heading, in the order it was stored.
class TocHeading {
  const TocHeading({
    required this.titleId,
    required this.shamelaTitleId,
    required this.title,
    this.parentId,
  });

  final int titleId;
  final int shamelaTitleId;
  final int? parentId;
  final String title;
}

/// A node in the contents tree. [titleId] is the Shamela title id.
class TocTreeNode {
  TocTreeNode({required this.titleId, required this.title});

  final int titleId;
  final String title;
  final List<TocTreeNode> children = [];
}

/// Dart's `\b` is an ASCII boundary, so it never matches after an Arabic word.
/// The lookahead is that boundary: the keyword must not continue into more
/// Arabic letters (`كتاب` matches, `كتابي` does not).
final bookRegex = RegExp(
  r'^(كتاب|مقدمة|\[مقدمة|المجلد|الجزء)(?![\u0600-\u06FF])',
);
final chapterRegex = RegExp(
  r'^(باب|فصل|مطلب|مبحث|\[باب|تابع)(?![\u0600-\u06FF])',
);

/// Contents tree in `shamela_title_id` order.
///
/// A heading whose parent is already in the tree hangs on that parent. A book
/// title otherwise starts a root and clears the chapter. A chapter title hangs
/// on the current book. Anything else hangs on the current chapter, then the
/// current book, then the top level.
List<TocTreeNode> buildTocTree(List<TocHeading> items) {
  final sorted = [...items]
    ..sort((a, b) {
      final byTitle = a.shamelaTitleId.compareTo(b.shamelaTitleId);
      if (byTitle != 0) return byTitle;
      return a.titleId.compareTo(b.titleId);
    });
  final nodeMap = <int, TocTreeNode>{};
  final roots = <TocTreeNode>[];
  TocTreeNode? currentBook;
  TocTreeNode? currentChapter;
  for (final item in sorted) {
    final title = item.title.trim();
    final node = TocTreeNode(titleId: item.titleId, title: title);
    nodeMap[item.titleId] = node;
    final parentId = item.parentId;
    if (parentId != null && nodeMap.containsKey(parentId)) {
      nodeMap[parentId]!.children.add(node);
      if (chapterRegex.hasMatch(title)) currentChapter = node;
    } else if (bookRegex.hasMatch(title) && !chapterRegex.hasMatch(title)) {
      roots.add(node);
      currentBook = node;
      currentChapter = null;
    } else if (chapterRegex.hasMatch(title)) {
      (currentBook?.children ?? roots).add(node);
      currentChapter = node;
    } else {
      (currentChapter?.children ?? currentBook?.children ?? roots).add(node);
    }
  }
  return roots;
}

/// Parent id of each [titleIds] entry, aligned with that list.
List<int?> tocTreeParentIds(List<TocTreeNode> roots, List<int> titleIds) {
  final parentOf = <int, int?>{};
  void walk(TocTreeNode node, int? parent) {
    parentOf[node.titleId] = parent;
    for (final child in node.children) {
      walk(child, node.titleId);
    }
  }

  for (final root in roots) {
    walk(root, null);
  }
  return [for (final id in titleIds) parentOf[id]];
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
      forced.addAll(tocPathIds(ids: ids, parentIds: parentIds, index: i));
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
        expanded: searching
            ? showsChild.contains(id)
            : expandedIds.contains(id),
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
