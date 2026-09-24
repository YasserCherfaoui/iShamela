# SPEC-022 — Accounts & Authentication

- **Status:** Draft
- **Depends on:** ADR-002 (Firebase), SPEC-004 (app foundation), DESIGN-001 (Warm Manuscript tokens)
- **Feeds:** SPEC-023 (Home), SPEC-024 (Profile)
- **Packages:** `firebase_core`, `firebase_auth`, `cloud_firestore`, `cloud_functions`, `google_sign_in`, `sign_in_with_apple`, `pin_code_fields` (or hand-rolled OTP boxes)

## 1. Goals / Non-goals

**Goals**
- Optional sign-in with **Apple**, **Google**, or **email + password**; full guest mode preserved.
- Email verification and password reset via **6-digit email OTP** (custom Cloud Functions — Firebase's native flows are link-based, §5).
- Session persistence, refresh, sign-out; local guest data merged into the account on first sign-in.

**Non-goals**
- Phone/SMS auth, magic links, MFA, username handles — out of scope.
- Paid features / entitlements — no monetization gating anywhere.

## 2. Entry points

- First launch after onboarding: app opens **signed-out into the normal tabs** (no auth wall). Auth is reached from: Profile tab (guest state CTA), Home "sync" banner, Settings → الحساب.
- OAuth is native on mobile (`google_sign_in`, `sign_in_with_apple` → `firebase_auth` credential sign-in — no browser redirect to configure) and `signInWithPopup` on web. Apple provider must be enabled in Firebase console + Apple Developer (Services ID for web).
- No email links anywhere, so no dynamic-link/app-link setup is needed: OTP codes are typed into the app.

## 3. Screens

All screens are RTL, themed like the rest of the app (Paper `#F8F3E6` / Sepia `#F1E5CC` / Night `#101B17`), Amiri for display text, IBM Plex Sans Arabic for UI. Rosette divider and gold `#C6A15B` accents per DESIGN-001. Every auth screen has a top-left close/back and never traps the user.

### 3.1 AuthWelcomeScreen (`/auth`)
- Brand lockup (icon + الشاملة), one line of value copy: «سجّل الدخول لمزامنة قراءاتك وملاحظاتك عبر أجهزتك».
- Buttons, in order:
  1. **متابعة عبر Apple** — black (Night: white) per Apple HIG. iOS/macOS/web only; hidden on Android.
  2. **متابعة عبر Google** — neutral surface + Google G asset.
  3. **البريد الإلكتروني** — pushes SignInScreen.
- Footer: «متابعة بدون حساب» (dismisses), links to privacy/terms on ishamela.online.
- Apple button must appear **above** Google (guideline 4.8 parity: equal prominence, we give it first slot).

### 3.2 SignInScreen (`/auth/sign-in`)
- Fields: البريد الإلكتروني (email keyboard, LTR input inside RTL layout), كلمة المرور (obscured, reveal toggle).
- Primary button تسجيل الدخول (`signInWithEmailAndPassword`); links: «نسيت كلمة المرور؟» → 3.4, «إنشاء حساب» → 3.3.
- Inline errors under fields (invalid email format, empty). Auth errors as themed snackbar (SPEC-020 style): `wrong-password` / `user-not-found` / `invalid-credential` all map to «البريد أو كلمة المرور غير صحيحة» (never reveal which).
- Signed in but `emailVerified == false` → route to OTPScreen in `verify` mode with the email prefilled (a fresh code is sent automatically).

### 3.3 SignUpScreen (`/auth/sign-up`)
- Fields: الاسم (display name → `updateDisplayName`), البريد الإلكتروني, كلمة المرور (min 8 chars; strength hint line), تأكيد كلمة المرور.
- Checkbox row linking سياسة الخصوصية / الشروط (must be checked).
- Submit → `createUserWithEmailAndPassword` → call `sendOtp(purpose: 'verify')` → OTPScreen (`verify` mode). The session exists but the app treats the account as unverified (sync disabled) until OTP passes.

### 3.4 ForgotPasswordScreen (`/auth/forgot`)
- Single email field + copy: «سنرسل رمزًا مكوَّنًا من ٦ أرقام إلى بريدك».
- Submit → `sendOtp(purpose: 'reset')` → OTPScreen (`reset` mode). Always show success («إن كان البريد مسجلًا لدينا فسيصلك الرمز») — the function returns OK even for unknown emails; no account enumeration.

### 3.5 OTPScreen (`/auth/otp?mode=verify|reset`)
- Six digit boxes, LTR order, auto-advance, paste support, numeric keyboard; Western digits accepted, rendered as typed.
- Countdown «إعادة الإرسال بعد ٠:٥٩» → resend link when elapsed (server enforces max 5 sends / 15 min; client mirrors with the cooldown message).
- Submit → `verifyOtp(email, code, purpose)`.
  - `verify` success → server marks `emailVerified: true` → client `currentUser.reload()` → MergeLocalData job (§6) → pop to origin with welcome snackbar.
  - `reset` success → server returns a one-shot `resetToken` → ResetPasswordScreen.
- Wrong code: shake animation + «الرمز غير صحيح»; expired (10 min TTL): prompt resend. 5 failed attempts invalidate the code → force resend.

### 3.6 ResetPasswordScreen (`/auth/reset`)
- New password + confirm (same rules as sign-up). Submit → `verifyOtp`'s `resetToken` + new password to `resetPassword` callable (Admin SDK `updateUser`), then `signInWithEmailAndPassword` with the new password. Success snackbar «تم تغيير كلمة المرور», route Home.

## 4. Session handling

- `firebase_auth` persists and auto-refreshes the session natively (Keychain/Keystore internally; IndexedDB on web) — no extra storage layer.
- Auth state exposed as a single `AuthController` (Riverpod/Bloc per app foundation) listening to `authStateChanges()`, with states: `guest`, `signedInUnverified`, `signedIn(profile)`.
- Token revocation/disabled account surfaces on next call → drop to `guest`, keep all local data, non-blocking snackbar «انتهت الجلسة، سجّل الدخول من جديد للمزامنة».
- Sign out (from Profile): `signOut()` (+ `GoogleSignIn.signOut()`), **keeps local data**, stops sync.

## 5. OTP backend (Cloud Functions, TypeScript, region `europe-west1`)

- `sendOtp({email, purpose})` — callable. Generates a crypto-random 6-digit code, stores SHA-256 hash in `otps/{email}_{purpose}` (`hash, purpose, attempts: 0, sends, expiresAt: now+10min`), emails it via the **Trigger Email** extension (writes to `mail/` collection; SMTP: Resend/Brevo). Rate limits: 5 sends / 15 min per email+purpose, generic OK response regardless of account existence.
- `verifyOtp({email, code, purpose})` — callable. Compares hash, increments `attempts` (invalidate at 5), deletes doc on success. `verify` → Admin `updateUser(uid, {emailVerified: true})`; `reset` → returns single-use `resetToken` (random, hashed, 5 min TTL, stored alongside).
- `resetPassword({email, resetToken, newPassword})` — callable. Validates token, Admin `updateUser(uid, {password})`, revokes refresh tokens.
- `otps/` and `mail/` are locked to no client access in `firestore.rules`. Unit-test the three functions with the Firebase emulator suite.

## 6. Guest-data merge (first verified sign-in on a device)

1. Snapshot local rows (progress, history, bookmarks, notes) with `updatedAt`, plus the locally installed book list.
2. Pull the user's Firestore subtree; upsert both ways with per-document last-write-wins on `updatedAt` (batched writes, ≤500/batch). Installed books are unioned into `users/{uid}/library/` (SPEC-025 §2/§4).
3. Hand off to the SPEC-025 auto-download orchestrator, which enqueues any account books missing on this device (network/storage policy and first-setup sheet per SPEC-025 §3).
4. Runs in background with the SPEC-020 progress snackbar («جارٍ مزامنة بياناتك…»); failure retries on next sync tick — never blocks reading.

## 7. Acceptance criteria

1. App is fully usable without an account; no auth wall exists on any reading path.
2. Apple sign-in works on iOS/macOS/web and is hidden on Android; Google works on all platforms; both resolve to the same Firebase user on repeat sign-ins.
3. Email sign-up remains `signedInUnverified` (no sync) until the OTP passes; verified state survives app restart.
4. Forgot-password: OTP → new password → signed in; old password rejected and old sessions revoked.
5. Wrong OTP ×5 invalidates the code; resend rate-limited server-side with visible client countdown; codes expire at 10 min.
6. Signing in on a device with guest history merges it (union, LWW) — verified by a device-A/device-B test script against the emulator.
7. Sign-out keeps local data and returns Profile/Home to guest state.
8. All screens render correctly in the three themes, RTL, and pass a VoiceOver/TalkBack pass (labels on every field/button).
9. `firestore.rules` deny-by-default verified by emulator rule tests; only `users/{uid}/**` readable/writable by its owner; `otps/`, `mail/` client-inaccessible.

## 8. Open questions

- Account linking (same email via Google *and* Apple): enable "one account per email address" in Firebase Auth settings; document the `account-exists-with-different-credential` linking flow for the edge case.
- Web (app.ishamela.online) mirrors these flows with the same routes and callables — same spec applies; confirm shared copy strings live in one ARB file.