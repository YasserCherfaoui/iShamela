import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ishamela/l10n/app_localizations.dart';

import 'package:ishamela/core/providers.dart';
import 'package:ishamela/features/reader/book_database.dart';

/// Minimal SPEC-005 reader: open installed book, page through verbatim body.
class ReaderPage extends ConsumerStatefulWidget {
  const ReaderPage({
    super.key,
    required this.bookId,
    this.title,
    this.authorName,
  });

  final int bookId;
  final String? title;
  final String? authorName;

  static Future<void> open(
    BuildContext context, {
    required int bookId,
    String? title,
    String? authorName,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ReaderPage(
          bookId: bookId,
          title: title,
          authorName: authorName,
        ),
      ),
    );
  }

  @override
  ConsumerState<ReaderPage> createState() => _ReaderPageState();
}

class _ReaderPageState extends ConsumerState<ReaderPage> {
  BookDatabase? _db;
  List<int> _ids = const [];
  int _index = 0;
  PageController? _controller;
  final _jumpCtrl = TextEditingController();
  Object? _error;

  @override
  void initState() {
    super.initState();
    _open();
  }

  Future<void> _open() async {
    try {
      final paths = await ref.read(appPathsProvider.future);
      final state = await ref.read(stateDatabaseProvider.future);
      final db = BookDatabase.open(paths, widget.bookId);
      final ids = db.pageIds();
      if (ids.isEmpty) {
        db.close();
        setState(() => _error = 'empty book');
        return;
      }
      final saved = state.readingPageId(widget.bookId);
      var index = 0;
      if (saved != null) {
        final i = ids.indexOf(saved);
        if (i >= 0) index = i;
      }
      setState(() {
        _db = db;
        _ids = ids;
        _index = index;
        _controller = PageController(initialPage: index);
      });
    } catch (e) {
      setState(() => _error = e);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    _jumpCtrl.dispose();
    _db?.close();
    super.dispose();
  }

  Future<void> _persist(int pageId) async {
    final state = await ref.read(stateDatabaseProvider.future);
    state.upsertReadingState(
      bookId: widget.bookId,
      pageId: pageId,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );
  }

  void _onPage(int i) {
    setState(() => _index = i);
    _persist(_ids[i]);
  }

  void _jumpToPrintPage() {
    final raw = _jumpCtrl.text.trim();
    final n = int.tryParse(raw);
    if (n == null || _db == null) return;
    final page = _db!.pageByPrintNumber(n);
    if (page == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).pageNotFound)),
      );
      return;
    }
    final i = _ids.indexOf(page.id);
    if (i < 0) return;
    _controller?.jumpToPage(i);
    _onPage(i);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final title = widget.title ?? _db?.meta('title') ?? 'book_${widget.bookId}';

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
          actions: [
            if (_ids.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Center(
                  child: Text(
                    l10n.readerProgress(_index + 1, _ids.length),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ),
          ],
        ),
        body: _error != null
            ? Center(child: Text('$_error'))
            : _db == null || _controller == null
                ? const Center(child: CircularProgressIndicator())
                : Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _jumpCtrl,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  hintText: l10n.jumpToPrintPage,
                                  isDense: true,
                                  border: const OutlineInputBorder(),
                                ),
                                onSubmitted: (_) => _jumpToPrintPage(),
                              ),
                            ),
                            const SizedBox(width: 8),
                            FilledButton(
                              onPressed: _jumpToPrintPage,
                              child: Text(l10n.go),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: PageView.builder(
                          controller: _controller,
                          // RTL: page 0 on the right; swipe left for next.
                          reverse: true,
                          itemCount: _ids.length,
                          onPageChanged: _onPage,
                          itemBuilder: (context, i) {
                            final page = _db!.pageById(_ids[i])!;
                            final printNo = page.pageNumber?.toString() ?? '—';
                            final part = page.part;
                            final header = [
                              title,
                              if (part != null && part.isNotEmpty) part,
                              printNo,
                            ].join(' · ');
                            return Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(
                                    header,
                                    style: Theme.of(context).textTheme.labelLarge,
                                    textAlign: TextAlign.center,
                                  ),
                                  const Divider(),
                                  Expanded(
                                    child: SingleChildScrollView(
                                      child: SelectableText(
                                        page.body,
                                        textAlign: TextAlign.justify,
                                        style: const TextStyle(
                                          fontSize: 20,
                                          height: 1.8,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }
}
