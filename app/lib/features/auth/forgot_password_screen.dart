import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ishamela/l10n/app_localizations.dart';

import 'package:ishamela/core/providers.dart';
import 'package:ishamela/features/auth/auth_l10n.dart';
import 'package:ishamela/features/auth/auth_routes.dart';
import 'package:ishamela/features/auth/auth_widgets.dart';
import 'package:ishamela/ui/theme/ishamela_theme.dart';
import 'package:ishamela/ui/theme/ishamela_tokens.dart';

/// SPEC-022 §3.4 — `/auth/forgot`
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  static Future<void> open(BuildContext context) =>
      pushAuthPage(context, const ForgotPasswordScreen());

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _email = TextEditingController();
  String? _emailError;
  bool _busy = false;

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
      // Always show success — no account enumeration (SPEC-022 §3.4).
      try {
        await ref.read(authProvider.notifier).sendOtp(
              email: email,
              purpose: 'reset',
            );
      } catch (_) {
        // Swallow — still show generic OK.
      }
      if (!mounted) return;
      showAuthSnack(context, l10n.authForgotSuccess);
      await OtpScreen.open(
        context,
        email: email,
        mode: OtpMode.reset,
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

    return Scaffold(
      backgroundColor: t.paper,
      appBar: AppBar(
        backgroundColor: t.paper,
        title: Text(
          l10n.authForgotTitle,
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
            Text(
              l10n.authForgotCopy,
              style: TextStyle(
                fontFamily: kFontUi,
                fontSize: 15,
                height: 1.5,
                color: t.muted,
              ),
            ),
            const SizedBox(height: 20),
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
            const SizedBox(height: 24),
            AuthPrimaryButton(
              label: l10n.authSendCode,
              busy: _busy,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}
