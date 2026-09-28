# REVISIONS-ADR-003 — Changes to SPEC-022, SPEC-024, SPEC-025

Apply these edits to the existing specs. Product behaviour is unchanged unless stated; only the Firebase implementation sections are replaced. Where a section says "see SPEC-027 / SPEC-028", delete the Firebase text and reference the new spec.

## SPEC-022 — Authentication

| Section | Change |
|---|---|
| Providers | Unchanged: Apple, Google, email + OTP. Guest mode stays first-class. |
| Firebase Auth SDK | **Remove** `firebase_auth`. Keep `sign_in_with_apple` and `google_sign_in` packages; they yield the `identityToken` / `idToken` sent to `POST /auth/apple` and `/auth/google` (SPEC-027 §5.1). |
| Email OTP via Cloud Function | **Replace** with `POST /auth/otp/request` + `/auth/otp/verify`. UI unchanged (email entry → 6-digit code). Error codes map from SPEC-027 `error.code`. |
| Session | Firebase ID-token refresh **replaced** by project JWT + refresh token per SPEC-028 §8. |
| Web | Google/Apple web sign-in return the same tokens; Apple web requires the Service ID `online.ishamela.web` (name TBD) whose return URL is `https://app.ishamela.online`. Add `api.ishamela.online` to Apple's "Domains and Subdomains" for email relay. |
| Account linking | New rule: a provider email matching an existing account links to it (SPEC-027 §5.1). Spec the "Linked sign-in methods" list in Profile as read-only for now. |

## SPEC-024 — Profile, sync, account deletion

| Section | Change |
|---|---|
| Sync engine (Firestore listeners, `cloud_firestore`) | **Replace** entirely with SPEC-028 (outbox + delta pull). Remove `cloud_firestore`, `cloud_functions`. |
| Sync status UI | "Syncing…" spinner **removed**. Show "Last synced: X ago" and, only when the outbox has rows past max attempts, a "Sync issues — retry" row. |
| Account deletion via Cloud Function | **Replace** with `DELETE /me` (SPEC-027 §5.2). The confirmation dialog and local wipe steps stay. |
| Sign-out behaviour | Unchanged ("Keep data on this device?"). Add: clears outbox and cursor (SPEC-028 §7). |
| Progress semantics | **New:** reference SPEC-028 §3 (qualification rule, peek chip). "Continue reading" on the Home tab (SPEC-023) reads `reading_progress`, not the viewport. |
| Firebase Analytics / Crashlytics / FCM | Kept. Note explicitly that they are the only remaining Firebase dependencies. |

## SPEC-025 — Bookshelf sync

| Section | Change |
|---|---|
| Firestore `bookshelf` manifest document | **Replace** with `bookshelf` table rows synced through the generic push/pull (SPEC-027 §4, §5.4). One row per `(user, book)`. |
| Realtime listener triggers auto-download | **Replace:** auto-download is evaluated after each pull (app start/resume/sign-in) by diffing `bookshelf` rows without `removed_everywhere` against locally installed bundles. |
| Remove-on-this-device vs remove-everywhere | Unchanged semantics. "This device" = delete the local bundle only, no sync write. "Everywhere" = set `removed_everywhere = true` (a normal LWW write). Re-adding clears the flag. |
| Content source | Unchanged — HuggingFace. Backend never stores or proxies bundles. |
| Download-progress application | Unchanged (progress applied once the bundle is installed). |

## Cross-cutting

- `CLAUDE.md` / Cursor rules: add the backend directory, "never call Firebase Auth/Firestore", and the local-first rule from SPEC-028 §2.
- `LICENSING.md` / acknowledgements page (SPEC-021): drop Firebase Auth/Firestore mentions; add NestJS, PostgreSQL, Drizzle, Resend (service), Railway (hosting).
- Privacy policy on ishamela.online: update data processor list (Railway, Resend), data location (Railway region chosen — recommend EU West), and retention ("deleted immediately on account deletion; backups purged within 30 days").
- CI (SPEC-007): add the `backend/` test job and a deploy job gated on `main`.