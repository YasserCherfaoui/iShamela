import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:ishamela/ui/theme/ishamela_theme.dart';
import 'package:ishamela/ui/theme/ishamela_tokens.dart';

/// Shared auth field chrome (Warm Manuscript).
InputDecoration authFieldDecoration(
  BuildContext context, {
  required String label,
  String? errorText,
  Widget? suffixIcon,
}) {
  final t = IshamelaTokens.of(context);
  return InputDecoration(
    labelText: label,
    errorText: errorText,
    filled: true,
    fillColor: t.card,
    suffixIcon: suffixIcon,
    labelStyle: TextStyle(fontFamily: kFontUi, color: t.muted),
    errorStyle: TextStyle(
      fontFamily: kFontUi,
      color: Theme.of(context).colorScheme.error,
      fontSize: 12,
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: t.hairline),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: t.hairline),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: t.green700, width: 1.5),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: Theme.of(context).colorScheme.error),
    ),
  );
}

TextStyle authFieldStyle(IshamelaTokens t) => TextStyle(
      fontFamily: kFontUi,
      fontSize: 15,
      color: t.ink,
    );

/// Primary green filled CTA.
class AuthPrimaryButton extends StatelessWidget {
  const AuthPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.busy = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final t = IshamelaTokens.of(context);
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: FilledButton(
        onPressed: busy ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: t.green700,
          foregroundColor: Colors.white,
          disabledBackgroundColor: t.green700.withValues(alpha: 0.4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: busy
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Text(
                label,
                style: const TextStyle(
                  fontFamily: kFontUi,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
      ),
    );
  }
}

/// Outline / tonal secondary CTA.
class AuthSecondaryButton extends StatelessWidget {
  const AuthSecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.leading,
    this.backgroundColor,
    this.foregroundColor,
    this.borderColor,
  });

  final String label;
  final VoidCallback? onPressed;
  final Widget? leading;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final t = IshamelaTokens.of(context);
    final fg = foregroundColor ?? t.ink;
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: backgroundColor ?? t.card,
          foregroundColor: fg,
          side: BorderSide(color: borderColor ?? t.hairline),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (leading != null) ...[
              leading!,
              const SizedBox(width: 10),
            ],
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontFamily: kFontUi,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                  color: fg,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

bool isValidEmail(String raw) {
  final s = raw.trim();
  if (s.isEmpty) return false;
  return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(s);
}

String passwordStrengthHint(String password, {required String weak, required String ok, required String strong}) {
  if (password.length < 8) return weak;
  final hasLetter = RegExp(r'[A-Za-z\u0600-\u06FF]').hasMatch(password);
  final hasDigit = RegExp(r'\d').hasMatch(password);
  if (hasLetter && hasDigit && password.length >= 12) return strong;
  return ok;
}

void showAuthSnack(BuildContext context, String message) {
  final t = IshamelaTokens.of(context);
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        message,
        style: const TextStyle(fontFamily: kFontUi, color: Colors.white),
      ),
      backgroundColor: t.green900,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );
}

/// LTR text field for email / password / OTP digits inside RTL screens.
class AuthLtrField extends StatelessWidget {
  const AuthLtrField({
    super.key,
    required this.controller,
    required this.label,
    this.errorText,
    this.obscureText = false,
    this.keyboardType,
    this.autofillHints,
    this.onChanged,
    this.suffixIcon,
    this.textInputAction,
    this.onSubmitted,
    this.inputFormatters,
  });

  final TextEditingController controller;
  final String label;
  final String? errorText;
  final bool obscureText;
  final TextInputType? keyboardType;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onChanged;
  final Widget? suffixIcon;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final List<TextInputFormatter>? inputFormatters;

  @override
  Widget build(BuildContext context) {
    final t = IshamelaTokens.of(context);
    return Directionality(
      textDirection: TextDirection.ltr,
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        autofillHints: autofillHints,
        onChanged: onChanged,
        textInputAction: textInputAction,
        onSubmitted: onSubmitted,
        inputFormatters: inputFormatters,
        style: authFieldStyle(t),
        decoration: authFieldDecoration(
          context,
          label: label,
          errorText: errorText,
          suffixIcon: suffixIcon,
        ),
      ),
    );
  }
}
