# ADR-002 — User Accounts & Sync Backend

- **Status:** Accepted (backend: Firebase, per PM decision)
- **Date:** 2026-09-23
- **Owner:** Ladj (PM)
- **Relates to:** ADR-001 (offline-first, no backend), SPEC-014 (history/bookmarks), SPEC-022/023/024

## Context

ADR-001 established iShamela as an offline-first Flutter app with no backend: content ships as SQLite FTS5 bundles from HuggingFace, and all user data (history, bookmarks, notes, progress) lives in local SQLite.

New product requirements introduce identity and cross-device state:

1. A **Home screen** showing reading progress, streaks, and history.
2. A **User profile** screen.
3. **Authentication** with Google and Apple sign-in, plus email/password with reset and OTP flows.

Home and Profile can be built on local data alone, but accounts only earn their complexity if they **sync user data across devices** (phone ⇄ tablet ⇄ web at app.ishamela.online). Content itself never needs a backend — it stays on HuggingFace per ADR-001.

## Decision

Adopt **Firebase** as the accounts + user-data backend, with authentication strictly **optional**:

1. **Offline-first is preserved.** Every feature except sync works signed-out. The app never blocks on auth; «متابعة بدون حساب» (continue as guest) is always available. Local SQLite remains the source of truth on-device; the cloud is a replica for sync.
2. **Firebase Authentication** provides Sign in with Apple, Google sign-in, and email + password, with first-class Flutter support (FlutterFire) and the same SDK on web. Native email verification and password reset are **link-based**; since the product requires **6-digit OTP screens**, verification and reset codes are implemented with a small **Cloud Functions** pair (`sendOtp` / `verifyOtp`, see SPEC-022 §5) — a well-trodden pattern.
3. **Cloud Firestore** stores only *user* data under `users/{uid}` (profile doc + `history`, `bookmarks`, `notes`, `progress` subcollections). Security rules: `request.auth.uid == uid` on the whole subtree. Row volume per user is tiny (KBs).
4. **Sync model:** per-document last-write-wins on an `updatedAt` field, pushed opportunistically (app foreground/background, after a reading session ends, manual "sync now"). First sign-in on a device **merges local guest data up** — never wipes it. Firestore's built-in offline cache is a bonus, not the mechanism: SQLite stays canonical.
5. **Web app** (app.ishamela.online) uses the same Firebase project via the JS SDK.

## Alternatives considered

- **Supabase.** Postgres + RLS fits the relational user data well, open source with a self-hosting exit, and ships email OTP natively (would have avoided the custom Functions). Set aside on PM preference for Firebase and team familiarity; the client architecture (optional auth, LWW sync, local-first) is backend-agnostic, so a later migration remains feasible.
- **PocketBase / self-hosted.** Ops burden now; deferred.
- **No backend — iCloud/Drive file sync.** Platform-inconsistent, no web story, painful conflicts. Rejected.

## Consequences

- **Billing plan:** Cloud Functions and outbound email require the **Blaze** (pay-as-you-go) plan. At current scale this rounds to ~$0; set a budget alert anyway. OTP emails go out via the **Trigger Email** Firebase extension (SMTP — e.g. Resend/Brevo free tier).
- **App Store compliance:** offering Google sign-in on iOS **requires** Sign in with Apple (guideline 4.8) — included. In-app **account deletion** is mandatory (guideline 5.1.1(v)) — a callable `deleteAccount` Function (SPEC-024 §4).
- **Privacy:** update the ishamela.online policy (SPEC-021) for accounts, stored user data, and deletion; App Store privacy labels gain "Identifiers" and "Usage Data (reading activity)". Disable Firebase Analytics collection unless explicitly wanted.
- **New repo surface:** `firebase/` folder — `firestore.rules`, `firestore.indexes.json`, `functions/` (TypeScript: `sendOtp`, `verifyOtp`, `deleteAccount`), `firebase.json`; config via `flutterfire configure` (the generated `firebase_options.dart` is safe to commit; API keys are not secrets, rules are the security boundary).
- **Lock-in acknowledged:** Firestore's model and Auth are proprietary; mitigated by keeping SQLite canonical and the sync layer thin.