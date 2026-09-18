import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ishamela/l10n/app_localizations.dart';

import 'package:ishamela/core/format_bytes.dart';
import 'package:ishamela/core/providers.dart';
import 'package:ishamela/core/storage_size.dart';
import 'package:ishamela/features/reader/reader_styles.dart';
import 'package:ishamela/features/reader/role_color.dart';
import 'package:ishamela/features/reader/text_roles.dart';
import 'package:ishamela/features/settings/about_page.dart';
import 'package:ishamela/features/settings/storage_page.dart';
import 'package:ishamela/ui/theme/ishamela_theme.dart';
import 'package:ishamela/ui/theme/ishamela_tokens.dart';
import 'package:ishamela/ui/theme/reader_theme_tokens.dart';

/// SPEC-011 settings + DESIGN-001 theme picker / font card.
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final t = IshamelaTokens.of(context);
    final styles = ref.watch(readerTextStylesProvider);
    final notifier = ref.read(readerTextStylesProvider.notifier);
    final atmosphere = ref.watch(readingAtmosphereProvider);
    final width = MediaQuery.sizeOf(context).width;

    final body = ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                l10n.tabSettings,
                style: TextStyle(
                  fontFamily: kFontAmiri,
                  fontWeight: FontWeight.w700,
                  fontSize: 26,
                  color: t.ink,
                ),
              ),
            ),
            TextButton(
              onPressed: () => notifier.reset(),
              child: Text(
                l10n.resetTextStyles,
                style: const TextStyle(color: Color(0xFFA6402E)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          l10n.readingTheme,
          style: TextStyle(
            fontFamily: kFontUi,
            fontWeight: FontWeight.w700,
            fontSize: 13,
            color: t.green900,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            for (final a in ReadingAtmosphere.values) ...[
              Expanded(
                child: _AtmosphereTile(
                  atmosphere: a,
                  selected: atmosphere == a,
                  label: _atmosphereLabel(l10n, a),
                  onTap: () =>
                      ref.read(readingAtmosphereProvider.notifier).save(a),
                ),
              ),
              if (a != ReadingAtmosphere.night) const SizedBox(width: 8),
            ],
          ],
        ),
        const SizedBox(height: 24),
        Material(
          color: t.card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: t.hairline),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.readerFont,
                  style: TextStyle(
                    fontFamily: kFontUi,
                    fontWeight: FontWeight.w700,
                    color: t.green900,
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<ReaderFont>(
                  value: styles.font,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
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
                const SizedBox(height: 12),
                Text(
                  'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: styles.font.familyName ?? kFontAmiri,
                    fontSize: styles.fontSize,
                    height: 1.9,
                    color: t.ink,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      'ا',
                      style: TextStyle(
                        fontFamily: kFontAmiri,
                        fontSize: 14,
                        color: t.muted,
                      ),
                    ),
                    Expanded(
                      child: Slider(
                        value: styles.fontSize,
                        min: 14,
                        max: 40,
                        divisions: 26,
                        label: styles.fontSize.round().toString(),
                        onChanged: (v) =>
                            notifier.save(styles.withFontSize(v)),
                      ),
                    ),
                    Text(
                      'ا',
                      style: TextStyle(
                        fontFamily: kFontAmiri,
                        fontSize: 22,
                        color: t.muted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          l10n.textAppearance,
          style: TextStyle(
            fontFamily: kFontUi,
            fontWeight: FontWeight.w700,
            fontSize: 13,
            color: t.green900,
          ),
        ),
        const SizedBox(height: 8),
        for (final role in TextRole.values)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _RoleStyleTile(
              style: RoleStyle(
                color: resolveRoleColor(
                  role,
                  styles.styleFor(role),
                  ReaderThemeTokens.of(context),
                ),
                bold: styles.styleFor(role).bold,
              ),
              label: _roleLabel(l10n, role),
              previewFont: styles.font.familyName,
              onChanged: (next) {
                notifier.save(styles.withRole(role, next));
              },
            ),
          ),
        const SizedBox(height: 24),
        _StorageCard(),
        const SizedBox(height: 16),
        _LanguageAndAppCard(),
      ],
    );

    if (width >= 600 && width < 800) {
      return Scaffold(
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: body,
          ),
        ),
      );
    }

    return Scaffold(body: body);
  }

  String _atmosphereLabel(AppLocalizations l10n, ReadingAtmosphere a) {
    switch (a) {
      case ReadingAtmosphere.paper:
        return l10n.atmospherePaper;
      case ReadingAtmosphere.sepia:
        return l10n.atmosphereSepia;
      case ReadingAtmosphere.night:
        return l10n.atmosphereNight;
    }
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

class _AtmosphereTile extends StatelessWidget {
  const _AtmosphereTile({
    required this.atmosphere,
    required this.selected,
    required this.label,
    required this.onTap,
  });

  final ReadingAtmosphere atmosphere;
  final bool selected;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = ReaderThemeTokens.forAtmosphere(atmosphere);
    final t = IshamelaTokens.of(context);
    return Material(
      color: tokens.ground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: selected ? t.green700 : t.hairline,
          width: selected ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            children: [
              Text(
                'أبجد',
                style: TextStyle(
                  fontFamily: kFontAmiri,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: tokens.titles,
                ),
              ),
              Text(
                'نص',
                style: TextStyle(
                  fontFamily: kFontAmiri,
                  fontSize: 12,
                  color: tokens.body,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  fontFamily: kFontUi,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: tokens.muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
    Color(0xFF8F6A1F),
    Color(0xFF888888),
    Color(0xFFB71C1C),
    Color(0xFF0D47A1),
    Color(0xFF4E342E),
    Color(0xFF00695C),
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final t = IshamelaTokens.of(context);
    return Material(
      color: t.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: t.hairline),
      ),
      child: ListTile(
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
                  border: Border.all(color: t.hairline),
                ),
              ),
            ),
          ],
        ),
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
                            color: Theme.of(ctx).dividerColor,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: hexCtrl,
                decoration: InputDecoration(labelText: l10n.colorHex),
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
              final raw = hexCtrl.text.trim().replaceFirst('#', '');
              if (raw.length == 6) {
                final v = int.tryParse(raw, radix: 16);
                if (v != null) {
                  Navigator.pop(ctx, Color(0xFF000000 | v));
                  return;
                }
              }
              Navigator.pop(ctx);
            },
            child: Text(l10n.confirm),
          ),
        ],
      ),
    );
    hexCtrl.dispose();
    if (picked != null) onChanged(style.copyWith(color: picked));
  }
}

