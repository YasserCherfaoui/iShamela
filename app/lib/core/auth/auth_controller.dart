import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import 'package:ishamela/core/auth/auth_errors.dart';
import 'package:ishamela/core/auth/firebase_bootstrap.dart';
import 'package:ishamela/core/auth/auth_state.dart';
import 'package:ishamela/core/auth/user_profile.dart';
import 'package:ishamela/core/config.dart';
import 'package:ishamela/core/providers.dart';
import 'package:ishamela/core/sync/api_client.dart';

/// Apple Sign In is available on iOS, macOS, and web — hidden on Android.
bool get supportsAppleSignIn =>
    kIsWeb ||
    defaultTargetPlatform == TargetPlatform.iOS ||
    defaultTargetPlatform == TargetPlatform.macOS;

/// Session follows the project access token and `GET /v1/me` (SPEC-027 / SPEC-028).
class AuthController extends Notifier<AuthStatus> {
  GoogleSignIn? _google;

  @override
  AuthStatus build() {
    Future<void>.microtask(_restore);
    return const AuthGuest();
  }

  Future<void> _restore() async {
    try {
      if (firebaseReady && FirebaseAuth.instance.currentUser != null) {
        final profile = await ref.read(syncApiProvider).getMe();
        if (!ref.mounted) return;
        state = AuthSignedIn(_profile(profile));
        await ref.read(accountSessionProvider).registerDevice();
        return;
      }
      final refresh = await ref.read(tokenStoreProvider).readRefresh();
      if (!ref.mounted) return;
      if (refresh == null || refresh.isEmpty) {
        state = const AuthGuest();
        return;
      }
      final profile = await ref.read(syncApiProvider).getMe();
      if (!ref.mounted) return;
      state = AuthSignedIn(_profile(profile));
      await ref.read(accountSessionProvider).registerDevice();
    } catch (_) {
      if (ref.mounted) state = const AuthGuest();
    }
  }

  UserProfile _profile(ApiProfile profile) {
    return UserProfile(
      uid: profile.id,
      email: profile.email,
      displayName: profile.displayName,
      photoUrl: null,
      providers: const {},
      emailVerified: true,
    );
  }

  Future<void> _adopted() async {
    final profile = await ref.read(syncApiProvider).getMe();
    state = AuthSignedIn(_profile(profile));
    try {
      await ref.read(accountSessionProvider).registerDevice();
    } catch (_) {}
  }

  Future<void> requestEmailCode(String email) {
    return ref.read(syncApiProvider).requestOtp(email.trim());
  }

  Future<void> verifyEmailCode({
    required String email,
    required String code,
  }) async {
    await ref.read(accountSessionProvider).signInWithEmailCode(
      email: email.trim(),
      code: code,
    );
    await _adopted();
  }

  Future<void> signInGoogle() async {
    if (!firebaseReady) {
      throw AuthUnavailable('Authentication is unavailable');
    }
    if (kIsWeb) {
      await FirebaseAuth.instance.signInWithPopup(GoogleAuthProvider());
    } else {
      final applePlatform =
          defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS;
      _google ??= GoogleSignIn(
        clientId: applePlatform ? googleIosClientId : null,
        // Android and Apple platforms mint the ID token for the web client.
        // iOS still puts the iOS client ID in `aud`.
        serverClientId: googleWebClientId,
        scopes: const ['email', 'profile'],
      );
      final account = await _google!.signIn();
      if (account == null) return;
      final googleAuth = await account.authentication;
      final idToken = googleAuth.idToken;
      if (idToken == null || idToken.isEmpty) {
        throw AuthUnavailable('Google Sign-In did not return an ID token');
      }
      await FirebaseAuth.instance.signInWithCredential(
        GoogleAuthProvider.credential(
          idToken: idToken,
          accessToken: googleAuth.accessToken,
        ),
      );
    }
    await ref.read(accountSessionProvider).adoptFirebase();
    await _adopted();
  }

  Future<void> signInApple() async {
    if (!supportsAppleSignIn) {
      throw AuthUnavailable('Apple Sign In is not available on this platform');
    }
    if (!firebaseReady) {
      throw AuthUnavailable('Authentication is unavailable');
    }
    if (kIsWeb) {
      final apple = OAuthProvider('apple.com')
        ..addScope('email')
        ..addScope('name');
      await FirebaseAuth.instance.signInWithPopup(apple);
      await ref.read(accountSessionProvider).adoptFirebase();
      await _adopted();
      return;
    }
    final apple = await SignInWithApple.getAppleIDCredential(
      scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
    );
    final identity = apple.identityToken;
    if (identity == null || identity.isEmpty) {
      throw AuthUnavailable('Apple Sign-In did not return an identity token');
    }
    final credential = OAuthProvider('apple.com').credential(
      idToken: identity,
      accessToken: apple.authorizationCode,
    );
    await FirebaseAuth.instance.signInWithCredential(credential);
    await ref.read(accountSessionProvider).adoptFirebase();
    await _adopted();
    final given = apple.givenName;
    final family = apple.familyName;
    final name = [given, family].whereType<String>().join(' ').trim();
    final current = state.profileOrNull?.displayName;
    if (name.isNotEmpty && (current == null || current.isEmpty)) {
      await updateDisplayName(name);
    }
  }

  Future<void> signOut({bool keepData = true}) async {
    try {
      await ref.read(accountSessionProvider).signOut(keepData: keepData);
    } catch (_) {}
    try {
      await _google?.signOut();
    } catch (_) {}
    try {
      if (firebaseReady) await FirebaseAuth.instance.signOut();
    } catch (_) {}
    state = const AuthGuest();
  }

  Future<void> updateDisplayName(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty || trimmed.length > 40) {
      throw ArgumentError('displayName must be 1–40 characters');
    }
    if (state is! AuthSignedIn) throw AuthUnavailable('Not signed in');
    final profile = await ref.read(syncApiProvider).patchMe(trimmed);
    state = AuthSignedIn(_profile(profile));
  }

  /// Deletes the account and the synced rows on this device.
  Future<void> deleteAccount() async {
    if (state is! AuthSignedIn) throw AuthUnavailable('Not signed in');
    await ref.read(accountSessionProvider).deleteAccount();
    state = const AuthGuest();
  }
}
