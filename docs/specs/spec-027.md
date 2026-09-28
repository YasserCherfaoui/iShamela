# SPEC-027 — iShamela Backend Service (NestJS + PostgreSQL)

- **Status:** Draft
- **Implements:** ADR-003
- **Repo:** new directory `backend/` in the iShamela monorepo (or a separate `ishamela-backend` repo — PM decides; this spec assumes `backend/`)
- **Depends on:** SPEC-028 (client protocol), REVISIONS-ADR-003

## 1. Scope

A single NestJS service exposing a versioned REST API for:

1. Authentication (Apple, Google, email OTP), token refresh, logout.
2. Account profile and in-app account deletion.
3. Device registration.
4. Delta sync of user data: reading progress, reading history, bookmarks, notes, bookshelf manifest.
5. A low-latency progress beacon endpoint.

Non-goals: serving book content, search, analytics ingestion, admin UI, data export.

## 2. Stack and repository layout

- Node 22 LTS, NestJS 11, TypeScript strict.
- PostgreSQL 16. ORM: **Drizzle** (schema as code, SQL-transparent, small). Prisma is acceptable if the team prefers; do not mix.
- Validation: `zod` via `nestjs-zod` (or `class-validator`; pick one).
- Auth libs: `jose` (JWT sign/verify, Apple JWKS), `google-auth-library` (Google ID tokens), `apple-signin-auth` (Apple token revocation on delete).
- Mail: `resend` SDK (production), Mailpit (local). Abstract behind a `MailService` interface.
- Rate limiting: `@nestjs/throttler` backed by in-memory store (single instance) — Redis not required at this scale.
- Logging: `pino` via `nestjs-pino`, JSON to stdout.
- Tests: Jest unit + e2e with Testcontainers Postgres.

```
backend/
  Dockerfile
  docker-compose.yml          # local dev: api + postgres + mailpit
  railway.json                # Railway build/deploy config
  .env.example
  src/
    main.ts
    app.module.ts
    config/                   # zod-validated env
    db/                       # drizzle schema, migrations, client
    auth/                     # controllers, apple/google/otp strategies, tokens
    users/                    # me, deletion
    devices/
    sync/                     # push/pull, conflict resolution
    progress/                 # beacon endpoint
    mail/
    common/                   # guards, interceptors, errors
  scripts/
    migrate-firebase.ts       # one-off, §10
  test/
```

## 3. Environment

| Var | Purpose |
|---|---|
| `DATABASE_URL` | Postgres (Railway injects) |
| `JWT_ACCESS_SECRET` / `JWT_REFRESH_SECRET` | 256-bit random, distinct |
| `ACCESS_TOKEN_TTL` | default `15m` |
| `REFRESH_TOKEN_TTL` | default `60d` |
| `APPLE_CLIENT_IDS` | comma-separated: iOS bundle ID + web Service ID |
| `APPLE_TEAM_ID`, `APPLE_KEY_ID`, `APPLE_PRIVATE_KEY` | for token revocation on account deletion |
| `GOOGLE_CLIENT_IDS` | comma-separated: iOS, Android, web client IDs |
| `RESEND_API_KEY`, `MAIL_FROM` | `iShamela <no-reply@ishamela.online>` |
| `OTP_TTL_SECONDS` | default `600` |
| `CORS_ORIGINS` | `https://app.ishamela.online,https://ishamela.online` |
| `PUBLIC_BASE_URL` | e.g. `https://api.ishamela.online` |

Config module fails fast on missing/invalid vars.

## 4. Data model (Postgres)

All timestamps `timestamptz`. All user-data tables carry the **sync envelope**:

```
updated_at   timestamptz  -- client-authored logical time (see §7)
deleted_at   timestamptz  null  -- tombstone
server_seq   bigint       -- assigned by the server on every write, global sequence
device_id    uuid         -- last writer
```

`server_seq` comes from a single sequence `sync_seq`. A trigger sets it on INSERT/UPDATE of every synced table.

```sql
users (
  id uuid pk, email citext unique null, display_name text null,
  created_at, deleted_at null
)
auth_identities (
  id uuid pk, user_id fk, provider text check in ('apple','google','email'),
  subject text,               -- Apple/Google `sub`, or the email for 'email'
  email_at_link citext null,  -- Apple may hide email; keep what we got
  created_at,
  unique(provider, subject)
)
otp_codes (
  id uuid pk, email citext, code_hash text, expires_at, attempts int default 0,
  consumed_at null, created_at
)
refresh_tokens (
  id uuid pk, user_id fk, device_id fk, token_hash text unique,
  family_id uuid,             -- rotation family; reuse detection revokes family
  expires_at, revoked_at null, created_at
)
devices (
  id uuid pk, user_id fk, platform text, app_version text, model text null,
  push_token text null, last_seen_at, created_at
)

-- synced user data --
reading_progress (
  user_id fk, book_id text, page int, volume int null, scroll_offset real null,
  progress_at timestamptz,    -- when the position QUALIFIED (SPEC-028 §3)
  <envelope>, primary key (user_id, book_id)
)
reading_history_events (
  id uuid pk, user_id fk, book_id text, page int, opened_at timestamptz,
  duration_s int, <envelope>
)
bookmarks (
  id uuid pk, user_id fk, book_id text, page int, label text null, <envelope>
)
notes (
  id uuid pk, user_id fk, book_id text, page int, body text, <envelope>
)
bookshelf (
  user_id fk, book_id text, added_at timestamptz,
  removed_everywhere boolean default false,   -- SPEC-025 semantics
  <envelope>, primary key (user_id, book_id)
)
```

