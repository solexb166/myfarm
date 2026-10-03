// deno test supabase/functions/tests
import { assertEquals } from "jsr:@std/assert@1";
import { Webhook } from "npm:standardwebhooks@1.0.0";
import {
  africasTalking,
  type AllowResult,
  handleSendSms,
  smsText,
  ugandaMobile,
} from "../send-sms/handler.ts";

const secret = btoa("test-secret-test-secret-32-bytes");
const hook = new Webhook(secret);

function signed(payload: unknown): Request {
  const body = JSON.stringify(payload);
  const id = "msg_1";
  const ts = new Date();
  return new Request("http://x", {
    method: "POST",
    body,
    headers: {
      "webhook-id": id,
      "webhook-timestamp": `${Math.floor(ts.getTime() / 1000)}`,
      "webhook-signature": hook.sign(id, ts, body),
    },
  });
}

function setup(allow: AllowResult = "ok", sendFails = false) {
  const sent: [string, string][] = [];
  const allowed: string[] = [];
  return {
    sent,
    allowed,
    deps: {
      verify: (b: string, h: Record<string, string>) => hook.verify(b, h),
      allow: (p: string) => {
        allowed.push(p);
        return Promise.resolve(allow);
      },
      send: (to: string, msg: string) => {
        if (sendFails) return Promise.reject(new Error("no credit"));
        sent.push([to, msg]);
        return Promise.resolve();
      },
    },
  };
}

const payload = (phone: string, lang?: string) => ({
  user: { phone, user_metadata: lang ? { lang } : {} },
  sms: { otp: "123456" },
});

Deno.test("ugandaMobile accepts only Ugandan mobiles", () => {
  assertEquals(ugandaMobile("256772123456"), "+256772123456");
  assertEquals(ugandaMobile("+256 772 123 456"), "+256772123456");
  assertEquals(ugandaMobile("256414123456"), null); // landline
  assertEquals(ugandaMobile("254712345678"), null); // Kenya
  assertEquals(ugandaMobile("25677212345"), null); // too short
});

Deno.test("sends the code to a valid number", async () => {
  const s = setup();
  const res = await handleSendSms(signed(payload("256772123456")), s.deps);
  assertEquals(res.status, 200);
  assertEquals(s.allowed, ["+256772123456"]);
  assertEquals(s.sent, [["+256772123456", smsText("123456", "en")]]);
});

Deno.test("words the SMS in Luganda for Luganda users", async () => {
  const s = setup();
  await handleSendSms(signed(payload("256772123456", "lg")), s.deps);
  assertEquals(s.sent[0][1].startsWith("Koodi yo"), true);
  assertEquals(smsText("123456", "lg").length <= 160, true);
  assertEquals(smsText("123456", "en").length <= 160, true);
});

Deno.test("rejects a bad signature", async () => {
  const s = setup();
  const req = signed(payload("256772123456"));
  const forged = new Request(req, {
    body: JSON.stringify(payload("256700000000")),
  });
  const res = await handleSendSms(forged, s.deps);
  assertEquals(res.status, 401);
  assertEquals(s.sent.length, 0);
});

Deno.test("refuses numbers outside Uganda without counting them", async () => {
  const s = setup();
  const res = await handleSendSms(signed(payload("447700900123")), s.deps);
  assertEquals(res.status, 400);
  assertEquals(s.allowed.length, 0);
  assertEquals(s.sent.length, 0);
});

Deno.test("respects the limits", async () => {
  for (const limit of ["phone_limit", "daily_limit"] as const) {
    const s = setup(limit);
    const res = await handleSendSms(signed(payload("256772123456")), s.deps);
    assertEquals(res.status, 429);
    assertEquals((await res.json()).error.http_code, 429);
    assertEquals(s.sent.length, 0);
  }
});

Deno.test("reports a failed SMS", async () => {
  const s = setup("ok", true);
  const res = await handleSendSms(signed(payload("256772123456")), s.deps);
  assertEquals(res.status, 500);
});

Deno.test("Africa's Talking request and response handling", async () => {
  let url = "";
  let init: RequestInit = {};
  const reply =
    (statusCode: number) => (u: string | URL | Request, i?: RequestInit) => {
      url = String(u);
      init = i ?? {};
      return Promise.resolve(Response.json({
        SMSMessageData: { Recipients: [{ statusCode, status: "x" }] },
      }, { status: 201 }));
    };
  const send = africasTalking({
    username: "myfarm",
    apiKey: "key",
    from: "MYFARM",
    fetch: reply(101) as typeof fetch,
  });
  await send("+256772123456", "hi");
  assertEquals(url, "https://api.africastalking.com/version1/messaging");
  assertEquals((init.headers as Record<string, string>).apiKey, "key");
  const form = init.body as URLSearchParams;
  assertEquals(form.get("to"), "+256772123456");
  assertEquals(form.get("from"), "MYFARM");
  assertEquals(form.get("username"), "myfarm");

  const sandbox = africasTalking({
    username: "sandbox",
    apiKey: "key",
    fetch: reply(405) as typeof fetch, // insufficient balance
  });
  let failed = false;
  try {
    await sandbox("+256772123456", "hi");
  } catch {
    failed = true;
  }
  assertEquals(failed, true);
  assertEquals(url.startsWith("https://api.sandbox.africastalking.com"), true);
});
