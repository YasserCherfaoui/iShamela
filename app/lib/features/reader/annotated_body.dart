import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ishamela/l10n/app_localizations.dart';

import 'package:ishamela/core/db/state_database.dart';
import 'package:ishamela/features/reader/body_display_map.dart';
import 'package:ishamela/features/reader/citation.dart';
import 'package:ishamela/features/reader/role_color.dart';
import 'package:ishamela/features/reader/reader_styles.dart';
import 'package:ishamela/features/reader/text_roles.dart';
import 'package:ishamela/ui/selection_toolbar.dart';
import 'package:ishamela/ui/theme/reader_theme_tokens.dart';

/// Selectable body with SPEC-010/011/012 annotations, roles, note badges.
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
    this.onNotesChanged,
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
  final VoidCallback? onNotesChanged;

  @override
  State<AnnotatedBody> createState() => _AnnotatedBodyState();
}

class _AnnotatedBodyState extends State<AnnotatedBody> {
  List<Map<String, Object?>> _highlights = [];
  List<Map<String, Object?>> _notes = [];
  Map<int, int> _noteIndexById = {};
  late BodyDisplayMap _map;
  late TextRoleMap _roles;

  /// Selectable index → display index; `-1` = note-badge placeholder.
  List<int> _selToDisplay = const [];

  /// Latest body selection (web toolbar + actions).
  TextSelection _selection = const TextSelection.collapsed(offset: 0);
  int? _pointerDownButtons;
  OverlayEntry? _webToolbar;
  Offset? _webToolbarAnchor;

  @override
  void initState() {
    super.initState();
    // Browser menu otherwise replaces Flutter's highlight/note/cite toolbar.
    if (kIsWeb) {
      BrowserContextMenu.disableContextMenu();
    }
    _remapBody();
    _loadAnnotations();
    _notifyNotesChanged();
  }

