/// Thrown when Firebase is not configured / init failed (guest forever).
class AuthUnavailable implements Exception {
  AuthUnavailable([this.message = 'Authentication is unavailable']);
  final String message;

  @override
  String toString() => 'AuthUnavailable: $message';
}

/// Maps Firebase Auth error codes to ARB message keys (SPEC-022 §3.2).
///
/// `wrong-password` / `user-not-found` / `invalid-credential` share one key
/// so we never reveal whether the email exists.
String mapAuthErrorToMessageKey(Object error) {
  final code = _authCode(error);
  switch (code) {
    case 'wrong-password':
    case 'user-not-found':
    case 'invalid-credential':
    case 'INVALID_LOGIN_CREDENTIALS':
      return 'authWrongCredentials';
    case 'email-already-in-use':
      return 'authEmailAlreadyInUse';
    case 'weak-password':
      return 'authWeakPassword';
    case 'invalid-email':
      return 'authInvalidEmail';
    case 'too-many-requests':
      return 'authTooManyRequests';
    case 'network-request-failed':
      return 'authNetworkError';
    case 'requires-recent-login':
      return 'authRequiresRecentLogin';
    case 'user-disabled':
      return 'authSessionExpired';
    case 'otp-invalid':
      return 'authOtpWrong';
    case 'otp-expired':
      return 'authOtpExpired';
    case 'otp-locked':
      return 'authOtpLocked';
    default:
      if (error is AuthUnavailable) return 'authUnavailable';
      return 'authGenericError';
  }
}

String? _authCode(Object error) {
  try {
    // Avoid a hard import of firebase_auth in pure unit tests: duck-type `.code`.
    final dynamic e = error;
    final code = e.code;
    if (code is String) return code;
  } catch (_) {}
  return null;
}

/// Minimal stand-in used by unit tests (mirrors FirebaseAuthException.code).
class AuthErrorCode {
  AuthErrorCode(this.code);
  final String code;
}
