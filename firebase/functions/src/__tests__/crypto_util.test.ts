import {
  filterSendTimestamps,
  generateOtpCode,
  isRateLimited,
  normalizeEmail,
  otpDocId,
  RATE_LIMIT_WINDOW_MS,
  sha256,
} from '../crypto_util';

describe('crypto_util', () => {
  test('normalizeEmail lowercases and trims', () => {
    expect(normalizeEmail('  Foo@Bar.COM ')).toBe('foo@bar.com');
  });

  test('otpDocId uses normalized email', () => {
    expect(otpDocId('A@B.com', 'verify')).toBe('a@b.com_verify');
  });

  test('sha256 is stable hex', () => {
    expect(sha256('123456')).toBe(
      '8d969eef6ecad3c29a3a629280e686cf0c3f5d5a86aff3ca12020c923adc6c92',
    );
  });

  test('generateOtpCode is 6 zero-padded digits', () => {
    for (let i = 0; i < 20; i++) {
      const code = generateOtpCode();
      expect(code).toMatch(/^\d{6}$/);
    }
  });

  test('rate-limit window filters old timestamps', () => {
    const now = 1_000_000;
    const stamps = [
      now - RATE_LIMIT_WINDOW_MS - 1,
      now - 1000,
      now - 500,
    ];
    expect(filterSendTimestamps(stamps, now)).toEqual([
      now - 1000,
      now - 500,
    ]);
    expect(isRateLimited([1, 2, 3, 4, 5].map((i) => now - i), now)).toBe(true);
    expect(isRateLimited([1, 2, 3, 4].map((i) => now - i), now)).toBe(false);
  });
});