  @override
  void dispose() {
    _removeWebToolbar();
    if (kIsWeb) {
      BrowserContextMenu.enableContextMenu();
    }
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant AnnotatedBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pageId != widget.pageId ||
        oldWidget.bookId != widget.bookId ||
        oldWidget.body != widget.body) {
      _removeWebToolbar();
      _remapBody();
      _reload();
    }
  }

  void _remapBody() {
    _map = BodyDisplayMap.fromBody(widget.body);
    _roles = classifyTextRoles(widget.body);
  }

  void _loadAnnotations() {
    _highlights =
        widget.state.highlightsForPage(widget.bookId, widget.pageId);
    _notes = widget.state.notesForPage(widget.bookId, widget.pageId);
    final all = widget.state.notesForBook(widget.bookId);
    _noteIndexById = {
      for (var i = 0; i < all.length; i++) all[i]['id'] as int: i + 1,
    };
  }

  void _reload() {
    setState(_loadAnnotations);
    _notifyNotesChanged();
  }

  /// Parent may call setState; never invoke during our own build/init.
  void _notifyNotesChanged() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onNotesChanged?.call();
    });
  }

  TextStyle _baseStyle(ReaderTextStyles styles) => TextStyle(
        fontSize: styles.fontSize,
        height: 1.9,
        fontFamily: styles.font.familyName,
      );

  (int, int)? _selectionToBody(TextSelection sel) {
    if (!sel.isValid || sel.isCollapsed) return null;
    if (_selToDisplay.isEmpty) {
      return _map.toBodyRange(sel.start, sel.end);
    }
    final a = sel.start.clamp(0, _selToDisplay.length);
    final b = sel.end.clamp(0, _selToDisplay.length);
    int? dStart;
    int? dEnd;
    for (var i = a; i < b; i++) {
      final d = _selToDisplay[i];
      if (d < 0) continue;
      dStart ??= d;
      dEnd = d + 1;
    }
    if (dStart == null || dEnd == null || dEnd <= dStart) return null;
    return _map.toBodyRange(dStart, dEnd);
  }

  String? _selectionExcerpt(TextSelection sel) {
    if (!sel.isValid || sel.isCollapsed) return null;
    if (_selToDisplay.isEmpty) {
      return _map.display.substring(sel.start, sel.end);
    }
    final a = sel.start.clamp(0, _selToDisplay.length);
    final b = sel.end.clamp(0, _selToDisplay.length);
    final buf = StringBuffer();
    for (var i = a; i < b; i++) {
      final d = _selToDisplay[i];
      if (d < 0) continue;
      buf.write(_map.display[d]);
    }
    return buf.toString();
  }

  Future<void> _highlight(TextSelection sel, String color) async {
    final range = _selectionToBody(sel);
    if (range == null) return;
    final (start, end) = range;
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

  /// Deletes every highlight that overlaps the selection (SPEC-010).
  void _clearHighlights(TextSelection sel) {
    final range = _selectionToBody(sel);
    if (range == null) return;
    final (start, end) = range;
    if (end <= start) return;
    var removed = false;
    for (final h in List<Map<String, Object?>>.from(_highlights)) {
      final hs = h['start_offset'] as int;
      final he = h['end_offset'] as int;
      if (hs < end && start < he) {
        widget.state.deleteHighlight(h['id'] as int);
        removed = true;
      }
    }
    if (removed) _reload();
  }

  bool _selectionOverlapsHighlight(TextSelection sel) {
    final range = _selectionToBody(sel);
    if (range == null) return false;
    final (start, end) = range;
    for (final h in _highlights) {
      final hs = h['start_offset'] as int;
      final he = h['end_offset'] as int;
      if (hs < end && start < he) return true;
    }
    return false;
  }

  SelectionToolbar _selectionToolbar({
    required TextSelectionToolbarAnchors anchors,
    required TextSelection sel,
    VoidCallback? beforeAction,
  }) {
    final clearable = _selectionOverlapsHighlight(sel);
    return SelectionToolbar(
      anchors: anchors,
      onHighlight: (color) {
        beforeAction?.call();
        ContextMenuController.removeAny();
        _highlight(sel, color);
      },
      onClear: clearable
          ? () {
              beforeAction?.call();
              ContextMenuController.removeAny();
              _clearHighlights(sel);
            }
          : null,
      onNote: () {
        beforeAction?.call();
        ContextMenuController.removeAny();
        _addNote(sel);
      },
      onCite: () {
        beforeAction?.call();
        ContextMenuController.removeAny();
        _copyCitation(sel);
      },
    );
  }

  Future<void> _addNote(TextSelection sel) async {
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
    final range = _selectionToBody(sel);
    if (range == null) return;
    final (start, end) = range;
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
    final excerpt = _selectionExcerpt(sel);
    if (excerpt == null || excerpt.isEmpty) return;
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

  void _removeWebToolbar() {
    _webToolbar?.remove();
    _webToolbar = null;
    _webToolbarAnchor = null;
  }

  void _showWebToolbar(Offset globalPosition, TextSelection sel) {
    if (!kIsWeb || !mounted) return;
    if (!sel.isValid || sel.isCollapsed) {
      _removeWebToolbar();
      return;
    }
    _webToolbarAnchor = globalPosition;
    final entry = OverlayEntry(
      builder: (ctx) {
        final anchor = _webToolbarAnchor ?? globalPosition;
        return _selectionToolbar(
          anchors: TextSelectionToolbarAnchors(primaryAnchor: anchor),
          sel: sel,
          beforeAction: _removeWebToolbar,
        );
      },
    );
    _webToolbar?.remove();
    _webToolbar = entry;
    Overlay.of(context).insert(entry);
  }

  void _onSelectionChanged(TextSelection selection, SelectionChangedCause? cause) {
    _selection = selection;
    if (!selection.isValid || selection.isCollapsed) {
      _removeWebToolbar();
    }
  }

  void _onPointerDown(PointerDownEvent event) {
    _pointerDownButtons = event.buttons;
  }

  void _onPointerUp(PointerUpEvent event) {
    final down = _pointerDownButtons;
    _pointerDownButtons = null;
    // Only after a primary-button select/drag — not right-click (that uses
    // contextMenuBuilder once the browser menu is disabled).
    final wasPrimary = down == kPrimaryButton;
    if (!wasPrimary || !kIsWeb) return;
    final sel = _selection;
    if (!sel.isValid || sel.isCollapsed) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _showWebToolbar(event.position, sel);
    });
  }

  @override
  Widget build(BuildContext context) {
    final styles = widget.textStyles ?? ReaderTextStyles.defaults();
    final fontSize = styles.fontSize;
    final reader = ReaderThemeTokens.of(context);
    final (spans, selMap) = _buildSpansAndMap(styles, reader);
    _selToDisplay = selMap;
    Widget body = SelectableText.rich(
      TextSpan(children: spans),
      textAlign: TextAlign.justify,
      style: TextStyle(
        fontSize: fontSize,
        height: 1.9,
        fontFamily: styles.font.familyName,
        color: reader.body,
      ),
      strutStyle: StrutStyle(
        fontSize: fontSize,
        height: 1.9,
        fontFamily: styles.font.familyName,
        forceStrutHeight: true,
      ),
      onSelectionChanged: _onSelectionChanged,
      contextMenuBuilder: (context, editableTextState) {
        // Prefer the system/Flutter menu path (right-click / long-press).
        _removeWebToolbar();
        final sel = editableTextState.textEditingValue.selection;
        if (!sel.isValid || sel.isCollapsed) {
          return AdaptiveTextSelectionToolbar.buttonItems(
            anchors: editableTextState.contextMenuAnchors,
            buttonItems: editableTextState.contextMenuButtonItems,
          );
        }
        return _selectionToolbar(
          anchors: editableTextState.contextMenuAnchors,
          sel: sel,
        );
      },
    );
    if (kIsWeb) {
      body = Listener(
        onPointerDown: _onPointerDown,
        onPointerUp: _onPointerUp,
        child: body,
      );
    }
    return body;
  }

  Color _roleColor(TextRole role, ReaderTextStyles styles, ReaderThemeTokens theme) {
    return resolveRoleColor(role, styles.styleFor(role), theme);
  }

  (List<InlineSpan>, List<int>) _buildSpansAndMap(
    ReaderTextStyles styles,
    ReaderThemeTokens reader,
  ) {
    final display = _map.display;
    final base = _baseStyle(styles);
    final hl = List<Color?>.filled(display.length, null);
    final noteFlags = List<bool>.filled(display.length, false);
    final badgeAt = <int, int>{};
    final night = reader.atmosphere == ReadingAtmosphere.night;
    final palette = night ? highlightColorsNight : highlightColors;

    for (final h in _highlights) {
      final start = h['start_offset'] as int;
      final end = h['end_offset'] as int;
      final colorId = h['color'] as String;
      final argb = palette[colorId] ?? palette['yellow']!;
      final c = Color(argb);
      final (ds, de) = _map.toDisplayRange(start, end);
      for (var i = ds; i < de && i < display.length; i++) {
        hl[i] = c;
      }
    }
    for (final n in _notes) {
      final id = n['id'] as int;
      final start = n['start_offset'] as int;
      final end = n['end_offset'] as int;
      final (ds, de) = _map.toDisplayRange(start, end);
      final idx = _noteIndexById[id] ?? 0;
      if (ds < display.length && idx > 0) {
        badgeAt[ds] = idx;
      }
      for (var i = ds; i < de && i < display.length; i++) {
        noteFlags[i] = true;
      }
    }

    final out = <InlineSpan>[];
    final selMap = <int>[];
    var i = 0;
    while (i < display.length) {
      if (badgeAt.containsKey(i)) {
        final n = badgeAt[i]!;
        out.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: _NoteBadge(
              index: n,
              gold: true,
              onTap: () {
                Map<String, Object?>? note;
                for (final x in _notes) {
                  if (_noteIndexById[x['id']] == n) {
                    note = x;
                    break;
                  }
                }
                if (note != null) {
                  _editNote(note['id'] as int, note['note'] as String);
                }
              },
            ),
          ),
        );
        selMap.add(-1);
      }
      final role = _roles.roleAt(i);
      final bg = hl[i];
      final note = noteFlags[i];
      var j = i + 1;
      while (j < display.length &&
          !badgeAt.containsKey(j) &&
          _roles.roleAt(j) == role &&
          hl[j] == bg &&
          noteFlags[j] == note) {
        j++;
      }
      final rs = styles.styleFor(role);
      var style = base.copyWith(
        color: _roleColor(role, styles, reader),
        fontWeight: rs.bold ? FontWeight.bold : FontWeight.normal,
      );
      if (bg != null) {
        style = style.copyWith(backgroundColor: bg);
        if (night && reader.highlightUnderline != null) {
          style = style.copyWith(
            decoration: TextDecoration.underline,
            decorationColor: reader.highlightUnderline,
            decorationThickness: 2,
          );
        }
      }
      if (note) {
        style = style.copyWith(
          decoration: TextDecoration.underline,
          decorationStyle: TextDecorationStyle.dashed,
        );
      }
      out.add(TextSpan(text: display.substring(i, j), style: style));
      for (var k = i; k < j; k++) {
        selMap.add(k);
      }
      i = j;
    }
    return (out, selMap);
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
}

class _NoteBadge extends StatelessWidget {
  const _NoteBadge({
    required this.index,
    required this.onTap,
    this.gold = false,
  });

  final int index;
  final VoidCallback onTap;
  final bool gold;

  @override
  Widget build(BuildContext context) {
    final bg =
        gold ? const Color(0xFFA67C2E) : Theme.of(context).colorScheme.primary;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 1),
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          '$index',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            height: 1.2,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
