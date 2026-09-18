import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ishamela/l10n/app_localizations.dart';

import 'package:ishamela/core/providers.dart';
import 'package:ishamela/features/reader/reader_styles.dart';
import 'package:ishamela/features/reader/text_roles.dart';

/// SPEC-011 settings: per-role reader text colors / weight / font.
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final styles = ref.watch(readerTextStylesProvider);
    final notifier = ref.read(readerTextStylesProvider.notifier);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.tabSettings),
          actions: [
            TextButton(
              onPressed: () => notifier.reset(),
              child: Text(l10n.resetTextStyles),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text(
                l10n.readerFont,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: DropdownButtonFormField<ReaderFont>(
                value: styles.font,
                decoration: const InputDecoration(border: OutlineInputBorder()),
                items: [
                  DropdownMenuItem(
                    value: ReaderFont.amiri,
                    child: Text(l10n.fontAmiri),
                  ),
                  DropdownMenuItem(
                    value: ReaderFont.scheherazade,
                    child: Text(l10n.fontScheherazade),
                  ),
                  DropdownMenuItem(
                    value: ReaderFont.system,
                    child: Text(l10n.fontSystem),
                  ),
                ],
                onChanged: (f) {
                  if (f != null) notifier.save(styles.withFont(f));
                },
              ),
            ),
            ListTile(
              title: Text(l10n.fontSize),
              subtitle: Slider(
                value: styles.fontSize,
                min: 14,
                max: 40,
                divisions: 26,
                label: styles.fontSize.round().toString(),
                onChanged: (v) => notifier.save(styles.withFontSize(v)),
              ),
            ),
            const Divider(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text(
                l10n.textAppearance,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            for (final role in TextRole.values)
              _RoleStyleTile(
                style: styles.styleFor(role),
                label: _roleLabel(l10n, role),
                previewFont: styles.font.familyName,
                onChanged: (next) {
                  notifier.save(styles.withRole(role, next));
                },
              ),
          ],
        ),
      ),
    );
  }

  String _roleLabel(AppLocalizations l10n, TextRole role) {
    switch (role) {
      case TextRole.body:
        return l10n.roleBody;
      case TextRole.title:
        return l10n.roleTitle;
      case TextRole.honorific:
        return l10n.roleHonorific;
      case TextRole.quran:
        return l10n.roleQuran;
      case TextRole.punctuation:
        return l10n.rolePunctuation;
    }
  }
}

class _RoleStyleTile extends StatelessWidget {
  const _RoleStyleTile({
    required this.style,
    required this.label,
    required this.onChanged,
    this.previewFont,
  });

  final RoleStyle style;
  final String label;
  final ValueChanged<RoleStyle> onChanged;
  final String? previewFont;

  static const _presets = <Color>[
    Color(0xFF1A1A1A),
    Color(0xFF0D5C3D),
    Color(0xFF1B7A4E),
    Color(0xFF2E6B9E),
    Color(0xFF6B4C9A),
    Color(0xFF8B5A2B),
    Color(0xFFB8860B),
    Color(0xFF888888),
    Color(0xFFB71C1C),
    Color(0xFF0D47A1),
    Color(0xFF4E342E),
    Color(0xFF00695C),
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListTile(
      title: Text(label),
      subtitle: Text(
        label,
        style: TextStyle(
          color: style.color,
          fontWeight: style.bold ? FontWeight.bold : FontWeight.normal,
          fontSize: 16,
          fontFamily: previewFont,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FilterChip(
            label: Text(l10n.bold),
            selected: style.bold,
            onSelected: (v) => onChanged(style.copyWith(bold: v)),
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: () => _pickColor(context),
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: style.color,
                shape: BoxShape.circle,
                border: Border.all(color: Theme.of(context).dividerColor),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickColor(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final hexCtrl = TextEditingController(
      text:
          '#${style.color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}',
    );
    final picked = await showDialog<Color>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.pickColor),
        content: SizedBox(
          width: 320,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final c in _presets)
                    InkWell(
                      onTap: () => Navigator.pop(ctx, c),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: c,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: c == style.color
                                ? Theme.of(ctx).colorScheme.primary
                                : Colors.transparent,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: hexCtrl,
                decoration: InputDecoration(
                  labelText: l10n.colorHex,
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () {
              final parsed = _parseHex(hexCtrl.text);
              if (parsed != null) Navigator.pop(ctx, parsed);
            },
            child: Text(l10n.confirm),
          ),
        ],
      ),
    );
    if (picked != null) onChanged(style.copyWith(color: picked));
  }

  static Color? _parseHex(String s) {
    var h = s.trim();
    if (h.startsWith('#')) h = h.substring(1);
    if (h.length == 6) h = 'FF$h';
    if (h.length != 8) return null;
    final v = int.tryParse(h, radix: 16);
    if (v == null) return null;
    return Color(v);
  }
}
