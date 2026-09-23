import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ishamela/l10n/app_localizations.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:ishamela/core/providers.dart';
import 'package:ishamela/features/auth/auth_l10n.dart';
import 'package:ishamela/features/auth/auth_routes.dart';
import 'package:ishamela/features/auth/auth_widgets.dart';
import 'package:ishamela/ui/theme/ishamela_theme.dart';
import 'package:ishamela/ui/theme/ishamela_tokens.dart';

/// SPEC-022 §3.3 — `/auth/sign-up`
class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});

  static Future<void> open(BuildContext context) =>
      pushAuthPage(context, const SignUpScreen());

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  String? _nameError;
  String? _emailError;
  String? _passwordError;
  String? _confirmError;
  bool _obscure = true;
  bool _accepted = false;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    final name = _name.text.trim();
    final email = _email.text.trim();
    final password = _password.text;
    final confirm = _confirm.text;

    setState(() {
      _nameError = name.isEmpty ? l10n.authFieldRequired : null;
      _emailError = email.isEmpty
          ? l10n.authFieldRequired
          : (!isValidEmail(email) ? l10n.authInvalidEmail : null);
      _passwordError = password.length < 8 ? l10n.authPasswordTooShort : null;
      _confirmError =
          confirm != password ? l10n.authPasswordMismatch : null;
    });
    if (!_accepted) {
      showAuthSnack(context, l10n.authMustAcceptTerms);
      return;
    }
    if (_nameError != null ||
        _emailError != null ||
        _passwordError != null ||
        _confirmError != null) {
      return;
    }

    setState(() => _busy = true);
    try {
      await ref.read(authProvider.notifier).signUpEmail(
            email: email,
            password: password,
            displayName: name,
          );
      if (!mounted) return;
      await OtpScreen.open(
        context,
        email: email,
        mode: OtpMode.verify,
      );
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
    final strength = passwordStrengthHint(
      _password.text,
      weak: l10n.authPasswordStrengthWeak,
      ok: l10n.authPasswordStrengthOk,
      strong: l10n.authPasswordStrengthStrong,
    );

    return Scaffold(
      backgroundColor: t.paper,
      appBar: AppBar(
        backgroundColor: t.paper,
        title: Text(
          l10n.authSignUpTitle,
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
            TextField(
              controller: _name,
              textInputAction: TextInputAction.next,
              onChanged: (_) => setState(() => _nameError = null),
              style: authFieldStyle(t),
              decoration: authFieldDecoration(
                context,
                label: l10n.authDisplayName,
                errorText: _nameError,
              ),
            ),
            const SizedBox(height: 14),
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
              autofillHints: const [AutofillHints.newPassword],
              textInputAction: TextInputAction.next,
              onChanged: (_) => setState(() {
                _passwordError = null;
              }),
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
            if (_password.text.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                strength,
                style: TextStyle(
                  fontFamily: kFontUi,
                  fontSize: 12,
                  color: t.muted,
                ),
              ),
            ],
            const SizedBox(height: 14),
            AuthLtrField(
              controller: _confirm,
              label: l10n.authConfirmPassword,
              errorText: _confirmError,
              obscureText: _obscure,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
              onChanged: (_) => setState(() => _confirmError = null),
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Checkbox(
                  value: _accepted,
                  activeColor: t.green700,
                  onChanged: (v) => setState(() => _accepted = v ?? false),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text.rich(
                      TextSpan(
                        style: TextStyle(
                          fontFamily: kFontUi,
                          fontSize: 13,
                          color: t.ink,
                        ),
                        children: [
                          TextSpan(text: '${l10n.authAcceptPrefix} '),
                          TextSpan(
                            text: l10n.authPrivacy,
                            style: TextStyle(
                              color: t.green700,
                              decoration: TextDecoration.underline,
                            ),
                            recognizer: TapGestureRecognizer()
                              ..onTap = () => launchUrl(
                                    Uri.parse(AuthWelcomeScreen.privacyUrl),
                                    mode: LaunchMode.externalApplication,
                                  ),
                          ),
                          TextSpan(text: ' ${l10n.authAcceptAnd} '),
                          TextSpan(
                            text: l10n.authTerms,
                            style: TextStyle(
                              color: t.green700,
                              decoration: TextDecoration.underline,
                            ),
                            recognizer: TapGestureRecognizer()
                              ..onTap = () => launchUrl(
                                    Uri.parse(AuthWelcomeScreen.termsUrl),
                                    mode: LaunchMode.externalApplication,
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            AuthPrimaryButton(
              label: l10n.authSignUp,
              busy: _busy,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}
