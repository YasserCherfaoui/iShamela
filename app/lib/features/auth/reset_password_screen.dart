import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ishamela/l10n/app_localizations.dart';

import 'package:ishamela/core/providers.dart';
import 'package:ishamela/features/auth/auth_l10n.dart';
import 'package:ishamela/features/auth/auth_routes.dart';
import 'package:ishamela/features/auth/auth_widgets.dart';
import 'package:ishamela/ui/theme/ishamela_theme.dart';
import 'package:ishamela/ui/theme/ishamela_tokens.dart';

/// SPEC-022 §3.6 — `/auth/reset`
class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({
    super.key,
    required this.email,
    required this.resetToken,
  });

  final String email;
  final String resetToken;

  static Future<void> open(
    BuildContext context, {
    required String email,
    required String resetToken,
  }) =>
      pushAuthPage(
        context,
        ResetPasswordScreen(email: email, resetToken: resetToken),
      );

  @override
  ConsumerState<ResetPasswordScreen> createState() =>
      _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  String? _passwordError;
  String? _confirmError;
  bool _obscure = true;
  bool _busy = false;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    final password = _password.text;
    final confirm = _confirm.text;
    setState(() {
      _passwordError = password.length < 8 ? l10n.authPasswordTooShort : null;
      _confirmError =
          confirm != password ? l10n.authPasswordMismatch : null;
    });
    if (_passwordError != null || _confirmError != null) return;

    setState(() => _busy = true);
    try {
      await ref.read(authProvider.notifier).resetPassword(
            email: widget.email,
            resetToken: widget.resetToken,
            newPassword: password,
          );
      if (!mounted) return;
      showAuthSnack(context, l10n.authPasswordChanged);
      Navigator.of(context).popUntil((r) => r.isFirst);
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
          l10n.authResetTitle,
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
              controller: _password,
              label: l10n.authNewPassword,
              errorText: _passwordError,
              obscureText: _obscure,
              autofillHints: const [AutofillHints.newPassword],
              textInputAction: TextInputAction.next,
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
            const SizedBox(height: 24),
            AuthPrimaryButton(
              label: l10n.authSavePassword,
              busy: _busy,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}
