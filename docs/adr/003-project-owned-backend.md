# ADR-003 — Project-owned backend (NestJS + Postgres) replaces Firebase Auth/Firestore

- **Status:** Accepted — supersedes the backend section of ADR-002
- **Date:** 2026-09-28
- **Deciders:** Ladj (PM)
- **Related:** ADR-001 (offline-first), ADR-002 (optional accounts), SPEC-022, SPEC-024, SPEC-025, SPEC-027, SPEC-028

## Context

ADR-002 introduced optional user accounts and cross-device sync on Firebase (Auth + Firestore + Cloud Functions). Two problems surfaced:

1. **Licensing/ethos.** iShamela is an open-source project. Firebase Auth, Firestore and Cloud Functions are proprietary, non-self-hostable services; a contributor cannot run the full stack locally without a Google project, and the project cannot be forked and hosted elsewhere without rewriting the data layer.
2. **Sync latency.** In practice the Firestore-based sync was slow (cold-started Cloud Functions for OTP/deletion, listener set-up, full-collection reads on login). Reading progress was also lost when the app was killed before the write reached Firestore.

Only two accounts exist today, so the cost of switching is close to zero.

## Decision

Replace Firebase Auth, Firestore and Cloud Functions with a **project-owned HTTP API**:

| Concern | Choice |
|---|---|
| API framework | NestJS (TypeScript), REST + JSON |
| Database | PostgreSQL — single source of truth for accounts and user data |
| Auth | Server-side verification of Apple / Google ID tokens; email OTP sent via a transactional mail provider; project-issued access JWT + rotating refresh tokens |
| Sync | Cursor-based delta sync over plain HTTP (no realtime listeners); last-writer-wins per record with tombstones |
| Progress tracking | Dedicated lightweight "progress beacon" endpoint + client outbox (SPEC-028) |
| Hosting | Railway (API service from Dockerfile + managed Postgres). Docker Compose reproduces the same stack locally |
| Content | Unchanged — books stay on HuggingFace, served as SQLite bundles (ADR-001). The backend never serves book content or search |

**Firebase pieces that stay:** Firebase Cloud Messaging (push), Crashlytics, Analytics. They are client-side SDKs with no server dependency and no user data of ours stored server-side. They may be swapped later; out of scope here.

**Explicitly out of scope:** "download my data" export, server-side library-wide search (SPEC-017 stays on-device), realtime multi-device presence.

## Consequences

- ADR-002's product decisions (guest mode first-class, optional sign-in, Apple/Google/email+OTP, in-app account deletion) are **kept**. Only the implementation moves.
- SPEC-022 (auth), SPEC-024 (profile/sync/deletion) and SPEC-025 (bookshelf sync) are revised per `REVISIONS-ADR-003.md`. SPEC-023 (Home tab) is unaffected.
- New specs: SPEC-027 (backend service), SPEC-028 (progress tracking & sync client).
- The two existing Firebase users are migrated by a one-off script (SPEC-027 §10); identities are matched by provider subject ID (Apple/Google) or email.
- The project now owns an operational surface: backups, secrets, mail deliverability, and dependency updates. Railway handles Postgres backups; everything else is documented in SPEC-027 §9.
- Contributors can run `docker compose up` and get a fully working backend with no third-party accounts (OTP emails are captured by Mailpit locally).

## Alternatives considered

- **Self-hosted Supabase.** Open-source and closer to Firestore ergonomically, but a heavy stack (Postgres + GoTrue + PostgREST + Kong + Realtime + Studio) for what is a handful of tables. Hosted Supabase was already rejected in ADR-002.
- **PocketBase.** Single-binary, open-source, attractive for this size. Rejected because the sync and progress logic needs custom server code, and the team is already fluent in NestJS.
- **Keep Firestore, fix latency client-side.** Would fix the crash-loss problem (SPEC-028 is largely client-side) but not the licensing concern.