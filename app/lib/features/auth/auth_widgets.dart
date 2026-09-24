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
    labelText: label.isEmpty ? null : label,
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
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: t.hairline),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: t.hairline),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: t.goldSoft, width: 1.4),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: Theme.of(context).colorScheme.error),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
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
      height: 52,
      child: FilledButton(
        onPressed: busy ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: t.green700,
          foregroundColor: Colors.white,
          disabledBackgroundColor: t.green700.withValues(alpha: 0.4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
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
    this.iconAtEnd = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final Widget? leading;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final Color? borderColor;

  /// Places [leading] after the label so it sits on the left in RTL.
  final bool iconAtEnd;

  @override
  Widget build(BuildContext context) {
    final t = IshamelaTokens.of(context);
    final fg = foregroundColor ?? t.ink;
    final labelWidget = Flexible(
      child: Text(
        label,
        style: TextStyle(
          fontFamily: kFontUi,
          fontWeight: FontWeight.w600,
          fontSize: 15,
          color: fg,
        ),
      ),
    );
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: backgroundColor ?? t.card,
          foregroundColor: fg,
          side: BorderSide(color: borderColor ?? t.hairline),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (!iconAtEnd && leading != null) ...[
              leading!,
              const SizedBox(width: 10),
            ],
            labelWidget,
            if (iconAtEnd && leading != null) ...[
              const SizedBox(width: 8),
              leading!,
            ],
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          textAlign: TextAlign.start,
          style: TextStyle(
            fontFamily: kFontUi,
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: t.ink,
          ),
        ),
        const SizedBox(height: 8),
        Directionality(
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
              label: '',
              errorText: errorText,
              suffixIcon: suffixIcon,
            ),
          ),
        ),
      ],
    );
  }
}

/// Circular back/close control used on every auth screen.
class AuthCircleButton extends StatelessWidget {
  const AuthCircleButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final t = IshamelaTokens.of(context);
    return Material(
      color: t.card,
      shape: CircleBorder(side: BorderSide(color: t.hairline)),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(icon, size: 20, color: t.emphasis),
        ),
      ),
    );
  }
}

/// Title on the leading edge, circle control beside it (SPEC-022 screens).
class AuthTopBar extends StatelessWidget {
  const AuthTopBar({
    super.key,
    required this.title,
    required this.onBack,
    this.close = false,
  });

  final String title;
  final VoidCallback onBack;
  final bool close;

  @override
  Widget build(BuildContext context) {
    final t = IshamelaTokens.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
      child: Row(
        children: [
          AuthCircleButton(
            icon: close ? Icons.close : Icons.chevron_right,
            onPressed: onBack,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              textAlign: TextAlign.start,
              style: TextStyle(
                fontFamily: kFontAmiri,
                fontWeight: FontWeight.w700,
                fontSize: 28,
                color: t.emphasis,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Green rounded brand lockup from the welcome design.
class AuthBrandMark extends StatelessWidget {
  const AuthBrandMark({super.key, this.size = 84});

  final double size;

  @override
  Widget build(BuildContext context) {
    final t = IshamelaTokens.of(context);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: t.green900,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: t.goldSoft, width: 1.5),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(Icons.menu_book_rounded, color: Colors.white, size: size * 0.42),
          Positioned(
            top: size * 0.16,
            child: Icon(Icons.star_rounded, color: t.goldSoft, size: size * 0.18),
          ),
        ],
      ),
    );
  }
}

double passwordStrengthFraction(String password) {
  if (password.isEmpty) return 0;
  if (password.length < 8) return 0.28;
  final hasLetter = RegExp(r'[A-Za-z\u0600-\u06FF]').hasMatch(password);
  final hasDigit = RegExp(r'\d').hasMatch(password);
  if (hasLetter && hasDigit && password.length >= 12) return 1;
  return 0.62;
}

class PasswordStrengthBar extends StatelessWidget {
  const PasswordStrengthBar({
    super.key,
    required this.password,
    required this.label,
  });

  final String password;
  final String label;

  @override
  Widget build(BuildContext context) {
    if (password.isEmpty) return const SizedBox.shrink();
    final t = IshamelaTokens.of(context);
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(
            fontFamily: kFontUi,
            fontSize: 12,
            color: t.muted,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: passwordStrengthFraction(password),
              minHeight: 3,
              backgroundColor: t.hairline,
              color: t.goldSoft,
            ),
          ),
        ),
      ],
    );
  }
}

/// Hairline with a centered word («أو»).
class AuthOrDivider extends StatelessWidget {
  const AuthOrDivider({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final t = IshamelaTokens.of(context);
    return Row(
      children: [
        Expanded(child: Divider(color: t.hairline)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            label,
            style: TextStyle(
              fontFamily: kFontUi,
              fontSize: 13,
              color: t.muted,
            ),
          ),
        ),
        Expanded(child: Divider(color: t.hairline)),
      ],
    );
  }
}
