import 'package:ishamela/core/auth/user_profile.dart';

/// Session status exposed by [AuthController] (SPEC-022 §4).
sealed class AuthStatus {
  const AuthStatus();
}

/// Signed out — full guest mode; local SQLite is the only store.
final class AuthGuest extends AuthStatus {
  const AuthGuest();
}

/// Signed in but email not yet verified; sync disabled.
final class AuthSignedInUnverified extends AuthStatus {
  const AuthSignedInUnverified(this.profile);
  final UserProfile profile;
}

/// Fully verified session; sync may run.
final class AuthSignedIn extends AuthStatus {
  const AuthSignedIn(this.profile);
  final UserProfile profile;
}

/// Convenience: profile when signed in (verified or not), else null.
extension AuthStatusX on AuthStatus {
  UserProfile? get profileOrNull => switch (this) {
        AuthGuest() => null,
        AuthSignedInUnverified(:final profile) => profile,
        AuthSignedIn(:final profile) => profile,
      };

  bool get isGuest => this is AuthGuest;
  bool get isVerified => this is AuthSignedIn;
}
