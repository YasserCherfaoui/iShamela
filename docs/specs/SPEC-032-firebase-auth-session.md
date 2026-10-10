# SPEC-032 — Firebase Auth session

**Status:** Implemented (client and API). Email OTP is unchanged. Console setup is still required. · **Depends on:** ADR-004, SPEC-022, SPEC-027, SPEC-028 · **Deliverable:** Google and Apple sign-in create a Firebase session, and data routes accept that Firebase ID token

## Problem

`GoogleSignIn.signIn()` on the web returns an access token and no ID token. The app then throws `AuthUnavailable` and never calls the API. Apple’s web popup is a separate console problem. ADR-004 makes Firebase Auth the session and leaves library, progress, profile, and devices on the Railway API.

Firestore stays unused. Email OTP stays on `POST /v1/auth/otp/request` and `POST /v1/auth/otp/verify` (SPEC-027 §5.1). Those screens are unchanged.

## Sign-in

`firebaseReady` must be true. Otherwise `signInGoogle` and `signInApple` throw `AuthUnavailable`.

Web:

- Google: `FirebaseAuth.signInWithPopup(GoogleAuthProvider())`.
- Apple: `FirebaseAuth.signInWithPopup` with `OAuthProvider('apple.com')`.

iOS, Android, and macOS:

- Google: existing `GoogleSignIn.signIn()`, then `FirebaseAuth.signInWithCredential` with `GoogleAuthProvider.credential`. A missing ID token throws `AuthUnavailable`.
- Apple: existing `SignInWithApple.getAppleIDCredential`, then `signInWithCredential` with the Apple OAuth credential. `webAuthenticationOptions` stays null off the web.

The client does not call `POST /v1/auth/google` or `POST /v1/auth/apple`. After Firebase accepts the user, the app calls `GET /v1/me` and runs the same local sign-in replay as a project session, without writing a project access or refresh token.

Sign-out calls `FirebaseAuth.signOut()` and `GoogleSignIn.signOut()`, then the existing local clear.

Restore: when Firebase has a current user, load `GET /v1/me`. Otherwise keep the project refresh-token restore used by email OTP.

## API credential

`Authorization: Bearer <token>`.

- `alg` `HS256` is the project access JWT (email OTP). The guard verifies it as today. `deviceId` stays the `dev` claim.
- `alg` `RS256` is a Firebase ID token. Verify it with Firebase Admin for project id `FIREBASE_PROJECT_ID` (default `shamelaonline`). Check `aud`, `iss`, and `exp` via `verifyIdToken`. No service-account secret is required for verification.

The client sends header `X-Device-Id` with the local device UUID on every Firebase-authenticated request. The guard rejects a missing or non-UUID value. If that device row is missing, insert it for this user (`platform` `unknown`, `appVersion` `0`). If it belongs to another user, `401`.

## uid mapping

No new column. `users.id` stays a UUID. Firebase `uid` is not that id.

From the verified token, take `firebase.sign_in_provider` and `firebase.identities`:

| `sign_in_provider` | `auth_identities.provider` | `subject` |
|---|---|---|
| `google.com` | `google` | first `firebase.identities['google.com']` |
| `apple.com` | `apple` | first `firebase.identities['apple.com']` |
| `password` | `email` | token `email`, trimmed and lowercased |

Any other provider, or a missing subject, is `401`.

Look up `(provider, subject)`. If found, that `user_id` is the account. If not, link by lowercased email when the token has one, else insert a `users` row, then insert the `auth_identities` row. Same link-by-email rule as SPEC-027 §5.1. Do not issue a project access JWT for this path.

## Acceptance criteria

- [x] `signInGoogle` / `signInApple` on web call `signInWithPopup` and do not call `signInWithGoogle` / `signInWithApple` on `AccountSession`.
- [x] A unit test maps `google.com`, `apple.com`, and `password` as in the table, and rejects an unknown provider.
- [x] `flutter analyze` and `flutter test` pass.
- [x] Backend `npm test` passes the new identity test.

## Out of scope

- Replacing email OTP with Firebase email/password or Cloud Functions.
- Removing `POST /v1/auth/google` and `POST /v1/auth/apple` from the API. The client stops calling them.
- Firestore, and the GIS `renderButton` from the withdrawn SPEC-031 plan.
- Console setup (Firebase authorized domains, Google JavaScript origins, Apple Services ID).
