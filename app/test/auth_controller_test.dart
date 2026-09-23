import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ishamela/core/auth/auth_errors.dart';
import 'package:ishamela/core/auth/auth_state.dart';
import 'package:ishamela/core/auth/firebase_bootstrap.dart';
import 'package:ishamela/core/providers.dart';

void main() {
  test('auth defaults to guest when Firebase is not ready', () {
    firebaseReady = false;
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final status = container.read(authProvider);
    expect(status, isA<AuthGuest>());
    expect(status.isGuest, isTrue);
  });

  test('wrong-password / user-not-found / invalid-credential map to one key', () {
    expect(
      mapAuthErrorToMessageKey(AuthErrorCode('wrong-password')),
      'authWrongCredentials',
    );
    expect(
      mapAuthErrorToMessageKey(AuthErrorCode('user-not-found')),
      'authWrongCredentials',
    );
    expect(
      mapAuthErrorToMessageKey(AuthErrorCode('invalid-credential')),
      'authWrongCredentials',
    );
  });

  test('AuthUnavailable maps to authUnavailable key', () {
    expect(
      mapAuthErrorToMessageKey(AuthUnavailable()),
      'authUnavailable',
    );
  });
}
