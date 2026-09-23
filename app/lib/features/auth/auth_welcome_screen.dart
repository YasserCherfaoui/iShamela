import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ishamela/l10n/app_localizations.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:ishamela/core/auth/auth_controller.dart';
import 'package:ishamela/core/providers.dart';
import 'package:ishamela/features/auth/auth_l10n.dart';
import 'package:ishamela/features/auth/auth_widgets.dart';
import 'package:ishamela/features/auth/sign_in_screen.dart';
import 'package:ishamela/ui/rosette_divider.dart';
import 'package:ishamela/ui/theme/ishamela_theme.dart';
import 'package:ishamela/ui/theme/ishamela_tokens.dart';
import 'package:ishamela/ui/theme/reader_theme_tokens.dart';

/// SPEC-022 §3.1 — `/auth` welcome entry.
class AuthWelcomeScreen extends ConsumerStatefulWidget {
  const AuthWelcomeScreen({super.key});

  static const privacyUrl = 'https://ishamela.online/privacy';
  static const termsUrl = 'https://ishamela.online/terms';

  static Future<void> open(BuildContext context) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const AuthWelcomeScreen()),
    );
  }

  @override
  ConsumerState<AuthWelcomeScreen> createState() => _AuthWelcomeScreenState();
}

class _AuthWelcomeScreenState extends ConsumerState<AuthWelcomeScreen> {
  bool _busyApple = false;
  bool _busyGoogle = false;

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  Future<void> _signInApple() async {
    final l10n = AppLocalizations.of(context);
    setState(() => _busyApple = true);
    try {
      await ref.read(authProvider.notifier).signInApple();
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    } catch (e) {
      if (mounted) showAuthSnack(context, localizeAuthError(l10n, e));
    } finally {
      if (mounted) setState(() => _busyApple = false);
    }
  }

  Future<void> _signInGoogle() async {
    final l10n = AppLocalizations.of(context);
    setState(() => _busyGoogle = true);
    try {
      await ref.read(authProvider.notifier).signInGoogle();
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    } catch (e) {
      if (mounted) showAuthSnack(context, localizeAuthError(l10n, e));
    } finally {
      if (mounted) setState(() => _busyGoogle = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final t = IshamelaTokens.of(context);
    final night =
        ReaderThemeTokens.of(context).atmosphere == ReadingAtmosphere.night;
    final busy = _busyApple || _busyGoogle;

    return Scaffold(
      backgroundColor: t.paper,
      appBar: AppBar(
        backgroundColor: t.paper,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const RosetteMark(size: 40),
              const SizedBox(height: 16),
              Text(
                l10n.appTitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: kFontAmiri,
                  fontWeight: FontWeight.w700,
                  fontSize: 28,
                  color: t.ink,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                l10n.authValueCopy,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: kFontUi,
                  fontSize: 14,
                  color: t.muted,
                  height: 1.45,
                ),
              ),
              const Spacer(),
              if (supportsAppleSignIn) ...[
                AuthSecondaryButton(
                  label: l10n.authContinueApple,
                  onPressed: busy ? null : _signInApple,
                  backgroundColor: night ? Colors.white : Colors.black,
                  foregroundColor: night ? Colors.black : Colors.white,
                  borderColor: night ? Colors.white : Colors.black,
                  leading: _busyApple
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: night ? Colors.black : Colors.white,
                          ),
                        )
                      : Icon(
                          Icons.apple,
                          size: 22,
                          color: night ? Colors.black : Colors.white,
                        ),
                ),
                const SizedBox(height: 12),
              ],
              AuthSecondaryButton(
                label: l10n.authContinueGoogle,
                onPressed: busy ? null : _signInGoogle,
                leading: _busyGoogle
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: t.ink,
                        ),
                      )
                    : Text(
                        'G',
                        style: TextStyle(
                          fontFamily: kFontUi,
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                          color: t.green700,
                        ),
                      ),
              ),
              const SizedBox(height: 12),
              AuthPrimaryButton(
                label: l10n.authContinueEmail,
                onPressed: busy ? null : () => SignInScreen.open(context),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: busy ? null : () => Navigator.of(context).pop(),
                child: Text(
                  l10n.authContinueGuest,
                  style: TextStyle(
                    fontFamily: kFontUi,
                    fontWeight: FontWeight.w600,
                    color: t.emphasis,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text.rich(
                TextSpan(
                  style: TextStyle(
                    fontFamily: kFontUi,
                    fontSize: 12,
                    color: t.muted,
                  ),
                  children: [
                    TextSpan(
                      text: l10n.authPrivacy,
                      style: TextStyle(
                        color: t.green700,
                        decoration: TextDecoration.underline,
                      ),
                      recognizer: TapGestureRecognizer()
                        ..onTap = () => _openUrl(AuthWelcomeScreen.privacyUrl),
                    ),
                    TextSpan(text: ' · '),
                    TextSpan(
                      text: l10n.authTerms,
                      style: TextStyle(
                        color: t.green700,
                        decoration: TextDecoration.underline,
                      ),
                      recognizer: TapGestureRecognizer()
                        ..onTap = () => _openUrl(AuthWelcomeScreen.termsUrl),
                    ),
                  ],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
