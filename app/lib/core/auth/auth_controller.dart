import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import 'package:ishamela/core/auth/auth_errors.dart';
import 'package:ishamela/core/auth/auth_state.dart';
import 'package:ishamela/core/auth/firebase_bootstrap.dart';
import 'package:ishamela/core/auth/merge_local_data.dart';
import 'package:ishamela/core/auth/sync_service.dart';
import 'package:ishamela/core/auth/user_profile.dart';
import 'package:ishamela/core/db/state_database.dart';
import 'package:ishamela/core/library/library_plan.dart';

/// Apple Sign In is available on iOS, macOS, and web — hidden on Android.
bool get supportsAppleSignIn =>
    kIsWeb ||
    defaultTargetPlatform == TargetPlatform.iOS ||
    defaultTargetPlatform == TargetPlatform.macOS;

/// Riverpod auth controller listening to `authStateChanges` when Firebase is ready.
class AuthController extends Notifier<AuthStatus> {
  StreamSubscription<User?>? _sub;
  final SyncService _sync = SyncService();
  GoogleSignIn? _google;

  FirebaseAuth get _auth {
    if (!firebaseReady) throw AuthUnavailable();
    return FirebaseAuth.instance;
  }

  FirebaseFunctions get _functions {
    if (!firebaseReady) throw AuthUnavailable();
    return FirebaseFunctions.instanceFor(region: 'europe-west1');
  }

  @override
  AuthStatus build() {
    ref.onDispose(() {
      _sub?.cancel();
      _sub = null;
    });
    if (!firebaseReady) {
      return const AuthGuest();
    }
    _sub?.cancel();
    _sub = FirebaseAuth.instance.authStateChanges().listen(
      _onUser,
      onError: (_) => state = const AuthGuest(),
    );
    return _statusFromUser(FirebaseAuth.instance.currentUser);
  }

  void _onUser(User? user) {
    state = _statusFromUser(user);
  }

  AuthStatus _statusFromUser(User? user) {
    if (user == null) return const AuthGuest();
    final profile = _profileFromUser(user);
    if (!profile.emailVerified &&
        profile.providers.contains(AuthProviderKind.email)) {
      return AuthSignedInUnverified(profile);
    }
    return AuthSignedIn(profile);
  }

  UserProfile _profileFromUser(User user) {
    final providers = <AuthProviderKind>{};
    for (final info in user.providerData) {
      switch (info.providerId) {
        case 'apple.com':
          providers.add(AuthProviderKind.apple);
        case 'google.com':
          providers.add(AuthProviderKind.google);
        case 'password':
          providers.add(AuthProviderKind.email);
      }
    }
    // OAuth users are treated as verified for sync purposes.
    final verified = user.emailVerified ||
        providers.contains(AuthProviderKind.google) ||
        providers.contains(AuthProviderKind.apple);
    return UserProfile(
      uid: user.uid,
      email: user.email,
      displayName: user.displayName,
      photoUrl: user.photoURL,
      providers: providers,
      emailVerified: verified,
    );
  }

