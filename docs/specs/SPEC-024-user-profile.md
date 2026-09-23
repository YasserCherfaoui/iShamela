# SPEC-024 — User Profile Screen (الملف الشخصي)

- **Status:** Implemented
- **Depends on:** SPEC-022 (auth), SPEC-023 (stats DAO reused), SPEC-015 (storage manager link), DESIGN-001 tokens
- **Placement:** avatar button in the Home header (top-left) and Settings → الحساب both push `/profile`.

## 1. Purpose

One place for identity, lifetime reading stats, sync status, and account management — with a useful guest variant that sells sign-in without nagging.

## 2. Guest variant

- Rosette avatar placeholder, «ضيف», copy: «أنت تستخدم التطبيق بدون حساب — بياناتك محفوظة على هذا الجهاز فقط».
- Primary button «تسجيل الدخول أو إنشاء حساب» → AuthWelcomeScreen (SPEC-022 §3.1).
- Lifetime stats section (§3.2) still shown — computed locally; everything account-specific below it is hidden.

## 3. Signed-in layout (top → bottom)

### 3.1 Identity card
- Avatar (provider photo if any, else initial letter on green `#0E3B30` disc, gold ring), display name (editable — pencil → inline sheet, 1–40 chars), email (read-only), provider badges: , G, or ✉️ for email accounts.

### 3.2 Lifetime stats (2×2 tonal grid, reuses `HomeStatsDao` with all-time range)
- كتب بدأتها · صفحات مقروءة · دقائق القراءة · أطول سلسلة أيام. Arabic-Indic digits; each cell tappable → History screen filtered accordingly where a filter exists, else inert.

### 3.3 Sync section («المزامنة»)
- Status row: «آخر مزامنة: قبل ٥ دقائق» / «لم تتم المزامنة بعد» + trailing «مزامنة الآن» button → triggers the SPEC-022 §5 job with the SPEC-020 progress snackbar.
- Toggle: «المزامنة عبر بيانات الهاتف» (default on; off = Wi-Fi only).
- Error state (last attempt failed): amber note line with retry.

### 3.4 Shortcuts
- Plain rows with chevrons: إدارة التخزين (SPEC-015), سجل القراءة, العلامات, ملاحظاتي, الإعدادات. No new destinations.

### 3.5 Account management
- «تغيير كلمة المرور» — email-provider accounts only (hidden for pure Google/Apple accounts): current password + new + confirm in a sheet; success snackbar.
- «تسجيل الخروج» — confirmation dialog stating local data is kept: «سيبقى سجلك وملاحظاتك على هذا الجهاز».
- **«حذف الحساب»** — danger row (red-on-theme), required by App Store 5.1.1(v). Flow:
  1. Sheet explains exactly what is deleted: the cloud account and all synced data; **local data on this device is kept** unless the checkbox «احذف بياناتي من هذا الجهاز أيضًا» is ticked.
  2. Confirm by typing «حذف» (or biometric where available).
  3. Calls the callable Cloud Function `deleteAccount` (Admin SDK deletes the auth user; Firestore subtree `users/{uid}` cascaded in-function with batched recursive delete). Client then signs out, wipes local data only if the checkbox was ticked, shows «تم حذف الحساب». Firebase requires recent login for destructive actions — reauthenticate first (password prompt or provider flow) and surface `requires-recent-login` as that prompt, not an error.
  4. Failure: nothing partial visible to the user; retry snackbar.

## 4. Data & backend

- Profile lives on the `users/{uid}` Firestore doc (`displayName, avatarUrl, createdAt, updatedAt`), created on first verified sign-in by the client (idempotent `set(merge: true)`); security rules restrict the whole `users/{uid}/**` subtree to its owner (SPEC-022 §5/§7.9).
- `sync_state` stored locally: `last_synced_at`, `last_error`, `cellular_allowed`.
- Cloud Function `deleteAccount` (callable, TypeScript): verifies the caller, recursively deletes `users/{uid}`, then deletes the auth user; ships in `firebase/functions/` (ADR-002) with emulator tests.
- «تغيير كلمة المرور» is fully client-side: `reauthenticateWithCredential(currentPassword)` → `updatePassword(new)`.

## 5. Theming & a11y

- Same card/hairline tokens as SPEC-023; danger uses `#B3402E` (Paper/Sepia) and `#E06A55` (Night) — add to the token sheet.
- Delete flow fully reachable with screen readers; the typed confirmation field has an explicit label and error.

## 6. Acceptance criteria

1. Guest variant shows local lifetime stats and a single sign-in CTA; no account rows leak into it.
2. Display-name edit round-trips to `profiles` and appears on Home greeting after pop.
3. «مزامنة الآن» performs a full two-way sync and updates «آخر مزامنة»; airplane mode yields the error state with retry, no crash.
4. Change-password row appears only for email-provider users and rejects a wrong current password.
5. Sign-out keeps local data (verified by reopening as guest with intact history).
6. Delete-account removes the user and the whole `users/{uid}` subtree (verified in the Firebase console/emulator), respects the local-wipe checkbox both ways, and the same email can register a fresh empty account afterwards.
7. Three themes + RTL + accessibility pass.

## 7. Out of scope

Public profiles, avatars upload/cropping (provider photo or initial only for v1), followers/social, achievements. Revisit after sync is stable.