Indexes: `(user_id, server_seq)` on every synced table (the pull query), `(user_id, book_id)` where not already PK.

`book_id` is the catalog ID from SPEC-003; the backend stores it opaquely.

## 5. API

Base path `/v1`. JSON only. Errors follow `{ "error": { "code": "OTP_EXPIRED", "message": "..." } }` with stable `code` strings the Flutter app maps to localized text.

### 5.1 Auth

| Method | Path | Body → Response |
|---|---|---|
| POST | `/auth/apple` | `{ identityToken, device }` → `AuthResult` |
| POST | `/auth/google` | `{ idToken, device }` → `AuthResult` |
| POST | `/auth/otp/request` | `{ email }` → `204` (always, even for unknown emails) |
| POST | `/auth/otp/verify` | `{ email, code, device }` → `AuthResult` |
| POST | `/auth/refresh` | `{ refreshToken }` → `{ accessToken, refreshToken }` |
| POST | `/auth/logout` | `{ refreshToken }` → `204` (revokes that token's family) |

`device = { id?: uuid, platform, appVersion, model? }` — if `id` is absent the server creates the device and returns it.

`AuthResult = { accessToken, refreshToken, user: { id, email, displayName }, device: { id }, isNewUser }`

Rules:
- Apple/Google tokens verified against provider JWKS; `aud` must be in the configured client-ID list; `iss` and `exp` checked. On first sight, create `users` + `auth_identities`. If the provider email matches an existing user's verified email, **link** to that user rather than creating a duplicate.
- OTP: 6 digits, stored as bcrypt hash, 10-minute TTL, max 5 attempts, one active code per email (new request invalidates prior). Throttle: 3 requests / email / 15 min and 20 / IP / hour.
- Access JWT: HS256, 15 min, claims `{ sub: userId, dev: deviceId }`. Refresh: opaque 256-bit random, stored hashed, rotated on every use; presenting an already-rotated token revokes the whole family (theft detection).

### 5.2 Account

| Method | Path | Notes |
|---|---|---|
| GET | `/me` | profile + list of devices |
| PATCH | `/me` | `{ displayName }` |
| DELETE | `/me` | Hard-deletes all rows for the user in one transaction; revokes Apple token via Apple's `/auth/revoke` when an Apple identity exists; returns `204`. Client wipes local synced data per SPEC-024. |

### 5.3 Devices

| Method | Path | Notes |
|---|---|---|
| POST | `/devices/register` | upsert push token / app version; called on launch when signed in |

### 5.4 Sync (SPEC-028 is the client contract)

**Pull**

```
GET /sync/pull?since=<server_seq>&limit=500
→ {
  changes: [ { table, record } ... ],   // records include their envelope
  nextCursor: <server_seq>,
  hasMore: boolean
}
```
Returns rows with `server_seq > since` for this user across all synced tables, ordered by `server_seq`. Tombstones are returned as records with `deleted_at` set. `since=0` on a fresh device returns everything (paged).

**Push**

```
POST /sync/push
{ changes: [ { table, record } ... ] }    // max 500
→ { applied: [ { table, key, server_seq } ], rejected: [ { table, key, reason } ], serverTime }
```

Conflict rule (per record): incoming `updated_at` (or `progress_at` for `reading_progress`) **> stored** → apply; **<** → reject with reason `STALE` (client will receive the winner on next pull); equal → apply if `device_id` differs? No — equal is treated as duplicate, `applied` returned with existing `server_seq`. Deletes are writes with `deleted_at`. Server clamps any client timestamp more than 5 minutes in the future to `serverTime` (bad device clocks).

Push and pull are both idempotent; the client may retry freely.

### 5.5 Progress beacon

```
POST /progress
{ bookId, page, volume?, scrollOffset?, progressAt, deviceId }
→ 204
```
Single-purpose, no body validation beyond types, no joins: `INSERT ... ON CONFLICT (user_id, book_id) DO UPDATE ... WHERE excluded.progress_at > reading_progress.progress_at`. Target p95 < 50 ms server-side. Also accepts an array of up to 50 items (outbox drain). This endpoint exists so the client can fire a tiny request on app-pause without going through the full sync cycle.

### 5.6 Health

`GET /health` → `{ status: "ok", db: "ok" }` (used by Railway).

## 6. Security

- All routes except `/auth/*` and `/health` require `Authorization: Bearer <access>`.
- Helmet defaults, CORS restricted to `CORS_ORIGINS`, body limit 1 MB.
- No PII in logs (email masked). OTP codes never logged.
- Throttler defaults: 60 req/min per user on sync, 600/min on `/progress`.

## 7. Time and conflict semantics (shared with SPEC-028)

- `updated_at` is authored by the **client** at the moment of the edit (device wall clock). It is the conflict key. Server never rewrites it except the +5 min clamp.
- `server_seq` is the **pull cursor** only; it is not used for conflict resolution.
- `reading_progress` uses `progress_at` (qualification time) instead of `updated_at` as the conflict key — this is what prevents a quick "open at page 300 to check a reference" on the phone from overwriting real progress at page 42 on the tablet (SPEC-028 §3 defines qualification; the server just compares timestamps).
- Last-writer-wins is intentional. No merges.

## 8. Local development

`docker-compose.yml`:

```yaml
services:
  api:
    build: .
    ports: ["3000:3000"]
    env_file: .env
    depends_on: [db, mail]
    command: npm run start:dev
    volumes: [".:/app", "/app/node_modules"]
  db:
    image: postgres:16-alpine
    environment: { POSTGRES_USER: ishamela, POSTGRES_PASSWORD: ishamela, POSTGRES_DB: ishamela }
    ports: ["5432:5432"]
    volumes: ["pgdata:/var/lib/postgresql/data"]
  mail:
    image: axllent/mailpit
    ports: ["8025:8025", "1025:1025"]   # web UI, SMTP
volumes: { pgdata: {} }
```

`MailService` uses SMTP → Mailpit when `NODE_ENV=development`, Resend otherwise. Apple/Google sign-in can be exercised locally with real tokens from a dev build; email OTP works fully offline.

## 9. Deployment on Railway

- Railway does not run Compose. Create two services in one project: **api** (deploy from repo, root `backend/`, uses `Dockerfile`) and **Postgres** (Railway plugin). Railway injects `DATABASE_URL`.
- `railway.json`: `{"build":{"builder":"DOCKERFILE"},"deploy":{"healthcheckPath":"/health","restartPolicyType":"ON_FAILURE"}}`.
- Dockerfile: multi-stage, `node:22-alpine`, `npm ci --omit=dev`, `CMD ["node","dist/main.js"]`. Migrations run on container start via `drizzle-kit migrate` before `main.js` (single instance, so no race).
- Custom domain `api.ishamela.online` → Railway. Add to `CORS_ORIGINS` and to Apple's Service ID return URLs where relevant.
- Backups: Railway Postgres daily snapshots; additionally a weekly `pg_dump` GitHub Action to a private bucket (nice-to-have, M2).
- Secrets live in Railway variables only; `.env` never committed.
- Deploy on push to `main` under `backend/**`; PR previews off (cost).

## 10. Migration of the two existing Firebase users

One-off `scripts/migrate-firebase.ts`, run locally by a maintainer with a Firebase service-account key:

1. Export from Firebase Auth: uid, email, provider data (`sub` per provider).
2. Export Firestore collections defined in the Firebase-era SPEC-024/025 (progress, history, bookmarks, notes, bookshelf).
3. Insert `users` + `auth_identities` (provider subjects preserved so next login links transparently), then user data with `updated_at` = Firestore `updatedAt` (or export time if absent), `device_id` = a synthetic "migration" device.
4. Print a summary; run twice must be idempotent (upsert on identity).
5. After the app release that points at the new API, disable Firebase Auth providers and delete the Firestore database.

Given two users, a manual re-login without step 2/3 is an acceptable fallback if the export is more trouble than it is worth — PM's call at execution time.

## 11. Acceptance criteria

- `docker compose up` yields a working API; OTP flow completes end-to-end using Mailpit.
- Sign in with Apple and Google succeed from iOS, Android, and web builds against the deployed API.
- Fresh device with `since=0` receives the complete dataset; subsequent pulls return only deltas.
- Concurrent edits from two devices resolve deterministically by `updated_at`/`progress_at`; no duplicates.
- `POST /progress` p95 < 50 ms measured server-side under 100 rps.
- `DELETE /me` removes every row for the user and revokes Apple credentials; a subsequent Apple sign-in creates a fresh account.
- Refresh-token reuse revokes the family and forces re-login.
- e2e tests cover every endpoint; CI runs them on PR.

## 12. Milestones

- **M-B1:** repo scaffold, Compose, schema + migrations, `/health`, CI.
- **M-B2:** auth (all three providers), refresh/logout, `/me`, deletion.
- **M-B3:** sync push/pull, progress beacon, throttling.
- **M-B4:** Railway deployment, domain, mail domain verification (SPF/DKIM for `ishamela.online`), migration script, Firebase decommission.