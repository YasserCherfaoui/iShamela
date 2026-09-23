import { HttpsError } from 'firebase-functions/v2/https';
import {
  MAX_SENDS_PER_WINDOW,
  MAX_VERIFY_ATTEMPTS,
  otpDocId,
  RATE_LIMIT_WINDOW_MS,
  resetTokenDocId,
  sha256,
} from '../crypto_util';
import {
  handleDeleteAccount,
  handleResetPassword,
  handleSendOtp,
  handleVerifyOtp,
} from '../handlers';
import { createFakeAuth, createFakeFirestore, Timestamp } from './fake_deps';

const EMAIL = 'user@example.com';
const UID = 'uid-test-1';

describe('sendOtp', () => {
  test('stores hashed code and queues mail for an existing user', async () => {
    const fs = createFakeFirestore();
    const auth = createFakeAuth({
      users: { [EMAIL]: { uid: UID, email: EMAIL } },
    });
    const now = 1_700_000_000_000;

    const result = await handleSendOtp(
      { email: '  User@Example.com ', purpose: 'verify' },
      { auth: auth.deps, db: fs.deps },
      { nowMs: now, generateCode: () => '123456' },
    );

    expect(result).toEqual({ ok: true });
    const doc = fs.otps.get(otpDocId(EMAIL, 'verify'));
    expect(doc).toBeDefined();
    expect(doc!.hash).toBe(sha256('123456'));
    expect(doc!.attempts).toBe(0);
    expect(doc!.sends).toBe(1);
    expect(doc!.purpose).toBe('verify');
    expect(fs.mail).toHaveLength(1);
    expect(fs.mail[0].to).toEqual([EMAIL]);
  });

  test('always returns ok for unknown emails (no enumeration)', async () => {
    const fs = createFakeFirestore();
    const auth = createFakeAuth({ users: {} });

    const result = await handleSendOtp(
      { email: 'ghost@example.com', purpose: 'reset' },
      { auth: auth.deps, db: fs.deps },
    );

    expect(result).toEqual({ ok: true });
    expect(fs.otps.size).toBe(0);
    expect(fs.mail).toHaveLength(0);
  });

  test('rate-limits to 5 sends per 15 minutes', async () => {
    const fs = createFakeFirestore();
    const auth = createFakeAuth({
      users: { [EMAIL]: { uid: UID, email: EMAIL } },
    });
    const base = 1_700_000_000_000;

    for (let i = 0; i < MAX_SENDS_PER_WINDOW; i++) {
      await handleSendOtp(
        { email: EMAIL, purpose: 'reset' },
        { auth: auth.deps, db: fs.deps },
        {
          nowMs: base + i * 1000,
          generateCode: () => `10000${i}`,
        },
      );
    }

    expect(fs.mail).toHaveLength(MAX_SENDS_PER_WINDOW);
    const doc = fs.otps.get(otpDocId(EMAIL, 'reset'))!;
    expect(doc.sends).toBe(MAX_SENDS_PER_WINDOW);

    // 6th send inside the window — still ok, but no new mail / send count.
    const sixth = await handleSendOtp(
      { email: EMAIL, purpose: 'reset' },
      { auth: auth.deps, db: fs.deps },
      { nowMs: base + 10_000, generateCode: () => '999999' },
    );
    expect(sixth).toEqual({ ok: true });
    expect(fs.mail).toHaveLength(MAX_SENDS_PER_WINDOW);
    expect(fs.otps.get(otpDocId(EMAIL, 'reset'))!.sends).toBe(
      MAX_SENDS_PER_WINDOW,
    );
    expect(fs.otps.get(otpDocId(EMAIL, 'reset'))!.hash).toBe(
      sha256('100004'),
    );

    // After the window rolls, a new send is allowed.
    const afterWindow = await handleSendOtp(
      { email: EMAIL, purpose: 'reset' },
      { auth: auth.deps, db: fs.deps },
      {
        nowMs: base + RATE_LIMIT_WINDOW_MS + 1,
        generateCode: () => '654321',
      },
    );
    expect(afterWindow).toEqual({ ok: true });
    expect(fs.mail).toHaveLength(MAX_SENDS_PER_WINDOW + 1);
    expect(fs.otps.get(otpDocId(EMAIL, 'reset'))!.hash).toBe(sha256('654321'));
  });
});

