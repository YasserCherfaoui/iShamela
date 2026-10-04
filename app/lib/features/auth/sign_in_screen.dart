import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ishamela/l10n/app_localizations.dart';

import 'package:ishamela/core/auth/auth_controller.dart';
import 'package:ishamela/core/providers.dart';
import 'package:ishamela/features/auth/auth_l10n.dart';
import 'package:ishamela/features/auth/auth_routes.dart';
import 'package:ishamela/features/auth/auth_widgets.dart';
import 'package:ishamela/ui/rosette_divider.dart';
import 'package:ishamela/ui/theme/ishamela_theme.dart';
import 'package:ishamela/ui/theme/ishamela_tokens.dart';
import 'package:ishamela/ui/theme/reader_theme_tokens.dart';

/// SPEC-022 §3.2 — `/auth/sign-in`
class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  static Future<void> open(BuildContext context) =>
      pushAuthPage(context, const SignInScreen());

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _email = TextEditingController();
  String? _emailError;
  bool _busy = false;
  bool _busyApple = false;
  bool _busyGoogle = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    final email = _email.text.trim();
    setState(() {
      _emailError = email.isEmpty
          ? l10n.authFieldRequired
          : (!isValidEmail(email) ? l10n.authInvalidEmail : null);
    });
    if (_emailError != null) return;

    setState(() => _busy = true);
    try {
      await ref.read(authProvider.notifier).requestEmailCode(email);
      if (!mounted) return;
      await OtpScreen.open(context, email: email, mode: OtpMode.verify);
    } catch (e) {
      if (mounted) showAuthSnack(context, localizeAuthError(l10n, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
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
    final oauthBusy = _busy || _busyApple || _busyGoogle;

    return Scaffold(
      backgroundColor: t.paper,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          children: [
            AuthTopBar(
              title: l10n.authSignInTitle,
              onBack: () => Navigator.of(context).pop(),
            ),
            const SizedBox(height: 8),
            const RosetteDivider(),
            const SizedBox(height: 28),
            AuthLtrField(
              controller: _email,
              label: l10n.authEmail,
              errorText: _emailError,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
              onChanged: (_) => setState(() => _emailError = null),
            ),
            const SizedBox(height: 20),
            AuthPrimaryButton(
              label: l10n.authSignIn,
              busy: _busy,
              onPressed: oauthBusy ? null : _submit,
            ),
            const SizedBox(height: 28),
            AuthOrDivider(label: l10n.authOr),
            const SizedBox(height: 20),
            Row(
              children: [
                if (supportsAppleSignIn) ...[
                  Expanded(
                    child: AuthSecondaryButton(
                      label: 'Apple',
                      iconAtEnd: true,
                      onPressed: oauthBusy ? null : _signInApple,
                      backgroundColor:
                          night ? Colors.white : const Color(0xFF1A1A1A),
                      foregroundColor: night ? Colors.black : Colors.white,
                      borderColor:
                          night ? Colors.white : const Color(0xFF1A1A1A),
                      leading: Icon(
                        Icons.apple,
                        size: 20,
                        color: night ? Colors.black : Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: AuthSecondaryButton(
                    label: 'Google',
                    iconAtEnd: true,
                    onPressed: oauthBusy ? null : _signInGoogle,
                    leading: Text(
                      'G',
                      style: TextStyle(
                        fontFamily: kFontUi,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: const Color(0xFF4285F4),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
