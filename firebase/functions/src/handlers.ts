/**
 * Pure callable handlers (injectable deps for unit tests).
 * Wired to firebase-functions v2 `onCall` in index.ts.
 */

import { FieldValue, Timestamp } from 'firebase-admin/firestore';
import { HttpsError } from 'firebase-functions/v2/https';
import type * as admin from 'firebase-admin';
import {
  filterSendTimestamps,
  generateOtpCode,
  generateResetToken,
  isRateLimited,
  isValidPurpose,
  MAX_VERIFY_ATTEMPTS,
  MIN_PASSWORD_LENGTH,
  normalizeEmail,
  otpDocId,
  OTP_TTL_MS,
  OtpPurpose,
  RESET_TOKEN_TTL_MS,
  resetTokenDocId,
  sha256,
} from './crypto_util';
import type { SendEmailFn } from './email';

export interface AuthDeps {
  getUserByEmail: (email: string) => Promise<admin.auth.UserRecord | null>;
  updateUser: (
    uid: string,
    props: admin.auth.UpdateRequest,
  ) => Promise<admin.auth.UserRecord>;
  revokeRefreshTokens: (uid: string) => Promise<void>;
  deleteUser: (uid: string) => Promise<void>;
}

export interface FirestoreDeps {
  otpDoc: (id: string) => FirebaseFirestore.DocumentReference;
  recursiveDeleteUser: (uid: string) => Promise<void>;
}

export interface HandlerDeps {
  auth: AuthDeps;
  db: FirestoreDeps;
  sendEmail: SendEmailFn;
}

function otpMailSubject(purpose: OtpPurpose): string {
  return purpose === 'verify'
    ? 'رمز التحقق — الشاملة'
    : 'رمز إعادة تعيين كلمة المرور — الشاملة';
}

function otpMailBody(code: string, purpose: OtpPurpose): string {
  const intro =
    purpose === 'verify'
      ? 'رمز التحقق من بريدك في الشاملة:'
      : 'رمز إعادة تعيين كلمة المرور في الشاملة:';
  return `${intro}\n\n${code}\n\nصالح لمدة ١٠ دقائق. إن لم تطلب هذا الرمز فتجاهل الرسالة.`;
}

export interface SendOtpRequest {
  email?: string;
  purpose?: string;
}

/**
 * Generates a 6-digit OTP, stores its SHA-256 hash, emails via Resend.
 * Always returns `{ok: true}` to avoid account enumeration — including
 * unknown emails, rate limits, and send failures.
 */
export async function handleSendOtp(
  data: SendOtpRequest,
  deps: HandlerDeps,
  options?: {
    nowMs?: number;
    generateCode?: () => string;
  },
): Promise<{ ok: true }> {
  const email = typeof data.email === 'string' ? normalizeEmail(data.email) : '';
  const purpose = data.purpose;

  if (!email || !email.includes('@')) {
    return { ok: true };
  }
  if (!isValidPurpose(purpose)) {
    throw new HttpsError('invalid-argument', 'purpose must be verify or reset');
  }

  const docRef = deps.db.otpDoc(otpDocId(email, purpose));
  const nowMs = options?.nowMs ?? Date.now();

  const existing = await docRef.get();
  const priorSends: number[] = existing.exists
    ? ((existing.data()?.sendTimestamps as number[] | undefined) ?? [])
    : [];
  const recentSends = filterSendTimestamps(priorSends, nowMs);

  if (isRateLimited(recentSends, nowMs)) {
    return { ok: true };
  }

  const user = await deps.auth.getUserByEmail(email);
  if (!user) {
    return { ok: true };
  }

  const code = (options?.generateCode ?? generateOtpCode)();
  const hash = sha256(code);
  const sendTimestamps = [...recentSends, nowMs];

  await docRef.set({
    hash,
    purpose,
    attempts: 0,
    sends: sendTimestamps.length,
    sendTimestamps,
    expiresAt: Timestamp.fromMillis(nowMs + OTP_TTL_MS),
    createdAt: FieldValue.serverTimestamp(),
  });

  try {
    await deps.sendEmail({
      to: email,
      subject: otpMailSubject(purpose),
      text: otpMailBody(code, purpose),
      html: `<p>${otpMailBody(code, purpose).replace(/\n/g, '<br>')}</p>`,
    });
  } catch {
    // Do not leak send failures; drop the unused code so the user can retry.
    await docRef.delete().catch(() => undefined);
  }

  return { ok: true };
}

export interface VerifyOtpRequest {
  email?: string;
  code?: string;
  purpose?: string;
}

export interface VerifyOtpResponse {
  ok: true;
  resetToken?: string;
}

