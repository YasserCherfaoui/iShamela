import 'package:flutter_test/flutter_test.dart';

import 'package:ishamela/core/db/paths.dart';
import 'package:ishamela/core/db/state_database.dart';
import 'package:ishamela/features/reader/body_display_map.dart';
import 'package:ishamela/features/reader/citation.dart';
import 'package:path/path.dart' as p;
import 'dart:io';

void main() {
  test('formatCitation arabic and english templates', () {
    expect(
      formatCitation(
        excerpt: 'نص',
        title: 'كتاب',
        author: 'مؤلف',
        part: '1',
        pageNumber: 10,
        arabic: true,
      ),
      '«نص» — كتاب، مؤلف، ج1، ص10',
    );
    expect(
      formatCitation(
        excerpt: 'hello',
        title: 'Book A',
        author: 'Author A',
        pageNumber: 10,
        arabic: false,
      ),
      '"hello" — Book A, Author A, p. 10',
    );
    expect(
      formatCitation(
        excerpt: 'x',
        title: 'T',
        author: 'A',
        arabic: false,
      ),
      '"x" — T, A, p. —',
    );
  });

  test('formatCitation keeps long excerpts in full', () {
    final long = 'a' * 300;
    final out = formatCitation(
      excerpt: long,
      title: 'T',
      author: 'A',
      pageNumber: 1,
      arabic: false,
    );
    expect(out.contains('…'), isFalse);
    expect(out.contains(long), isTrue);
  });

  test('BodyDisplayMap maps around HTML tags', () {
    const body = 'a<b>bc</b>d';
    final map = BodyDisplayMap.fromBody(body);
    expect(map.display, 'abcd');
    final (bs, be) = map.toBodyRange(1, 3); // "bc"
    expect(body.substring(bs, be), 'bc');
    final (ds, de) = map.toDisplayRange(bs, be);
    expect(map.display.substring(ds, de), 'bc');
  });

  test('highlights and notes persist in state.sqlite', () async {
    final dir = await Directory.systemTemp.createTemp('ishamela-ann-');
    final paths = AppPaths(Directory(p.join(dir.path, 'ishamela')));
    await paths.ensureLayout();
    final state = await StateDatabase.open(paths);

    final hid = state.insertHighlight(
      bookId: 1,
      pageId: 2,
      start: 0,
      end: 4,
      color: 'yellow',
      createdAt: 100,
    );
    expect(hid, greaterThan(0));
    final hs = state.highlightsForPage(1, 2);
    expect(hs, hasLength(1));
    expect(hs.first['color'], 'yellow');

    final nid = state.insertNote(
      bookId: 1,
      pageId: 2,
      start: 1,
      end: 3,
      note: 'note',
      createdAt: 101,
    );
    expect(nid, greaterThan(0));
    expect(state.notesForPage(1, 2), hasLength(1));
    state.updateNote(nid, 'updated');
    expect(state.notesForPage(1, 2).first['note'], 'updated');
    state.deleteNote(nid);
    expect(state.notesForPage(1, 2), isEmpty);
    state.deleteHighlight(hid);
    expect(state.highlightsForPage(1, 2), isEmpty);

    state.close();
    await dir.delete(recursive: true);
  });
}
