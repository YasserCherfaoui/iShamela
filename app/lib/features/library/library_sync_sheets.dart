import 'package:flutter/material.dart';
import 'package:ishamela/l10n/app_localizations.dart';

import 'package:ishamela/core/arabic_digits.dart';
import 'package:ishamela/core/db/state_database.dart';
import 'package:ishamela/core/library/library_plan.dart';
import 'package:ishamela/features/downloads/download_service.dart';
import 'package:ishamela/ui/theme/ishamela_theme.dart';
import 'package:ishamela/ui/theme/ishamela_tokens.dart';

enum BookRemovalChoice { thisDevice, allDevices }

String libraryByteLabel(int bytes, {required bool arabic}) {
  final mb = bytes / (1024 * 1024);
  final raw = mb >= 10 ? mb.round().toString() : mb.toStringAsFixed(1);
  final unit = arabic ? 'م.ب' : 'MB';
  if (!arabic) return '$raw $unit';
  final buf = StringBuffer();
  for (final ch in raw.split('')) {
    buf.write(RegExp(r'\d').hasMatch(ch) ? toArabicIndicDigits(int.parse(ch)) : ch);
  }
  return '${buf.toString()} $unit';
}

Future<BookRemovalChoice?> showBookRemovalSheet(
  BuildContext context, {
  required bool signedIn,
}) {
  final l10n = AppLocalizations.of(context);
  final t = IshamelaTokens.of(context);
  if (!signedIn) {
    return showDialog<BookRemovalChoice>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: t.card,
        title: Text(l10n.delete),
        content: Text(l10n.libraryRemoveDevice),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, BookRemovalChoice.thisDevice),
            child: Text(l10n.confirm),
          ),
        ],
      ),
    );
  }
  return showModalBottomSheet<BookRemovalChoice>(
    context: context,
    backgroundColor: t.card,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            title: Text(l10n.libraryRemoveDevice),
            onTap: () => Navigator.pop(ctx, BookRemovalChoice.thisDevice),
          ),
          ListTile(
            title: Text(
              l10n.libraryRemoveAll,
              style: TextStyle(color: t.danger, fontFamily: kFontUi),
            ),
            onTap: () => Navigator.pop(ctx, BookRemovalChoice.allDevices),
          ),
          ListTile(
            title: Text(l10n.cancel),
            onTap: () => Navigator.pop(ctx),
          ),
        ],
      ),
    ),
  );
}

Future<void> applyBookRemoval({
  required BookRemovalChoice choice,
  required bool signedIn,
  required int bookId,
  required String title,
  required int sizeBytes,
  required int catalogVersion,
  required StateDatabase state,
  required DownloadService downloads,
  required Future<void> Function(List<LibraryDoc> docs) pushRemoved,
}) async {
  if (!signedIn) {
    await downloads.deleteInstalled(bookId);
    return;
  }
  final now = DateTime.now().millisecondsSinceEpoch;
  if (choice == BookRemovalChoice.allDevices) {
    await pushRemoved([
      LibraryDoc(
        bookId: bookId,
        title: title,
        sizeBytes: sizeBytes,
        catalogVersion: catalogVersion,
        status: LibraryStatus.removed,
        installedAt: state.installedAt(bookId) ?? now,
        updatedAt: now,
      ),
    ]);
    state.clearLibraryExclusion(bookId);
  } else {
    state.addLibraryExclusion(bookId);
  }
  await downloads.deleteInstalled(bookId);
}

class LibrarySetupResult {
  const LibrarySetupResult(this.choice, this.selected);
  final LibrarySetupChoice choice;
  final Set<int> selected;
}

Future<LibrarySetupResult?> showLibrarySetupSheet(
  BuildContext context, {
  required int bookCount,
  required int bytes,
  required List<int> bookIds,
  required String Function(int bookId) titleOf,
}) {
  final l10n = AppLocalizations.of(context);
  final t = IshamelaTokens.of(context);
  final arabic = Localizations.localeOf(context).languageCode == 'ar';
  final count = arabic ? toArabicIndicDigits(bookCount) : '$bookCount';
  final size = libraryByteLabel(bytes, arabic: arabic);
  return showModalBottomSheet<LibrarySetupResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: t.card,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.librarySetupTitle,
              style: TextStyle(
                fontFamily: kFontAmiri,
                fontWeight: FontWeight.w700,
                fontSize: 22,
                color: t.ink,
              ),
            ),
            const SizedBox(height: 8),
            Text(l10n.librarySetupBody(count, size)),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => Navigator.pop(
                ctx,
                LibrarySetupResult(LibrarySetupChoice.all, bookIds.toSet()),
              ),
              child: Text(l10n.libraryDownloadAll),
            ),
            TextButton(
              onPressed: () async {
                final picked = await _pickBooks(ctx, bookIds, titleOf);
                if (picked == null || !ctx.mounted) return;
                Navigator.pop(
                  ctx,
                  LibrarySetupResult(LibrarySetupChoice.all, picked),
                );
              },
              child: Text(l10n.libraryChoose),
            ),
            TextButton(
              onPressed: () => Navigator.pop(
                ctx,
                const LibrarySetupResult(LibrarySetupChoice.later, {}),
              ),
              child: Text(l10n.libraryLater),
            ),
          ],
        ),
      ),
    ),
  );
}

Future<Set<int>?> showLibraryStorageSheet(
  BuildContext context, {
  required int requiredBytes,
  required List<int> bookIds,
  required String Function(int bookId) titleOf,
  required VoidCallback onManageStorage,
}) {
  final l10n = AppLocalizations.of(context);
  final t = IshamelaTokens.of(context);
  final arabic = Localizations.localeOf(context).languageCode == 'ar';
  final size = libraryByteLabel(requiredBytes, arabic: arabic);
  return showModalBottomSheet<Set<int>>(
    context: context,
    backgroundColor: t.card,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.libraryStorageShort(size)),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () async {
                final picked = await _pickBooks(ctx, bookIds, titleOf);
                if (picked == null || !ctx.mounted) return;
                Navigator.pop(ctx, picked);
              },
              child: Text(l10n.libraryChooseBooks),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                onManageStorage();
              },
              child: Text(l10n.libraryManageStorage),
            ),
          ],
        ),
      ),
    ),
  );
}

Future<Set<int>?> _pickBooks(
  BuildContext context,
  List<int> bookIds,
  String Function(int bookId) titleOf,
) {
  final selected = bookIds.toSet();
  return showDialog<Set<int>>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) {
        final l10n = AppLocalizations.of(ctx);
        return AlertDialog(
          title: Text(l10n.libraryChooseBooks),
          content: SizedBox(
            width: 360,
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final id in bookIds)
                  CheckboxListTile(
                    value: selected.contains(id),
                    title: Text(titleOf(id)),
                    onChanged: (v) => setState(() {
                      if (v == true) {
                        selected.add(id);
                      } else {
                        selected.remove(id);
                      }
                    }),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l10n.cancel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, selected),
              child: Text(l10n.confirm),
            ),
          ],
        );
      },
    ),
  );
}
