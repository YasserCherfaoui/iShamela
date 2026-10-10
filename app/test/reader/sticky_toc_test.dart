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
    expect(tocPathIds(ids: ids, parentIds: parents, index: 3), {4, 2, 1});

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

  List<int> idsOf(List<TocTreeNode> nodes) => [
    for (final node in nodes) node.titleId,
  ];

  test('books, chapters, and leaves follow shamela title order', () {
    final roots = buildTocTree(const [
      TocHeading(titleId: 1, shamelaTitleId: 1, title: 'المجلد الأول'),
      TocHeading(titleId: 2, shamelaTitleId: 2, title: 'كتاب الطهارة'),
      TocHeading(titleId: 3, shamelaTitleId: 3, title: 'باب المياه'),
      TocHeading(titleId: 4, shamelaTitleId: 4, title: 'مسألة في الماء'),
      TocHeading(titleId: 5, shamelaTitleId: 5, title: '[باب الغسل]'),
      TocHeading(titleId: 6, shamelaTitleId: 6, title: 'بيت من الشعر'),
    ]);
    expect(idsOf(roots), [1, 2]);
    expect(idsOf(roots[1].children), [3, 5]);
    expect(idsOf(roots[1].children[0].children), [4]);
    expect(idsOf(roots[1].children[1].children), [6]);

    const ids = [1, 2, 3, 4, 5, 6];
    final parents = tocTreeParentIds(roots, ids);
    expect(parents, [null, null, 2, 3, 2, 5]);
    final closed = visibleTocRows(
      ids: ids,
      parentIds: parents,
      expandedIds: const {},
    );
    expect(closed.map((row) => row.index), [0, 1]);
    final chapterOpen = visibleTocRows(
      ids: ids,
      parentIds: parents,
      expandedIds: const {2, 5},
    );
    expect(chapterOpen.map((row) => row.index), [0, 1, 2, 4, 5]);
    expect(chapterOpen.last.depth, 2);
  });

  test('a new book clears the chapter', () {
    final roots = buildTocTree(const [
      TocHeading(titleId: 1, shamelaTitleId: 1, title: 'كتاب الطهارة'),
      TocHeading(titleId: 2, shamelaTitleId: 2, title: 'باب المياه'),
      TocHeading(titleId: 3, shamelaTitleId: 3, title: 'مسألة'),
      TocHeading(titleId: 4, shamelaTitleId: 4, title: 'كتاب الصلاة'),
      TocHeading(titleId: 5, shamelaTitleId: 5, title: 'فصل في الأوقات'),
    ]);
    expect(idsOf(roots), [1, 4]);
    expect(idsOf(roots[0].children), [2]);
    expect(idsOf(roots[0].children.single.children), [3]);
    expect(idsOf(roots[1].children), [5]);
  });

  test('leaves before any book stay at the top level', () {
    final roots = buildTocTree(const [
      TocHeading(titleId: 1, shamelaTitleId: 1, title: 'الإهداء'),
      TocHeading(titleId: 2, shamelaTitleId: 2, title: 'مسألة'),
      TocHeading(titleId: 3, shamelaTitleId: 3, title: 'بيت من الشعر'),
    ]);
    expect(idsOf(roots), [1, 2, 3]);
  });

  test('a known parent wins, and a chapter title updates the chapter', () {
    final roots = buildTocTree(const [
      TocHeading(titleId: 1, shamelaTitleId: 1, title: 'كتاب الطهارة'),
      TocHeading(
        titleId: 2,
        shamelaTitleId: 2,
        parentId: 1,
        title: 'أنواع المياه',
      ),
      TocHeading(
        titleId: 3,
        shamelaTitleId: 3,
        parentId: 1,
        title: 'باب المياه',
      ),
      TocHeading(titleId: 4, shamelaTitleId: 4, title: 'مسألة'),
    ]);
    expect(idsOf(roots.single.children), [2, 3]);
    expect(idsOf(roots.single.children[1].children), [4]);
  });

  test(
    'a parented book stays under its volume and does not take the chapter',
    () {
      final roots = buildTocTree(const [
        TocHeading(titleId: 1, shamelaTitleId: 1, title: 'المجلد الأول'),
        TocHeading(
          titleId: 2,
          shamelaTitleId: 2,
          parentId: 1,
          title: 'كتاب الطهارة',
        ),
        TocHeading(titleId: 3, shamelaTitleId: 3, title: 'مسألة'),
        TocHeading(titleId: 4, shamelaTitleId: 4, title: '[مقدمة التحقيق]'),
        TocHeading(titleId: 5, shamelaTitleId: 5, title: '[مخطوطات المقنع]'),
      ]);
      expect(idsOf(roots), [1, 4]);
      expect(idsOf(roots[0].children), [2, 3]);
      expect(idsOf(roots[1].children), [5]);
    },
  );

  test('only chapter titles move the chapter pointer', () {
    final roots = buildTocTree(const [
      TocHeading(titleId: 1, shamelaTitleId: 1, title: 'كتاب الطهارة'),
      TocHeading(titleId: 2, shamelaTitleId: 2, title: 'ثم نعود إلى المسألة'),
      TocHeading(titleId: 3, shamelaTitleId: 3, title: 'تابع الكلام'),
      TocHeading(titleId: 4, shamelaTitleId: 4, title: 'مسألة'),
    ]);
    expect(idsOf(roots.single.children), [2, 3]);
    expect(idsOf(roots.single.children[1].children), [4]);
  });

  test('entries are ordered by shamela title id, not page id', () {
    final roots = buildTocTree(const [
      TocHeading(titleId: 10, shamelaTitleId: 2, title: 'باب المياه'),
      TocHeading(titleId: 1, shamelaTitleId: 1, title: 'كتاب الطهارة'),
    ]);
    expect(roots.single.titleId, 1);
    expect(roots.single.children.single.titleId, 10);
  });

  test('a keyword must end before the next Arabic letter', () {
    final roots = buildTocTree(const [
      TocHeading(titleId: 1, shamelaTitleId: 1, title: 'كتابي في الفقه'),
      TocHeading(titleId: 2, shamelaTitleId: 2, title: 'كتاب الطهارة'),
    ]);
    expect(idsOf(roots), [1, 2]);
    expect(roots[0].children, isEmpty);
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
