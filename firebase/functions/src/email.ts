/**
 * Outbound email via Resend HTTP API (no Firebase Extensions).
 * Spec: SPEC-022 §5 — OTP delivery.
 */

export interface OutboundEmail {
  to: string;
  subject: string;
  text: string;
  html: string;
}

export type SendEmailFn = (msg: OutboundEmail) => Promise<void>;

/**
 * Sends one email through Resend. Throws on non-2xx so callers can roll back OTP docs.
 */
export async function sendViaResend(
  apiKey: string,
  from: string,
  msg: OutboundEmail,
  fetchImpl: typeof fetch = fetch,
): Promise<void> {
  if (!apiKey) {
    throw new Error('RESEND_API_KEY is not configured');
  }
  if (!from) {
    throw new Error('RESEND_FROM is not configured');
  }

  const res = await fetchImpl('https://api.resend.com/emails', {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${apiKey}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      from,
      to: [msg.to],
      subject: msg.subject,
      text: msg.text,
      html: msg.html,
    }),
  });

  if (!res.ok) {
    const body = await res.text().catch(() => '');
    throw new Error(`Resend HTTP ${res.status}: ${body.slice(0, 200)}`);
  }
}
