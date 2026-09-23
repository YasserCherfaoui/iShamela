import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ishamela/l10n/app_localizations.dart';

import 'package:ishamela/core/auth/auth_state.dart';
import 'package:ishamela/core/providers.dart';
import 'package:ishamela/features/auth/auth_l10n.dart';
import 'package:ishamela/features/auth/auth_routes.dart';
import 'package:ishamela/features/auth/auth_widgets.dart';
import 'package:ishamela/ui/theme/ishamela_theme.dart';
import 'package:ishamela/ui/theme/ishamela_tokens.dart';

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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final t = IshamelaTokens.of(context);

    return Scaffold(
      backgroundColor: t.paper,
      appBar: AppBar(
        backgroundColor: t.paper,
        title: Text(
          l10n.authSignInTitle,
          style: TextStyle(
            fontFamily: kFontAmiri,
            fontWeight: FontWeight.w700,
            fontSize: 22,
            color: t.ink,
          ),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          children: [
            AuthLtrField(
              controller: _email,
              label: l10n.authEmail,
              errorText: _emailError,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              textInputAction: TextInputAction.next,
              onChanged: (_) => setState(() => _emailError = null),
            ),
            const SizedBox(height: 14),
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
                  _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                  color: t.muted,
                ),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton(
                onPressed: () => ForgotPasswordScreen.open(context),
                child: Text(
                  l10n.authForgotPassword,
                  style: TextStyle(
                    fontFamily: kFontUi,
                    color: t.green700,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            AuthPrimaryButton(
              label: l10n.authSignIn,
              busy: _busy,
              onPressed: _submit,
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => SignUpScreen.open(context),
              child: Text(
                l10n.authCreateAccount,
                style: TextStyle(
                  fontFamily: kFontUi,
                  fontWeight: FontWeight.w600,
                  color: t.emphasis,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
