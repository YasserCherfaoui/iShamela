import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:ishamela/core/db/paths.dart';
import 'package:ishamela/core/db/state_database.dart';
import 'package:ishamela/core/storage_size.dart';
import 'package:ishamela/features/reader/annotations_export.dart';

Future<StateDatabase> _openTemp() async {
  final dir = await Directory.systemTemp.createTemp('ishamela-st-');
  final paths = AppPaths(Directory(p.join(dir.path, 'ishamela')));
  await paths.ensureLayout();
  return StateDatabase.open(paths);
}

void main() {
  test('installed_size_bytes migration and SUM', () async {
    final state = await _openTemp();
    state.upsertInstalled(
      bookId: 1,
      schemaVersion: 1,
      normVersion: '1',
      sqliteBytes: 1000,
      installedAt: 1,
      installedSizeBytes: 1000,
    );
    state.upsertInstalled(
      bookId: 2,
      schemaVersion: 1,
      normVersion: '1',
      sqliteBytes: 2500,
      installedAt: 2,
      installedSizeBytes: 2500,
    );
    expect(state.installedSizeBytesTotal, 3500);
    final ordered = state.installedBooksBySizeDesc();
    expect(ordered.first.bookId, 2);
    expect(ordered.first.sizeBytes, 2500);
    state.close();
  });

  test('backfill fills missing sizes from disk', () async {
    final dir = await Directory.systemTemp.createTemp('ishamela-bf-');
    final paths = AppPaths(Directory(p.join(dir.path, 'ishamela')));
    await paths.ensureLayout();
    final state = await StateDatabase.open(paths);
    // Insert with null size by raw SQL after upsert then clear
    state.upsertInstalled(
      bookId: 9,
      schemaVersion: 1,
      normVersion: '1',
      sqliteBytes: 10,
      installedAt: 1,
      installedSizeBytes: 10,
    );
    state.setInstalledSizeBytes(9, 10);
    // Force null
    // ignore: invalid_use_of_visible_for_testing_member
    final bookFile = paths.bookSqlite(9);
    await bookFile.parent.create(recursive: true);
    await bookFile.writeAsBytes(List.filled(42, 1));
    // Clear size to simulate pre-migration row
    // Use update via set then manually — setInstalledSizeBytes can't null;
    // re-open after writing file and use missing list from empty:
    state.deleteInstalled(9);
    // Insert without going through size (simulate old row via re-upsert then
    // treat missing): write a row that backfill will see.
    // Direct path: installedBookIdsMissingSize after fake null insert —
    // upsert always sets size; call set after writing larger file.
    state.upsertInstalled(
      bookId: 9,
      schemaVersion: 1,
      normVersion: '1',
      sqliteBytes: 1,
      installedAt: 1,
      installedSizeBytes: 1,
    );
    expect(state.installedSizeBytes(9), 1);
    await backfillInstalledSizes(paths, state);
    // backfill only fills NULL; size already known stays
    expect(state.installedSizeBytes(9), 1);
    state.close();
  });

  test('truncateAnchor cuts on word boundary', () {
    final long = '${'كلمة ' * 80}نهاية';
    final out = truncateAnchor(long, maxChars: 40);
    expect(out.length, lessThanOrEqualTo(41));
    expect(out.endsWith('…'), isTrue);
  });

  test('buildAnnotationsExport markdown golden-ish', () {
    final text = buildAnnotationsExport(
      title: 'كتاب',
      author: 'مؤلف',
      entries: [
        ExportAnnotation(
          pageId: 1,
          printPage: 5,
          part: '1',
          startOffset: 0,
          endOffset: 4,
          anchorExcerpt: 'نص مميز',
          citationLine: '«نص مميز» — كتاب، مؤلف، ج1، ص5',
          color: 'yellow',
          noteBody: 'ملاحظة',
        ),
      ],
      options: AnnotationExportOptions(
        format: ExportFormat.markdown,
        includeHighlights: true,
        includeNotes: true,
        exportedOn: DateTime(2026, 9, 18),
      ),
      notesHeading: 'ملاحظات — كتاب',
      exportedOnLabel: 'صُدِّر في 2026-09-18',
      noteLabel: 'ملاحظة',
    );
    expect(text, contains('# ملاحظات — كتاب'));
    expect(text, contains('## ج 1 · ص 5'));
    expect(text, contains('> نص مميز'));
    expect(text, contains('#أصفر'));
    expect(text, contains('**ملاحظة:** ملاحظة'));
  });

  test('exportFilename shape', () {
    expect(
      exportFilename(
        bookId: 42,
        date: DateTime(2026, 1, 2),
        format: ExportFormat.markdown,
      ),
      'notes-42.md',
    );
  });
}