export async function handleVerifyOtp(
  data: VerifyOtpRequest,
  deps: HandlerDeps,
  options?: {
    nowMs?: number;
    generateResetToken?: () => string;
  },
): Promise<VerifyOtpResponse> {
  const email = typeof data.email === 'string' ? normalizeEmail(data.email) : '';
  const code = typeof data.code === 'string' ? data.code.trim() : '';
  const purpose = data.purpose;

  if (!email || !code || !isValidPurpose(purpose)) {
    throw new HttpsError('invalid-argument', 'email, code, and purpose are required');
  }

  const docRef = deps.db.otpDoc(otpDocId(email, purpose));
  const snap = await docRef.get();
  const nowMs = options?.nowMs ?? Date.now();

  if (!snap.exists) {
    throw new HttpsError('not-found', 'invalid or expired code');
  }

  const doc = snap.data()!;
  const expiresAt = doc.expiresAt as Timestamp | undefined;
  const attempts = (doc.attempts as number | undefined) ?? 0;
  const storedHash = doc.hash as string | undefined;

  if (!expiresAt || expiresAt.toMillis() < nowMs) {
    await docRef.delete();
    throw new HttpsError('deadline-exceeded', 'code expired');
  }

  if (attempts >= MAX_VERIFY_ATTEMPTS) {
    await docRef.delete();
    throw new HttpsError('resource-exhausted', 'too many attempts');
  }

  if (!storedHash || storedHash !== sha256(code)) {
    const nextAttempts = attempts + 1;
    if (nextAttempts >= MAX_VERIFY_ATTEMPTS) {
      await docRef.delete();
      throw new HttpsError('resource-exhausted', 'too many attempts');
    }
    await docRef.update({ attempts: nextAttempts });
    throw new HttpsError('invalid-argument', 'invalid code');
  }

  await docRef.delete();

  if (purpose === 'verify') {
    const user = await deps.auth.getUserByEmail(email);
    if (!user) {
      throw new HttpsError('not-found', 'user not found');
    }
    await deps.auth.updateUser(user.uid, { emailVerified: true });
    return { ok: true };
  }

  const resetToken = (options?.generateResetToken ?? generateResetToken)();
  await deps.db.otpDoc(resetTokenDocId(email)).set({
    hash: sha256(resetToken),
    purpose: 'resetToken',
    expiresAt: Timestamp.fromMillis(nowMs + RESET_TOKEN_TTL_MS),
    createdAt: FieldValue.serverTimestamp(),
  });

  return { ok: true, resetToken };
}

export interface ResetPasswordRequest {
  email?: string;
  resetToken?: string;
  newPassword?: string;
}

export async function handleResetPassword(
  data: ResetPasswordRequest,
  deps: HandlerDeps,
  options?: { nowMs?: number },
): Promise<{ ok: true }> {
  const email = typeof data.email === 'string' ? normalizeEmail(data.email) : '';
  const resetToken =
    typeof data.resetToken === 'string' ? data.resetToken.trim() : '';
  const newPassword = typeof data.newPassword === 'string' ? data.newPassword : '';
  const nowMs = options?.nowMs ?? Date.now();

  if (!email || !resetToken || !newPassword) {
    throw new HttpsError(
      'invalid-argument',
      'email, resetToken, and newPassword are required',
    );
  }
  if (newPassword.length < MIN_PASSWORD_LENGTH) {
    throw new HttpsError(
      'invalid-argument',
      `password must be at least ${MIN_PASSWORD_LENGTH} characters`,
    );
  }

  const tokenRef = deps.db.otpDoc(resetTokenDocId(email));
  const snap = await tokenRef.get();

  if (!snap.exists) {
    throw new HttpsError('not-found', 'invalid or expired reset token');
  }

  const doc = snap.data()!;
  const expiresAt = doc.expiresAt as Timestamp | undefined;
  const storedHash = doc.hash as string | undefined;

  if (!expiresAt || expiresAt.toMillis() < nowMs) {
    await tokenRef.delete();
    throw new HttpsError('deadline-exceeded', 'reset token expired');
  }

  if (!storedHash || storedHash !== sha256(resetToken)) {
    throw new HttpsError('invalid-argument', 'invalid reset token');
  }

  const user = await deps.auth.getUserByEmail(email);
  if (!user) {
    await tokenRef.delete();
    throw new HttpsError('not-found', 'user not found');
  }

  await deps.auth.updateUser(user.uid, { password: newPassword });
  await deps.auth.revokeRefreshTokens(user.uid);
  await tokenRef.delete();

  return { ok: true };
}

export async function handleDeleteAccount(
  uid: string | undefined,
  deps: HandlerDeps,
): Promise<{ ok: true }> {
  if (!uid) {
    throw new HttpsError('unauthenticated', 'must be signed in');
  }

  await deps.db.recursiveDeleteUser(uid);
  await deps.auth.deleteUser(uid);

  return { ok: true };
}
