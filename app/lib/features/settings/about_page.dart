import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ishamela/l10n/app_localizations.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:ishamela/ui/rosette_divider.dart';
import 'package:ishamela/ui/theme/ishamela_theme.dart';
import 'package:ishamela/ui/theme/ishamela_tokens.dart';

/// SPEC-016 About screen.
class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  static const _hfUrl =
      'https://huggingface.co/datasets/AuthenticIlm/Shamela4_Full_DB';
  static const _repoUrl = 'https://github.com/yassercherfaoui/iShamela';

  static Future<void> open(BuildContext context) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const AboutPage()),
    );
  }

  Future<void> _openUrl(BuildContext context, String url) async {
    final l10n = AppLocalizations.of(context);
    final uri = Uri.parse(url);
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.noConnection)),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.noConnection)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final t = IshamelaTokens.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          l10n.aboutApp,
          style: TextStyle(
            fontFamily: kFontAmiri,
            fontWeight: FontWeight.w700,
            fontSize: 22,
            color: t.ink,
          ),
        ),
      ),
      body: FutureBuilder<PackageInfo>(
        future: PackageInfo.fromPlatform(),
        builder: (context, snap) {
          final info = snap.data;
          final versionLine = info == null
              ? '…'
              : l10n.version(info.version, info.buildNumber);
          return ListView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
            children: [
              const Center(child: RosetteMark(size: 48)),
              const SizedBox(height: 16),
              Text(
                l10n.brandName,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: kFontAmiri,
                  fontWeight: FontWeight.w700,
                  fontSize: 28,
                  color: t.green900,
                ),
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onLongPress: info == null
                    ? null
                    : () async {
                        await Clipboard.setData(
                          ClipboardData(
                            text: '${info.version}+${info.buildNumber}',
                          ),
                        );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(l10n.buildCopied)),
                          );
                        }
                      },
                child: Text(
                  versionLine,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: kFontUi,
                    fontSize: 13,
                    color: t.muted,
                  ),
                ),
              ),
              const SizedBox(height: 28),
              Text(
                l10n.datasetAttributionTitle,
                style: TextStyle(
                  fontFamily: kFontUi,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: t.green900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.datasetAttributionBody,
                style: TextStyle(
                  fontFamily: kFontUi,
                  fontSize: 13,
                  height: 1.45,
                  color: t.ink,
                ),
              ),
              TextButton(
                onPressed: () => _openUrl(context, _hfUrl),
                child: const Text(
                  'Hugging Face',
                  textAlign: TextAlign.start,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.sourceCode),
                trailing: const Icon(Icons.open_in_new, size: 18),
                onTap: () => _openUrl(context, _repoUrl),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.licenses),
                trailing: const Icon(Icons.chevron_left),
                onTap: () {
                  showLicensePage(
                    context: context,
                    applicationName: l10n.brandName,
                    applicationVersion: info?.version,
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}