describe('verifyOtp', () => {
  test('wrong code ×5 invalidates the OTP', async () => {
    const fs = createFakeFirestore();
    const auth = createFakeAuth({
      users: { [EMAIL]: { uid: UID, email: EMAIL } },
    });
    const now = 1_700_000_000_000;
    const docId = otpDocId(EMAIL, 'verify');

    await fs.deps.otpDoc(docId).set({
      hash: sha256('111111'),
      purpose: 'verify',
      attempts: 0,
      sends: 1,
      sendTimestamps: [now],
      expiresAt: Timestamp.fromMillis(now + 10 * 60 * 1000),
    });

    for (let i = 0; i < MAX_VERIFY_ATTEMPTS - 1; i++) {
      await expect(
        handleVerifyOtp(
          { email: EMAIL, code: '000000', purpose: 'verify' },
          { auth: auth.deps, db: fs.deps },
          { nowMs: now },
        ),
      ).rejects.toMatchObject({ code: 'invalid-argument' });
      expect(fs.otps.has(docId)).toBe(true);
      expect(fs.otps.get(docId)!.attempts).toBe(i + 1);
    }

    await expect(
      handleVerifyOtp(
        { email: EMAIL, code: '000000', purpose: 'verify' },
        { auth: auth.deps, db: fs.deps },
        { nowMs: now },
      ),
    ).rejects.toMatchObject({ code: 'resource-exhausted' });

    expect(fs.otps.has(docId)).toBe(false);
  });

  test('verify purpose marks emailVerified on success', async () => {
    const fs = createFakeFirestore();
    const auth = createFakeAuth({
      users: { [EMAIL]: { uid: UID, email: EMAIL, emailVerified: false } },
    });
    const now = 1_700_000_000_000;

    await fs.deps.otpDoc(otpDocId(EMAIL, 'verify')).set({
      hash: sha256('424242'),
      purpose: 'verify',
      attempts: 0,
      sends: 1,
      sendTimestamps: [now],
      expiresAt: Timestamp.fromMillis(now + 10 * 60 * 1000),
    });

    const result = await handleVerifyOtp(
      { email: EMAIL, code: '424242', purpose: 'verify' },
      { auth: auth.deps, db: fs.deps },
      { nowMs: now },
    );

    expect(result).toEqual({ ok: true });
    expect(fs.otps.has(otpDocId(EMAIL, 'verify'))).toBe(false);
    expect(auth.updated).toEqual([
      { uid: UID, props: { emailVerified: true } },
    ]);
  });

  test('reset purpose returns a one-shot resetToken', async () => {
    const fs = createFakeFirestore();
    const auth = createFakeAuth({
      users: { [EMAIL]: { uid: UID, email: EMAIL } },
    });
    const now = 1_700_000_000_000;

    await fs.deps.otpDoc(otpDocId(EMAIL, 'reset')).set({
      hash: sha256('777777'),
      purpose: 'reset',
      attempts: 0,
      sends: 1,
      sendTimestamps: [now],
      expiresAt: Timestamp.fromMillis(now + 10 * 60 * 1000),
    });

    const result = await handleVerifyOtp(
      { email: EMAIL, code: '777777', purpose: 'reset' },
      { auth: auth.deps, db: fs.deps },
      { nowMs: now, generateResetToken: () => 'tok_abc' },
    );

    expect(result).toEqual({ ok: true, resetToken: 'tok_abc' });
    const tokenDoc = fs.otps.get(resetTokenDocId(EMAIL));
    expect(tokenDoc?.hash).toBe(sha256('tok_abc'));
  });
});

describe('resetPassword', () => {
  test('happy path updates password and revokes refresh tokens', async () => {
    const fs = createFakeFirestore();
    const auth = createFakeAuth({
      users: { [EMAIL]: { uid: UID, email: EMAIL } },
    });
    const now = 1_700_000_000_000;
    const resetToken = 'reset-token-xyz';

    await fs.deps.otpDoc(resetTokenDocId(EMAIL)).set({
      hash: sha256(resetToken),
      purpose: 'resetToken',
      expiresAt: Timestamp.fromMillis(now + 5 * 60 * 1000),
    });

    const result = await handleResetPassword(
      { email: EMAIL, resetToken, newPassword: 'newpass12' },
      { auth: auth.deps, db: fs.deps },
      { nowMs: now },
    );

    expect(result).toEqual({ ok: true });
    expect(auth.updated).toEqual([
      { uid: UID, props: { password: 'newpass12' } },
    ]);
    expect(auth.revoked).toEqual([UID]);
    expect(fs.otps.has(resetTokenDocId(EMAIL))).toBe(false);
  });

  test('rejects invalid reset token', async () => {
    const fs = createFakeFirestore();
    const auth = createFakeAuth({
      users: { [EMAIL]: { uid: UID, email: EMAIL } },
    });
    const now = 1_700_000_000_000;

    await fs.deps.otpDoc(resetTokenDocId(EMAIL)).set({
      hash: sha256('good-token'),
      purpose: 'resetToken',
      expiresAt: Timestamp.fromMillis(now + 5 * 60 * 1000),
    });

    await expect(
      handleResetPassword(
        { email: EMAIL, resetToken: 'bad-token', newPassword: 'newpass12' },
        { auth: auth.deps, db: fs.deps },
        { nowMs: now },
      ),
    ).rejects.toBeInstanceOf(HttpsError);
  });
});

describe('deleteAccount', () => {
  test('requires authentication', async () => {
    const fs = createFakeFirestore();
    const auth = createFakeAuth();

    await expect(
      handleDeleteAccount(undefined, { auth: auth.deps, db: fs.deps }),
    ).rejects.toMatchObject({ code: 'unauthenticated' });
  });

  test('recursively deletes users/{uid} then the Auth user', async () => {
    const fs = createFakeFirestore();
    const auth = createFakeAuth({
      users: { [EMAIL]: { uid: UID, email: EMAIL } },
    });

    const result = await handleDeleteAccount(UID, {
      auth: auth.deps,
      db: fs.deps,
    });

    expect(result).toEqual({ ok: true });
    expect(fs.deletedUsers).toEqual([UID]);
    expect(auth.deleted).toEqual([UID]);
  });
});