  Future<void> signInEmail({
    required String email,
    required String password,
  }) async {
    await _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<void> signUpEmail({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    final name = displayName.trim();
    if (name.isNotEmpty) {
      await cred.user?.updateDisplayName(name);
    }
    await sendOtp(email: email, purpose: 'verify');
  }

  Future<void> signInGoogle() async {
    if (!firebaseReady) throw AuthUnavailable();
    if (kIsWeb) {
      final provider = GoogleAuthProvider();
      await _auth.signInWithPopup(provider);
      return;
    }
    // iOS/macOS CLIENT_ID from GoogleService-Info (GIDClientID). Web client
    // (type 3) as serverClientId so Google returns an idToken Firebase accepts.
    const iosClientId =
        '940987204287-638kvo2uo56bj712ospf2cso3prhfvpq.apps.googleusercontent.com';
    const webClientId =
        '940987204287-i32s08v3mlpngvn98v58q133m2h5kpt3.apps.googleusercontent.com';
    final applePlatform = defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;
    _google ??= GoogleSignIn(
      clientId: applePlatform ? iosClientId : null,
      serverClientId: applePlatform ? webClientId : null,
      scopes: const ['email', 'profile'],
    );
    final account = await _google!.signIn();
    if (account == null) return; // user cancelled
    final googleAuth = await account.authentication;
    final idToken = googleAuth.idToken;
    if (idToken == null) {
      throw AuthUnavailable('Google Sign-In did not return an ID token');
    }
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: idToken,
    );
    await _auth.signInWithCredential(credential);
  }

  Future<void> signInApple() async {
    if (!supportsAppleSignIn) {
      throw AuthUnavailable('Apple Sign In is not available on this platform');
    }
    if (!firebaseReady) throw AuthUnavailable();
    if (kIsWeb) {
      final provider = AppleAuthProvider();
      await _auth.signInWithPopup(provider);
      return;
    }
    final apple = await SignInWithApple.getAppleIDCredential(
      scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
    );
    final oauth = OAuthProvider('apple.com').credential(
      idToken: apple.identityToken,
      accessToken: apple.authorizationCode,
    );
    final cred = await _auth.signInWithCredential(oauth);
    final given = apple.givenName;
    final family = apple.familyName;
    if (cred.user != null &&
        (cred.user!.displayName == null || cred.user!.displayName!.isEmpty) &&
        (given != null || family != null)) {
      final name = [given, family].whereType<String>().join(' ').trim();
      if (name.isNotEmpty) {
        await cred.user!.updateDisplayName(name);
      }
    }
  }

  Future<void> signOut() async {
    if (!firebaseReady) {
      state = const AuthGuest();
      return;
    }
    try {
      await _google?.signOut();
    } catch (_) {}
    await FirebaseAuth.instance.signOut();
  }

  Future<void> sendOtp({
    required String email,
    required String purpose,
  }) async {
    if (!firebaseReady) throw AuthUnavailable();
    final callable = _functions.httpsCallable('sendOtp');
    await callable.call<Map<String, dynamic>>({
      'email': email.trim(),
      'purpose': purpose,
    });
  }

  /// Returns a one-shot [resetToken] when [purpose] is `reset`; otherwise null.
  Future<String?> verifyOtp({
    required String email,
    required String code,
    required String purpose,
  }) async {
    if (!firebaseReady) throw AuthUnavailable();
    final callable = _functions.httpsCallable('verifyOtp');
    final result = await callable.call<Map<String, dynamic>>({
      'email': email.trim(),
      'code': code.trim(),
      'purpose': purpose,
    });
    final data = result.data;
    if (purpose == 'verify') {
      await reloadUser();
      return null;
    }
    final token = data['resetToken'];
    return token is String ? token : null;
  }

  Future<void> resetPassword({
    required String email,
    required String resetToken,
    required String newPassword,
  }) async {
    if (!firebaseReady) throw AuthUnavailable();
    final callable = _functions.httpsCallable('resetPassword');
    await callable.call<Map<String, dynamic>>({
      'email': email.trim(),
      'resetToken': resetToken,
      'newPassword': newPassword,
    });
    await signInEmail(email: email, password: newPassword);
  }

  Future<void> reloadUser() async {
    if (!firebaseReady) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await user.reload();
    state = _statusFromUser(FirebaseAuth.instance.currentUser);
  }

  Future<void> updateDisplayName(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty || trimmed.length > 40) {
      throw ArgumentError('displayName must be 1–40 characters');
    }
    final user = _auth.currentUser;
    if (user == null) throw AuthUnavailable('Not signed in');
    await user.updateDisplayName(trimmed);
    await reloadUser();
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = _auth.currentUser;
    if (user == null || user.email == null) {
      throw AuthUnavailable('Not signed in with email');
    }
    await reauthenticate(password: currentPassword);
    await user.updatePassword(newPassword);
  }

