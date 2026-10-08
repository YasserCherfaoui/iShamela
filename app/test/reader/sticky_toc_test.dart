import 'package:flutter_test/flutter_test.dart';

import 'package:ishamela/features/reader/sticky_toc.dart';

void main() {
  test('stickyTocIndex tracks section and always picks one', () {
    const ids = [10, 20, 30];
    expect(stickyTocIndex(ids, 5), 0);
    expect(stickyTocIndex(ids, 10), 0);
    expect(stickyTocIndex(ids, 15), 0);
    expect(stickyTocIndex(ids, 20), 1);
    expect(stickyTocIndex(ids, 25), 1);
    expect(stickyTocIndex(ids, 30), 2);
    expect(stickyTocIndex(ids, 99), 2);
  });

  test('tocIndentDepths follows parent_id chain', () {
    final depths = tocIndentDepths(
      ids: [1, 2, 3, 4],
      parentIds: [null, 1, 1, 2],
    );
    expect(depths, [0, 1, 1, 2]);
  });

  test('visible rows follow expanded ancestors', () {
    const ids = [1, 2, 3, 4];
    const parents = <int?>[null, 1, 1, 2];
    expect(
      tocPathIds(ids: ids, parentIds: parents, index: 3),
      {4, 2, 1},
    );

    final closed = visibleTocRows(
      ids: ids,
      parentIds: parents,
      expandedIds: const {},
    );
    expect(closed.map((row) => row.index), [0]);

    final branch = visibleTocRows(
      ids: ids,
      parentIds: parents,
      expandedIds: const {1},
    );
    expect(branch.map((row) => row.index), [0, 1, 2]);
    expect(branch[1].hasChildren, isTrue);
    expect(branch[1].expanded, isFalse);

    final open = visibleTocRows(
      ids: ids,
      parentIds: parents,
      expandedIds: const {1, 2},
    );
    expect(open.map((row) => row.index), [0, 1, 2, 3]);
  });

  test('three levels stay closed until each ancestor is opened', () {
    const ids = [1, 2, 3];
    const parents = <int?>[null, 1, 2];

    final roots = visibleTocRows(
      ids: ids,
      parentIds: parents,
      expandedIds: const {},
    );
    expect(roots.map((row) => row.index), [0]);
    expect(roots.single.hasChildren, isTrue);

    final twoLevels = visibleTocRows(
      ids: ids,
      parentIds: parents,
      expandedIds: const {1},
    );
    expect(twoLevels.map((row) => row.index), [0, 1]);
    expect(twoLevels[1].depth, 1);
    expect(twoLevels[1].hasChildren, isTrue);
    expect(twoLevels[1].expanded, isFalse);

    final threeLevels = visibleTocRows(
      ids: ids,
      parentIds: parents,
      expandedIds: const {1, 2},
    );
    expect(threeLevels.map((row) => row.index), [0, 1, 2]);
    expect(threeLevels[2].depth, 2);
    expect(threeLevels[2].hasChildren, isFalse);

    final rootClosed = visibleTocRows(
      ids: ids,
      parentIds: parents,
      expandedIds: const {2},
    );
    expect(rootClosed.map((row) => row.index), [0]);
  });

  test('orphan headings nest under the section they follow', () {
    const ids = [1, 2, 3, 4, 5, 6];
    const parents = <int?>[null, 1, null, null, 4, null];
    const titles = [
      'مقدمة التحقيق',
      '[١ - المقنع]',
      '[مخطوطات المقنع]',
      'كتاب الطهارة',
      'باب المياه',
      '١ - مسألة؛ قال: (وهو الباقي)',
    ];
    final inferred = tocInferredParents(
      ids: ids,
      parentIds: parents,
      titles: titles,
    );
    expect(inferred, [null, 1, null, null, 4, 5]);

    final closed = visibleTocRows(
      ids: ids,
      parentIds: inferred,
      expandedIds: const {},
    );
    expect(closed.map((row) => row.index), [0, 2, 3]);

    final bookOpen = visibleTocRows(
      ids: ids,
      parentIds: inferred,
      expandedIds: const {4},
    );
    expect(bookOpen.map((row) => row.index), [0, 2, 3, 4]);

    final chapterOpen = visibleTocRows(
      ids: ids,
      parentIds: inferred,
      expandedIds: const {4, 5},
    );
    expect(chapterOpen.map((row) => row.index), [0, 2, 3, 4, 5]);
    expect(chapterOpen.last.depth, 2);
  });

  test('a search shows the match and its ancestors', () {
    const ids = [1, 2, 3, 4];
    const parents = <int?>[null, 1, 1, 2];
    final rows = visibleTocRows(
      ids: ids,
      parentIds: parents,
      expandedIds: const {},
      matchIds: const {4},
    );
    expect(rows.map((row) => ids[row.index]), [1, 2, 4]);
    expect(rows[0].expanded, isTrue);
    expect(rows[2].expanded, isFalse);
  });
}
