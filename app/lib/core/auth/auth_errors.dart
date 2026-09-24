/// Thrown when Firebase is not configured / init failed (guest forever).
class AuthUnavailable implements Exception {
  AuthUnavailable([this.message = 'Authentication is unavailable']);
  final String message;

  @override
  String toString() => 'AuthUnavailable: $message';
}

/// Maps Firebase Auth / Functions / platform errors to ARB message keys (SPEC-022).
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
    case 'resource-exhausted':
      return 'authTooManyRequests';
    case 'network-request-failed':
    case 'unavailable':
      return 'authNetworkError';
    case 'requires-recent-login':
      return 'authRequiresRecentLogin';
    case 'user-disabled':
      return 'authSessionExpired';
    case 'otp-invalid':
    case 'invalid-argument':
      return 'authOtpWrong';
    case 'otp-expired':
    case 'deadline-exceeded':
      return 'authOtpExpired';
    case 'otp-locked':
      return 'authOtpLocked';
    case 'not-found':
    case 'unimplemented':
    case 'failed-precondition':
      return 'authUnavailable';
    default:
      if (error is AuthUnavailable) return 'authUnavailable';
      return 'authGenericError';
  }
}

String? _authCode(Object error) {
  try {
    final dynamic e = error;
    // FirebaseAuthException / FirebaseFunctionsException / PlatformException
    final code = e.code;
    if (code is String && code.isNotEmpty) {
      // Functions use "functions/not-found"; Auth uses "auth/..." or bare codes.
      final slash = code.lastIndexOf('/');
      return slash >= 0 ? code.substring(slash + 1) : code;
    }
  } catch (_) {}
  return null;
}

/// Minimal stand-in used by unit tests (mirrors FirebaseAuthException.code).
class AuthErrorCode {
  AuthErrorCode(this.code);
  final String code;
}
