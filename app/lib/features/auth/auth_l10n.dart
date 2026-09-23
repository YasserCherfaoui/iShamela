import 'package:ishamela/l10n/app_localizations.dart';

import 'package:ishamela/core/auth/auth_errors.dart';

/// Resolves [mapAuthErrorToMessageKey] against generated l10n.
String localizeAuthError(AppLocalizations l10n, Object error) {
  switch (mapAuthErrorToMessageKey(error)) {
    case 'authWrongCredentials':
      return l10n.authWrongCredentials;
    case 'authEmailAlreadyInUse':
      return l10n.authEmailAlreadyInUse;
    case 'authWeakPassword':
      return l10n.authWeakPassword;
    case 'authInvalidEmail':
      return l10n.authInvalidEmail;
    case 'authTooManyRequests':
      return l10n.authTooManyRequests;
    case 'authNetworkError':
      return l10n.authNetworkError;
    case 'authRequiresRecentLogin':
      return l10n.authRequiresRecentLogin;
    case 'authSessionExpired':
      return l10n.authSessionExpired;
    case 'authOtpWrong':
      return l10n.authOtpWrong;
    case 'authOtpExpired':
      return l10n.authOtpExpired;
    case 'authOtpLocked':
      return l10n.authOtpLocked;
    case 'authUnavailable':
      return l10n.authUnavailable;
    default:
      return l10n.authGenericError;
  }
}
