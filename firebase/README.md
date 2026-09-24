# Firebase backend (iShamela)

Cloud Functions + Firestore rules for accounts & sync (ADR-002, SPEC-022 §5, SPEC-024 §4).

Region: **`europe-west1`**.

## Layout

| Path | Role |
|------|------|
| `firebase.json` | Functions, Firestore rules/indexes, emulators |
| `.firebaserc` | Default project id (`ishamela-dev` placeholder) |
| `firestore.rules` | Deny-by-default; `users/{uid}/**` owner-only; `otps/` locked |
| `firestore.indexes.json` | Composite indexes (none required yet) |
| `functions/` | TypeScript callables: `sendOtp`, `verifyOtp`, `resetPassword`, `deleteAccount` |

## Prerequisites

- Node.js 20+
- [Firebase CLI](https://firebase.google.com/docs/cli): `npm i -g firebase-tools`
- A Firebase project on the **Blaze** plan (Functions + outbound email)

```bash
cd firebase/functions
npm install
```

Replace the project id in `.firebaserc` with your real Firebase project (must match
`projectId` in `app/lib/firebase_options.dart`), or run:

```bash
cd firebase
firebase use <projectId>
```

Current app options use **`shamelaonline`**. That project must exist under the same
Google account as `firebase login`, and be on the **Blaze** plan for Functions.

## Emulators

From `firebase/`:

```bash
cd functions && npm run build && cd ..
firebase emulators:start --only auth,firestore,functions
```

- Auth: `localhost:9099`
- Firestore: `localhost:8080`
- Functions: `localhost:5001`
- Emulator UI: `localhost:4000` (default)

Point the Flutter app at the emulators with `useAuthEmulator` / `useFirestoreEmulator` / `useFunctionsEmulator` (see FlutterFire docs). Functions are registered in `europe-west1`.

## Unit tests

No emulator required — handlers are tested with in-memory mocks:

```bash
cd firebase/functions
npm install
npm test
```

Coverage includes: `sendOtp` rate limit (5 / 15 min), `verifyOtp` wrong ×5 invalidation, `resetPassword` happy path, `deleteAccount`.

## Deploy

Predeploy hooks are **omitted** from `firebase.json` — the standalone Firebase CLI
(`curl | bash` / firepit) breaks on macOS with `/bin/sh: --: invalid option` when
running any `predeploy` script. Build first, then deploy:

```bash
cd firebase/functions
npm install
npm run deploy:all
# equivalent:
# npm run build && firebase deploy --only firestore:rules,firestore:indexes,functions
```

Prefer installing the CLI via npm or Homebrew (not the curl installer):

```bash
curl -sL firebase.tools | uninstall=true bash   # remove firepit if present
npm install -g firebase-tools
# or: brew install firebase-cli
firebase --version   # should be npm/brew path, not only /usr/local/bin from firepit
```

Local Node may be newer than 20; Cloud Functions still run on the **Node 20** runtime
(`engines` in `functions/package.json`). The `EBADENGINE` warning during `npm install`
is safe to ignore.

## OTP email (Resend)

OTP delivery calls the **Resend HTTP API** from `sendOtp` — no Firebase Extensions / `mail/` collection.

1. Create an API key at [resend.com](https://resend.com) and verify your sending domain (e.g. `ishamela.online`).
2. Store the secret (once per project):

```bash
firebase functions:secrets:set RESEND_API_KEY
```

3. Optional from-address override (default `الشاملة <noreply@ishamela.online>`):

```bash
firebase functions:config:set  # or set param RESEND_FROM in Google Cloud Console
# Prefer: firebase deploy with .env / params — see defineString('RESEND_FROM')
```

For local emulators, export `RESEND_API_KEY` before starting, or use a fake key and inspect logs.

Then redeploy functions:

```bash
cd firebase/functions && npm run deploy
```

## Callables (summary)

| Callable | Auth | Behavior |
|----------|------|----------|
| `sendOtp({email, purpose})` | optional | Crypto 6-digit → SHA-256 in `otps/{email}_{purpose}`; **Resend email**; **always** `{ok:true}` |
| `verifyOtp({email, code, purpose})` | optional | Hash compare; invalidate after 5 fails; `verify` → `emailVerified`; `reset` → `{resetToken}` |
| `resetPassword({email, resetToken, newPassword})` | optional | Admin password update + `revokeRefreshTokens` |
| `deleteAccount` | required | Recursive delete `users/{uid}`, then Auth user |

Emails are normalized with `toLowerCase().trim()` before use as doc ids / lookups.
