import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ishamela/l10n/app_localizations.dart';

import 'package:ishamela/core/providers.dart';
import 'package:ishamela/features/reader/reader_styles.dart';
import 'package:ishamela/ui/glass/chrome/glass_sheet.dart';
import 'package:ishamela/ui/segmented_pills.dart';
import 'package:ishamela/ui/theme/atmosphere_label.dart';
import 'package:ishamela/ui/theme/ishamela_theme.dart';
import 'package:ishamela/ui/theme/ishamela_tokens.dart';
import 'package:ishamela/ui/theme/reader_theme_tokens.dart';

/// In-reader typography and atmosphere quick-settings sheet.
Future<void> showReaderAppearanceSheet(BuildContext context) {
  final t = IshamelaTokens.of(context);
  return showGlassSheet<void>(
    context: context,
    showDragHandle: true,
    backgroundColor: t.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => const _ReaderAppearanceBody(),
  );
}

class _ReaderAppearanceBody extends ConsumerWidget {
  const _ReaderAppearanceBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final t = IshamelaTokens.of(context);
    final styles = ref.watch(readerTextStylesProvider);
    final stylesNotifier = ref.read(readerTextStylesProvider.notifier);
    final atmosphere = ref.watch(readingAtmosphereProvider);
    final fontOptions = const [
      ReaderFont.system,
      ReaderFont.amiri,
      ReaderFont.scheherazade,
    ];
    final fontLabels = [
      l10n.fontSystem,
      l10n.fontAmiri,
      l10n.fontScheherazade,
    ];
    final fontIndex = fontOptions.indexOf(styles.font).clamp(0, 2);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.textAppearance,
                      style: TextStyle(
                        fontFamily: kFontAmiri,
                        fontWeight: FontWeight.w700,
                        fontSize: 20,
                        color: t.ink,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => stylesNotifier.reset(),
                    child: Text(l10n.resetTextStyles),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                l10n.readingTheme,
                style: TextStyle(
                  fontFamily: kFontUi,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: t.emphasis,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final atm in ReadingAtmosphere.pickerOrder)
                    ChoiceChip(
                      label: Text(atmosphereLabel(l10n, atm)),
                      selected: atm == atmosphere,
                      onSelected: (_) => ref
                          .read(readingAtmosphereProvider.notifier)
                          .save(atm),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                l10n.readerFont,
                style: TextStyle(
                  fontFamily: kFontUi,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: t.emphasis,
                ),
              ),
              const SizedBox(height: 8),
              SegmentedPills(
                fitLabels: true,
                labels: fontLabels,
                selectedIndex: fontIndex,
                onChanged: (i) =>
                    stylesNotifier.save(styles.withFont(fontOptions[i])),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Text(
                    l10n.fontSize,
                    style: TextStyle(
                      fontFamily: kFontUi,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: t.emphasis,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${styles.fontSize.round()}',
                    style: TextStyle(
                      fontFamily: kFontUi,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: t.muted,
                    ),
                  ),
                ],
              ),
              Slider(
                value: styles.fontSize,
                min: 14,
                max: 40,
                divisions: 26,
                onChanged: (v) =>
                    stylesNotifier.save(styles.withFontSize(v.roundToDouble())),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