  Future<void> deleteAccount({bool wipeLocal = false}) async {
    if (!firebaseReady) throw AuthUnavailable();
    final callable = _functions.httpsCallable('deleteAccount');
    await callable.call<Map<String, dynamic>>({'wipeLocal': wipeLocal});
    await signOut();
    // Local wipe is owned by Profile (SPEC-024); auth only signs out.
  }

  Future<void> reauthenticate({String? password}) async {
    final user = _auth.currentUser;
    if (user == null) throw AuthUnavailable('Not signed in');
    final providers = user.providerData.map((p) => p.providerId).toSet();
    if (password != null &&
        user.email != null &&
        providers.contains('password')) {
      final cred = EmailAuthProvider.credential(
        email: user.email!,
        password: password,
      );
      await user.reauthenticateWithCredential(cred);
      return;
    }
    if (providers.contains('google.com')) {
      await signInGoogle();
      return;
    }
    if (providers.contains('apple.com')) {
      await signInApple();
      return;
    }
    throw AuthUnavailable('No reauthentication method available');
  }

  /// First verified sign-in merge (SPEC-022 §6). Non-fatal on failure.
  Future<void> mergeLocalAfterVerify(
    StateDatabase db, {
    void Function(String messageKey)? onProgress,
    void Function(String messageKey)? onFailure,
  }) async {
    final status = state;
    if (status is! AuthSignedIn) return;
    try {
      final bookIds = {
        ...db.installedBookIds(),
        ...db.listReadingHistory().map((e) => e.bookId),
      };
      final snap = snapshotLocalUserData(db, bookIds: bookIds);
      await _sync.mergeLocalData(
        uid: status.profile.uid,
        local: snap,
        onProgress: onProgress,
        onFailure: onFailure,
      );
      await _pullReading(status.profile.uid, db);
    } catch (_) {
      onFailure?.call(kSyncFailedMessageKey);
    }
  }

  /// Manual two-way sync from Profile (SPEC-024 §3.3 / SPEC-025).
  Future<void> syncNow(
    StateDatabase db, {
    void Function(String messageKey)? onProgress,
    void Function(String messageKey)? onFailure,
  }) async {
    final status = state;
    if (status is! AuthSignedIn) {
      throw AuthUnavailable('Not signed in');
    }
    onProgress?.call(kSyncProgressMessageKey);
    try {
      final bookIds = {
        ...db.installedBookIds(),
        ...db.listReadingHistory().map((e) => e.bookId),
      };
      final snap = snapshotLocalUserData(db, bookIds: bookIds);
      final ok = await _sync.mergeLocalData(
        uid: status.profile.uid,
        local: snap,
        onProgress: onProgress,
        onFailure: onFailure,
      );
      await _pullReading(status.profile.uid, db);
      if (ok || snap.isEmpty) {
        db.setSyncState(
          lastSyncedAt: DateTime.now().millisecondsSinceEpoch,
          clearError: true,
        );
      } else {
        db.setSyncState(lastError: 'sync_failed');
        onFailure?.call(kSyncFailedMessageKey);
      }
    } catch (_) {
      db.setSyncState(lastError: 'sync_failed');
      onFailure?.call(kSyncFailedMessageKey);
      rethrow;
    }
  }

  Future<List<LibraryDoc>> pullLibrary() async {
    final status = state;
    if (status is! AuthSignedIn) return const [];
    return _sync.fetchLibrary(status.profile.uid);
  }

  Future<void> pushLibrary(List<LibraryDoc> docs) async {
    final status = state;
    if (status is! AuthSignedIn || docs.isEmpty) return;
    await _sync.upsertLibrary(status.profile.uid, docs);
  }

  Future<void> _pullReading(String uid, StateDatabase db) async {
    final history = await _sync.fetchHistory(uid);
    final progress = await _sync.fetchProgress(uid);
    applyPulledReading(db, history: history, progress: progress);
  }
}
