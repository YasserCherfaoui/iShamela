import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ishamela/l10n/app_localizations.dart';

import 'package:ishamela/core/author_death.dart';
import 'package:ishamela/core/models/models.dart';
import 'package:ishamela/core/providers.dart';
import 'package:ishamela/features/catalog/catalog_page.dart';
import 'package:ishamela/ui/meta_chip.dart';
import 'package:ishamela/ui/segmented_pills.dart';
import 'package:ishamela/ui/theme/ishamela_theme.dart';
import 'package:ishamela/ui/theme/ishamela_tokens.dart';

/// SPEC-018 author destination page.
class AuthorPage extends ConsumerStatefulWidget {
  const AuthorPage({
    super.key,
    required this.authorId,
    this.initialAuthor,
  });

  final int authorId;
  final Author? initialAuthor;

  static Future<void> open(
    BuildContext context, {
    required int authorId,
    Author? author,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AuthorPage(
          authorId: authorId,
          initialAuthor: author,
        ),
      ),
    );
  }

  @override
  ConsumerState<AuthorPage> createState() => _AuthorPageState();
}

class _AuthorPageState extends ConsumerState<AuthorPage> {
  int _segment = 0; // 0 all, 1 installed
  bool _bioExpanded = false;
  String? _bio;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final t = IshamelaTokens.of(context);
    final catalogAsync = ref.watch(catalogRepositoryProvider);
    final stateAsync = ref.watch(stateDatabaseProvider);
    ref.watch(downloadRevisionProvider);
    ref.watch(downloadServiceProvider);

    return catalogAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(body: Center(child: Text('$e'))),
      data: (catalog) {
        final author = catalog.authorById(widget.authorId) ??
            widget.initialAuthor ??
            Author(id: widget.authorId, name: 'author_${widget.authorId}');
        final books = catalog.booksByAuthor(widget.authorId);
        final installedIds = stateAsync.maybeWhen(
          data: (s) => s.installedBookIds().toSet(),
          orElse: () => <int>{},
        );
        final installedCount =
            books.where((b) => installedIds.contains(b.bookId)).length;
        final death = formatAuthorDeath(l10n, author.deathYearHijri);
        final visible = _segment == 0
            ? books
            : books.where((b) => installedIds.contains(b.bookId)).toList();

        // Forward-compatible bio: try optional column via repository helper.
        _bio ??= catalog.authorBio(widget.authorId);

        return Scaffold(
          appBar: AppBar(
            title: Text(
              author.name,
              style: TextStyle(
                fontFamily: kFontAmiri,
                fontWeight: FontWeight.w700,
                fontSize: 20,
                color: t.ink,
              ),
            ),
          ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: t.green100,
                      child: Icon(Icons.person, color: t.emphasis),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            author.name,
                            style: TextStyle(
                              fontFamily: kFontAmiri,
                              fontWeight: FontWeight.w700,
                              fontSize: 22,
                              color: t.ink,
                            ),
                          ),
                          if (death != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              death,
                              style: TextStyle(
                                fontFamily: kFontUi,
                                fontSize: 13,
                                color: t.muted,
                              ),
                            ),
                          ],
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              MetaChip(
                                label: l10n.authorBooksCount(books.length),
                              ),
                              if (installedCount > 0)
                                MetaChip(
                                  label: l10n.authorInstalledCount(
                                    installedCount,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (_bio != null && _bio!.trim().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        _bio!,
                        maxLines: _bioExpanded ? null : 4,
                        overflow: _bioExpanded
                            ? TextOverflow.visible
                            : TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: kFontAmiri,
                          fontSize: 13.5,
                          height: 1.45,
                          color: t.muted,
                        ),
                      ),
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: TextButton(
                          onPressed: () =>
                              setState(() => _bioExpanded = !_bioExpanded),
                          child: Text(
                            _bioExpanded ? l10n.showLess : l10n.showMore,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: SegmentedPills(
                  labels: [l10n.allBooks, l10n.installedOnly],
                  selectedIndex: _segment,
                  onChanged: (i) => setState(() => _segment = i),
                ),
              ),
              Expanded(
                child: _segment == 1 && visible.isEmpty
                    ? Center(
                        child: Text(
                          l10n.noInstalledForAuthor,
                          style: TextStyle(
                            fontFamily: kFontUi,
                            color: t.muted,
                          ),
                        ),
                      )
                    : BookListPage(
                        title: author.name,
                        books: visible,
                        allowDownloadAll: true,
                        embedded: true,
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