class _StorageCard extends ConsumerStatefulWidget {
  @override
  ConsumerState<_StorageCard> createState() => _StorageCardState();
}

class _StorageCardState extends ConsumerState<_StorageCard> {
  int? _free;
  int _tick = 0;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final paths = await ref.read(appPathsProvider.future);
    final state = await ref.read(stateDatabaseProvider.future);
    await backfillInstalledSizes(paths, state);
    final free = await deviceFreeBytes(paths);
    if (!mounted) return;
    setState(() {
      _free = free;
      _tick++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final t = IshamelaTokens.of(context);
    ref.watch(downloadServiceProvider);
    final stateAsync = ref.watch(stateDatabaseProvider);
    final _ = _tick;

    return Material(
      color: t.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: t.hairline),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.storage,
              style: TextStyle(
                fontFamily: kFontUi,
                fontWeight: FontWeight.w700,
                color: t.green900,
              ),
            ),
            const SizedBox(height: 8),
            stateAsync.when(
              loading: () => Text('…', style: TextStyle(color: t.muted)),
              error: (e, _) => Text('$e'),
              data: (state) {
                final used = state.installedSizeBytesTotal;
                final n = state.installedBooksBySizeDesc().length;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      l10n.storageUsed(formatBytes(used), n),
                      style: TextStyle(
                        fontFamily: kFontUi,
                        fontSize: 13,
                        color: t.ink,
                      ),
                    ),
                    if (_free != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        l10n.storageAvailable(formatBytes(_free!)),
                        style: TextStyle(
                          fontFamily: kFontUi,
                          fontSize: 13,
                          color: t.muted,
                        ),
                      ),
                    ],
                    if (state.hasUnknownInstalledSizes)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          l10n.calculatingSizes,
                          style: TextStyle(
                            fontFamily: kFontUi,
                            fontSize: 11,
                            color: t.muted,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: 12),
            FilledButton.tonal(
              onPressed: () async {
                await StoragePage.open(context);
                if (mounted) await _refresh();
              },
              style: FilledButton.styleFrom(
                backgroundColor: t.green100,
                foregroundColor: t.green900,
              ),
              child: Text(l10n.manageStorage),
            ),
          ],
        ),
      ),
    );
  }
}

class _LanguageAndAppCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final t = IshamelaTokens.of(context);
    final locale = ref.watch(appLocaleProvider);
    final label = switch (locale.languageCode) {
      'en' => 'English',
      'fr' => 'Français',
      _ => 'العربية',
    };

    return Material(
      color: t.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: t.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              l10n.languageAndApp,
              style: TextStyle(
                fontFamily: kFontUi,
                fontWeight: FontWeight.w700,
                color: t.green900,
              ),
            ),
          ),
          ListTile(
            title: Text(l10n.appLanguage),
            subtitle: Text(label),
            trailing: const Icon(Icons.chevron_left),
            onTap: () => _pickLocale(context, ref),
          ),
          const Divider(height: 1),
          ListTile(
            title: Text(l10n.aboutApp),
            trailing: const Icon(Icons.chevron_left),
            onTap: () => AboutPage.open(context),
          ),
        ],
      ),
    );
  }

  Future<void> _pickLocale(BuildContext context, WidgetRef ref) async {
    final t = IshamelaTokens.of(context);
    final current = ref.read(appLocaleProvider);
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: t.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final opt in const [
                ('ar', 'العربية'),
                ('en', 'English'),
                ('fr', 'Français'),
              ])
                RadioListTile<String>(
                  title: Text(opt.$2),
                  value: opt.$1,
                  groupValue: current.languageCode,
                  onChanged: (v) => Navigator.pop(ctx, v),
                ),
            ],
          ),
        );
      },
    );
    if (picked != null) {
      await ref.read(appLocaleProvider.notifier).save(Locale(picked));
    }
  }
}
