import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ishamela/l10n/app_localizations.dart';

import 'package:ishamela/core/auth/auth_controller.dart';
import 'package:ishamela/core/auth/auth_state.dart';
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
  final _password = TextEditingController();
  String? _emailError;
  String? _passwordError;
  bool _obscure = true;
  bool _busy = false;
  bool _busyApple = false;
  bool _busyGoogle = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    final email = _email.text.trim();
    final password = _password.text;
    setState(() {
      _emailError = email.isEmpty
          ? l10n.authFieldRequired
          : (!isValidEmail(email) ? l10n.authInvalidEmail : null);
      _passwordError = password.isEmpty ? l10n.authFieldRequired : null;
    });
    if (_emailError != null || _passwordError != null) return;

    setState(() => _busy = true);
    try {
      await ref.read(authProvider.notifier).signInEmail(
            email: email,
            password: password,
          );
      if (!mounted) return;
      final status = ref.read(authProvider);
      if (status is AuthSignedInUnverified) {
        await ref.read(authProvider.notifier).sendOtp(
              email: email,
              purpose: 'verify',
            );
        if (!mounted) return;
        await OtpScreen.open(
          context,
          email: email,
          mode: OtpMode.verify,
        );
        return;
      }
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
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
    final linkStyle = TextStyle(
      fontFamily: kFontUi,
      fontWeight: FontWeight.w600,
      fontSize: 13,
      color: t.emphasis,
    );

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
              textInputAction: TextInputAction.next,
              onChanged: (_) => setState(() => _emailError = null),
            ),
            const SizedBox(height: 16),
            AuthLtrField(
              controller: _password,
              label: l10n.authPassword,
              errorText: _passwordError,
              obscureText: _obscure,
              autofillHints: const [AutofillHints.password],
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
              onChanged: (_) => setState(() => _passwordError = null),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscure
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: t.muted,
                ),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                TextButton(
                  onPressed: () => ForgotPasswordScreen.open(context),
                  child: Text(l10n.authForgotPassword, style: linkStyle),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => SignUpScreen.open(context),
                  child: Text(l10n.authCreateAccount, style: linkStyle),
                ),
              ],
            ),
            const SizedBox(height: 8),
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
