import * as crypto from 'crypto';

export type OtpPurpose = 'verify' | 'reset';

export const OTP_TTL_MS = 10 * 60 * 1000; // 10 minutes
export const RESET_TOKEN_TTL_MS = 5 * 60 * 1000; // 5 minutes
export const RATE_LIMIT_WINDOW_MS = 15 * 60 * 1000; // 15 minutes
export const MAX_SENDS_PER_WINDOW = 5;
export const MAX_VERIFY_ATTEMPTS = 5;
export const MIN_PASSWORD_LENGTH = 8;

export function normalizeEmail(email: string): string {
  return email.toLowerCase().trim();
}

export function otpDocId(email: string, purpose: OtpPurpose): string {
  return `${normalizeEmail(email)}_${purpose}`;
}

export function resetTokenDocId(email: string): string {
  return `${normalizeEmail(email)}_resetToken`;
}

export function sha256(value: string): string {
  return crypto.createHash('sha256').update(value, 'utf8').digest('hex');
}

/** Crypto-random 6-digit code as a zero-padded string (000000–999999). */
export function generateOtpCode(): string {
  const n = crypto.randomInt(0, 1_000_000);
  return n.toString().padStart(6, '0');
}

/** Opaque single-use reset token (hex). */
export function generateResetToken(): string {
  return crypto.randomBytes(32).toString('hex');
}

export function isValidPurpose(value: unknown): value is OtpPurpose {
  return value === 'verify' || value === 'reset';
}

/**
 * Count sends still inside the rolling 15-minute window and return the
 * timestamps to keep when recording a new send.
 */
export function filterSendTimestamps(
  timestamps: number[],
  nowMs: number,
  windowMs: number = RATE_LIMIT_WINDOW_MS,
): number[] {
  return timestamps.filter((t) => nowMs - t < windowMs);
}

export function isRateLimited(
  sendTimestamps: number[],
  nowMs: number,
): boolean {
  return (
    filterSendTimestamps(sendTimestamps, nowMs).length >= MAX_SENDS_PER_WINDOW
  );
}
