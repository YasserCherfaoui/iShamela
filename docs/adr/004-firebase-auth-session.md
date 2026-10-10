# ADR-004 — Firebase Auth is the session; the API keeps user data

- **Status:** Accepted — supersedes the Auth row of ADR-003 and the auth rows of `revisions-003.md`
- **Date:** 2026-10-08
- **Related:** ADR-002 (optional accounts), ADR-003 (project-owned API), SPEC-022, SPEC-027, SPEC-028

## Context

ADR-003 moved sign-in onto the Railway API: the app sends a Google ID token or an Apple identity token, and the API issues its own access JWT. On the web that handoff fails. `google_sign_in` 6.3's `signIn()` returns an access token and no ID token, so the app throws `AuthUnavailable` before it ever calls `POST /v1/auth/google`. Apple web sign-in depends on a Services ID and return URL that Apple is rejecting.

Firebase Auth is already initialized in the app, and SPEC-022 already specifies Google, Apple, and email OTP through it, including `signInWithPopup` on the web. Firestore and Cloud Functions stay out of user data. That split was the part of ADR-003 worth keeping.

## Decision

| Concern | Choice |
|---|---|
| Sign-in | Firebase Auth. Google and Apple on the web use `signInWithPopup`. Mobile keeps `google_sign_in` and `sign_in_with_apple` as Firebase credentials. Email sign-in is Firebase Auth as in SPEC-022. |
| Client session | The Firebase ID token. The app does not store the project access JWT or refresh token from `POST /v1/auth/*`. |
| API | Unchanged for library, progress, profile, and devices. Those routes accept `Authorization: Bearer <Firebase ID token>`. The API verifies it with Firebase Admin for project `shamelaonline` and maps `uid` to the Postgres user. |
| Dropped from the client | `POST /v1/auth/google`, `POST /v1/auth/apple`, `POST /v1/auth/otp/request`, `POST /v1/auth/otp/verify`, `POST /v1/auth/refresh`. |
| Still out | Firestore. Book content and search stay on device (ADR-001). |

## Consequences

- SPEC-027 §5.1 is not the client sign-in contract anymore. A follow-up spec has to define Firebase ID token verification on the data routes and the `uid` → user mapping before any client or API code changes.
- SPEC-031's web Google ID-token handoff is withdrawn. The GIS credential button is not the fix.
- `firebase_auth` stays. `cloud_firestore` stays unused.
- Web Google and Apple succeed only after the Firebase Auth providers, authorized domains, Google JavaScript origins, and the Apple Services ID are set in those consoles. The API's `GOOGLE_CLIENT_IDS` and `APPLE_CLIENT_IDS` no longer decide whether the button works.

## Alternatives considered

- Keep the API session and switch the web Google button to the GIS credential button (`renderButton`). That yields an ID token without Firebase, and it was the SPEC-031 follow-up. Rejected: sign-in goes back to Firebase Auth.
- Send the Firebase ID token to `POST /v1/auth/google` in exchange for a project JWT. Rejected: that keeps two sessions. The Firebase ID token is the credential the API sees.
