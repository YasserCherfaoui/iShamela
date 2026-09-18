import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ishamela/l10n/app_localizations.dart';

import 'package:ishamela/core/db/state_database.dart';
import 'package:ishamela/features/reader/body_display_map.dart';
import 'package:ishamela/features/reader/citation.dart';
import 'package:ishamela/features/reader/reader_styles.dart';
import 'package:ishamela/features/reader/text_roles.dart';

/// Selectable body with SPEC-010 highlights / notes / copy-citation
/// and SPEC-011 role coloring.
class AnnotatedBody extends StatefulWidget {
  const AnnotatedBody({
    super.key,
    required this.body,
    required this.bookId,
    required this.pageId,
    required this.state,
    required this.title,
    required this.author,
    this.part,
    this.pageNumber,
    this.textStyles,
  });

  final String body;
  final int bookId;
  final int pageId;
  final StateDatabase state;
  final String title;
  final String author;
  final String? part;
  final int? pageNumber;
  final ReaderTextStyles? textStyles;

  @override
  State<AnnotatedBody> createState() => _AnnotatedBodyState();
}

class _AnnotatedBodyState extends State<AnnotatedBody> {
  List<Map<String, Object?>> _highlights = [];
  List<Map<String, Object?>> _notes = [];
  late BodyDisplayMap _map;
  late TextRoleMap _roles;

  @override
  void initState() {
    super.initState();
    _remapBody();
    _reload();
  }

