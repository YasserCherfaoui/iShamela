# REVISIONS-ADR-003 — Changes to SPEC-022, SPEC-024, SPEC-025

Auth rows below that say "Superseded by ADR-004" are withdrawn. Firestore stays off the client. The API still owns sync and profile data.

Apply these edits to the existing specs. Product behaviour is unchanged unless stated; only the Firebase implementation sections are replaced. Where a section says "see SPEC-027 / SPEC-028", delete the Firebase text and reference the new spec.

## SPEC-022 — Authentication

| Section | Change |
|---|---|
| Providers | Unchanged: Apple, Google, email + OTP. Guest mode stays first-class. |
| Firebase Auth SDK | Superseded by ADR-004. Keep `firebase_auth`. Google and Apple sign in through Firebase. Do not post provider tokens to `POST /auth/google` or `POST /auth/apple`. |
| Email OTP via Cloud Function | Superseded by ADR-004. Email sign-in is Firebase Auth again, as in SPEC-022. |
| Session | Superseded by ADR-004. The client session is the Firebase ID token. The API accepts that token on data routes. |
| Web | Superseded by ADR-004. Web Google and Apple use Firebase Auth (`signInWithPopup`), as in SPEC-022. |
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

- `CLAUDE.md` / Cursor rules: add the backend directory, "never call Firestore", and the local-first rule from SPEC-028 §2. Firebase Auth is allowed again (ADR-004).
- `LICENSING.md` / acknowledgements page (SPEC-021): drop Firebase Auth/Firestore mentions; add NestJS, PostgreSQL, Drizzle, Resend (service), Railway (hosting).
- Privacy policy on ishamela.online: update data processor list (Railway, Resend), data location (Railway region chosen — recommend EU West), and retention ("deleted immediately on account deletion; backups purged within 30 days").
- CI (SPEC-007): add the `backend/` test job and a deploy job gated on `main`.