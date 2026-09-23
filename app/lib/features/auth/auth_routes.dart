import 'package:flutter/material.dart';

export 'auth_welcome_screen.dart' show AuthWelcomeScreen;
export 'sign_in_screen.dart' show SignInScreen;
export 'sign_up_screen.dart' show SignUpScreen;
export 'forgot_password_screen.dart' show ForgotPasswordScreen;
export 'otp_screen.dart' show OtpScreen, OtpMode;
export 'reset_password_screen.dart' show ResetPasswordScreen;

/// Shared push helper used by screen `.open` methods (SPEC-022).
Future<T?> pushAuthPage<T>(BuildContext context, Widget page) {
  return Navigator.of(context).push<T>(
    MaterialPageRoute<T>(builder: (_) => page),
  );
}