  @override
  void didUpdateWidget(covariant AnnotatedBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pageId != widget.pageId ||
        oldWidget.bookId != widget.bookId ||
        oldWidget.body != widget.body) {
      _remapBody();
      _reload();
    }
  }

  void _remapBody() {
    _map = BodyDisplayMap.fromBody(widget.body);
    _roles = classifyTextRoles(widget.body);
  }

  void _reload() {
    setState(() {
      _highlights =
          widget.state.highlightsForPage(widget.bookId, widget.pageId);
      _notes = widget.state.notesForPage(widget.bookId, widget.pageId);
    });
  }

  TextStyle _baseStyle(ReaderTextStyles styles) => TextStyle(
        fontSize: styles.fontSize,
        height: 1.8,
        fontFamily: styles.font.familyName,
      );

  List<InlineSpan> _buildSpans() {
    final display = _map.display;
    final styles = widget.textStyles ?? ReaderTextStyles.defaults();
    final base = _baseStyle(styles);
    final hl = List<Color?>.filled(display.length, null);
    final noteFlags = List<bool>.filled(display.length, false);

    for (final h in _highlights) {
      final start = h['start_offset'] as int;
      final end = h['end_offset'] as int;
      final colorId = h['color'] as String;
      final argb = highlightColors[colorId] ?? highlightColors['yellow']!;
      final c = Color(argb);
      final (ds, de) = _map.toDisplayRange(start, end);
      for (var i = ds; i < de && i < display.length; i++) {
        hl[i] = c;
      }
    }
    for (final n in _notes) {
      final start = n['start_offset'] as int;
      final end = n['end_offset'] as int;
      final (ds, de) = _map.toDisplayRange(start, end);
      for (var i = ds; i < de && i < display.length; i++) {
        noteFlags[i] = true;
      }
    }

    final out = <InlineSpan>[];
    var i = 0;
    while (i < display.length) {
      final role = _roles.roleAt(i);
      final bg = hl[i];
      final note = noteFlags[i];
      var j = i + 1;
      while (j < display.length &&
          _roles.roleAt(j) == role &&
          hl[j] == bg &&
          noteFlags[j] == note) {
        j++;
      }
      final rs = styles.styleFor(role);
      var style = base.copyWith(
        color: rs.color,
        fontWeight: rs.bold ? FontWeight.bold : FontWeight.normal,
      );
      if (bg != null) {
        style = style.copyWith(backgroundColor: bg);
      }
      if (note) {
        style = style.copyWith(
          decoration: TextDecoration.underline,
          decorationStyle: TextDecorationStyle.dashed,
          decorationColor: Theme.of(context).colorScheme.primary,
        );
      }
      out.add(TextSpan(text: display.substring(i, j), style: style));
      i = j;
    }
    if (out.isEmpty) {
      out.add(TextSpan(text: display, style: base));
    }
    return out;
  }

  Future<void> _highlight(TextSelection sel, String color) async {
    if (!sel.isValid || sel.isCollapsed) return;
    final (start, end) = _map.toBodyRange(sel.start, sel.end);
    if (end <= start) return;
    widget.state.insertHighlight(
      bookId: widget.bookId,
      pageId: widget.pageId,
      start: start,
      end: end,
      color: color,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );
    _reload();
  }

  Future<void> _addNote(TextSelection sel) async {
    if (!sel.isValid || sel.isCollapsed) return;
    final l10n = AppLocalizations.of(context);
    final ctrl = TextEditingController();
    final note = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.addNote),
        content: TextField(
          controller: ctrl,
          maxLines: 4,
          autofocus: true,
          decoration: InputDecoration(hintText: l10n.addNote),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: Text(l10n.confirm),
          ),
        ],
      ),
    );
    if (note == null || note.isEmpty) return;
    final (start, end) = _map.toBodyRange(sel.start, sel.end);
    if (end <= start) return;
    widget.state.insertNote(
      bookId: widget.bookId,
      pageId: widget.pageId,
      start: start,
      end: end,
      note: note,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );
    _reload();
  }

  Future<void> _copyCitation(TextSelection sel) async {
    if (!sel.isValid || sel.isCollapsed) return;
    final excerpt = _map.display.substring(sel.start, sel.end);
    final arabic = Localizations.localeOf(context).languageCode == 'ar';
    final text = formatCitation(
      excerpt: excerpt,
      title: widget.title,
      author: widget.author,
      part: widget.part,
      pageNumber: widget.pageNumber,
      arabic: arabic,
    );
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context).copiedCitation)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final styles = widget.textStyles ?? ReaderTextStyles.defaults();
    final fontSize = styles.fontSize;
    return SelectableText.rich(
      TextSpan(children: _buildSpans()),
      textAlign: TextAlign.justify,
      style: TextStyle(
        fontSize: fontSize,
        height: 1.8,
        fontFamily: styles.font.familyName,
      ),
      strutStyle: StrutStyle(
        fontSize: fontSize,
        height: 1.8,
        fontFamily: styles.font.familyName,
        forceStrutHeight: true,
      ),
      contextMenuBuilder: (context, editableTextState) {
        final sel = editableTextState.textEditingValue.selection;
        final items = <ContextMenuButtonItem>[
          ...editableTextState.contextMenuButtonItems,
        ];
        if (sel.isValid && !sel.isCollapsed) {
          for (final e in highlightColors.entries) {
            items.add(
              ContextMenuButtonItem(
                label: '${l10n.highlight}: ${_colorLabel(l10n, e.key)}',
                onPressed: () {
                  ContextMenuController.removeAny();
                  _highlight(sel, e.key);
                },
              ),
            );
          }
          items.add(
            ContextMenuButtonItem(
              label: l10n.addNote,
              onPressed: () {
                ContextMenuController.removeAny();
                _addNote(sel);
              },
            ),
          );
          items.add(
            ContextMenuButtonItem(
              label: l10n.copyWithReference,
              onPressed: () {
                ContextMenuController.removeAny();
                _copyCitation(sel);
              },
            ),
          );
        }
        for (final n in _notes) {
          final id = n['id'] as int;
          final preview = n['note'] as String;
          items.add(
            ContextMenuButtonItem(
              label:
                  '${l10n.addNote}: ${preview.length > 24 ? '${preview.substring(0, 24)}…' : preview}',
              onPressed: () {
                ContextMenuController.removeAny();
                _editNote(id, preview);
              },
            ),
          );
        }
        return AdaptiveTextSelectionToolbar.buttonItems(
          anchors: editableTextState.contextMenuAnchors,
          buttonItems: items,
        );
      },
    );
  }

  Future<void> _editNote(int id, String current) async {
    final l10n = AppLocalizations.of(context);
    final ctrl = TextEditingController(text: current);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.addNote),
        content: TextField(controller: ctrl, maxLines: 4, autofocus: true),
        actions: [
          TextButton(
            onPressed: () {
              widget.state.deleteNote(id);
              Navigator.pop(ctx, '');
            },
            child: Text(l10n.delete),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: Text(l10n.confirm),
          ),
        ],
      ),
    );
    if (result == null) return;
    if (result.isEmpty) {
      widget.state.deleteNote(id);
    } else {
      widget.state.updateNote(id, result);
    }
    _reload();
  }

  String _colorLabel(AppLocalizations l10n, String id) {
    switch (id) {
      case 'green':
        return l10n.colorGreen;
      case 'blue':
        return l10n.colorBlue;
      case 'pink':
        return l10n.colorPink;
      case 'orange':
        return l10n.colorOrange;
      default:
        return l10n.colorYellow;
    }
  }
}
