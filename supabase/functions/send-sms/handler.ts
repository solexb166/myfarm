// Logic of the Send SMS hook, kept apart from the HTTP server and the
// outside services so it can be tested (supabase/functions/tests).

export type AllowResult = "ok" | "phone_limit" | "daily_limit";

export interface Deps {
  /** Checks the Standard Webhooks signature; throws if it is wrong. */
  verify(body: string, headers: Record<string, string>): unknown;
  /** Counts this SMS against the limits (public.sms_allow). */
  allow(phone: string): Promise<AllowResult>;
  /** Sends the SMS to an E.164 number. Throws if it wasn't accepted. */
  send(to: string, message: string): Promise<void>;
}

/** +2567XXXXXXXX for a Ugandan mobile number, else null. Auth gives the
 * number as digits without the +. */
export function ugandaMobile(phone: string): string | null {
  const digits = phone.replace(/\D/g, "");
  return /^2567\d{8}$/.test(digits) ? `+${digits}` : null;
}

/** The SMS text. Short enough for one SMS (160 characters). */
export function smsText(otp: string, lang: string): string {
  return lang === "lg"
    ? `Koodi yo eya MY FARM: ${otp}. Togiwa muntu yenna.`
    : `Your MY FARM code is ${otp}. Do not share it with anyone.`;
}

/** Error in the shape Supabase Auth expects from a hook. */
function hookError(status: number, message: string): Response {
  return Response.json({ error: { http_code: status, message } }, {
    status,
  });
}

interface HookPayload {
  user?: { phone?: string; user_metadata?: { lang?: string } };
  sms?: { otp?: string };
}

export async function handleSendSms(
  req: Request,
  deps: Deps,
): Promise<Response> {
  if (req.method !== "POST") return hookError(405, "Method not allowed");
  const body = await req.text();
  let payload: HookPayload;
  try {
    payload = deps.verify(body, Object.fromEntries(req.headers)) as HookPayload;
  } catch {
    return hookError(401, "Invalid signature");
  }

  const otp = payload.sms?.otp ?? "";
  const to = ugandaMobile(payload.user?.phone ?? "");
  if (!/^\d{4,10}$/.test(otp)) return hookError(400, "Missing code");
  // Only Ugandan mobile numbers: stops SMS fraud to expensive countries.
  if (to == null) {
    return hookError(400, "Only Ugandan mobile numbers can sign in by SMS");
  }

  let allowed: AllowResult;
  try {
    allowed = await deps.allow(to);
  } catch (e) {
    console.error("sms_allow failed", e);
    return hookError(500, "Could not send the code");
  }
  if (allowed === "phone_limit") {
    return hookError(429, "Too many codes for this number. Try again later");
  }
  if (allowed === "daily_limit") {
    console.error("Daily SMS limit reached");
    return hookError(429, "Too many codes today. Try again later");
  }

  try {
    await deps.send(
      to,
      smsText(otp, payload.user?.user_metadata?.lang ?? "en"),
    );
  } catch (e) {
    console.error("SMS not sent", e);
    return hookError(500, "Could not send the code");
  }
  return Response.json({});
}

/** Sends with Africa's Talking. With username "sandbox" it uses their test
 * environment, where messages only appear in the online simulator. */
export function africasTalking(opts: {
  username: string;
  apiKey: string;
  from?: string;
  fetch?: typeof fetch;
}): (to: string, message: string) => Promise<void> {
  const http = opts.fetch ?? fetch;
  const host = opts.username === "sandbox"
    ? "https://api.sandbox.africastalking.com"
    : "https://api.africastalking.com";
  return async (to, message) => {
    const form = new URLSearchParams({ username: opts.username, to, message });
    if (opts.from) form.set("from", opts.from);
    const res = await http(`${host}/version1/messaging`, {
      method: "POST",
      headers: {
        apiKey: opts.apiKey,
        Accept: "application/json",
        "Content-Type": "application/x-www-form-urlencoded",
      },
      body: form,
    });
    const text = await res.text();
    if (!res.ok) throw new Error(`Africa's Talking ${res.status}: ${text}`);
    // 100 Processed, 101 Sent, 102 Queued. Anything else (e.g. 403 invalid
    // number, 405 insufficient balance) means the farmer gets nothing.
    const recipient = JSON.parse(text)?.SMSMessageData?.Recipients?.[0];
    if (![100, 101, 102].includes(recipient?.statusCode)) {
      throw new Error(`Africa's Talking rejected the SMS: ${text}`);
    }
  };
}
