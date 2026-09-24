import { sendViaResend } from '../email';

describe('sendViaResend', () => {
  test('POSTs to Resend API with bearer token', async () => {
    const calls: Array<{ url: string; init: RequestInit }> = [];
    const fetchImpl = (async (url: RequestInfo | URL, init?: RequestInit) => {
      calls.push({ url: String(url), init: init ?? {} });
      return new Response(JSON.stringify({ id: 'email_1' }), { status: 200 });
    }) as typeof fetch;

    await sendViaResend(
      're_test',
      'الشاملة <noreply@ishamela.online>',
      {
        to: 'user@example.com',
        subject: 'code',
        text: '123456',
        html: '<p>123456</p>',
      },
      fetchImpl,
    );

    expect(calls).toHaveLength(1);
    expect(calls[0].url).toBe('https://api.resend.com/emails');
    expect(calls[0].init.method).toBe('POST');
    expect(calls[0].init.headers).toMatchObject({
      Authorization: 'Bearer re_test',
      'Content-Type': 'application/json',
    });
    const body = JSON.parse(String(calls[0].init.body));
    expect(body.to).toEqual(['user@example.com']);
    expect(body.from).toContain('noreply@ishamela.online');
  });

  test('throws on non-2xx', async () => {
    const fetchImpl = (async () =>
      new Response('nope', { status: 401 })) as typeof fetch;
    await expect(
      sendViaResend('re_bad', 'from@x.com', {
        to: 'a@b.com',
        subject: 's',
        text: 't',
        html: 'h',
      }, fetchImpl),
    ).rejects.toThrow(/Resend HTTP 401/);
  });
});
