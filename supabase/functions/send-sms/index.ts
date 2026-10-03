// Supabase Auth "Send SMS" hook: texts the farmer's sign-in code with
// Africa's Talking, after checking the number and the SMS limits.
// Setup: supabase/README.md, "Phone sign-in".
//
// Secrets (Edge Functions → Secrets):
//   SEND_SMS_HOOK_SECRET  from Authentication → Hooks (v1,whsec_...)
//   AT_USERNAME           Africa's Talking app username ("sandbox" to test)
//   AT_API_KEY            Africa's Talking API key
//   AT_SENDER_ID          optional registered sender ID, e.g. MYFARM
//   SMS_PER_HOUR          optional, codes per number per hour (default 5)
//   SMS_PER_DAY           optional, codes per day for the app (default 500)

import { Webhook } from "npm:standardwebhooks@1.0.0";
import { createClient } from "jsr:@supabase/supabase-js@2";
import { africasTalking, handleSendSms } from "./handler.ts";

const env = (name: string) => Deno.env.get(name) ?? "";

const webhook = new Webhook(
  env("SEND_SMS_HOOK_SECRET").replace("v1,whsec_", ""),
);
const admin = createClient(
  env("SUPABASE_URL"),
  env("SUPABASE_SERVICE_ROLE_KEY"),
);
const send = africasTalking({
  username: env("AT_USERNAME"),
  apiKey: env("AT_API_KEY"),
  from: env("AT_SENDER_ID") || undefined,
});

Deno.serve((req) =>
  handleSendSms(req, {
    verify: (body, headers) => webhook.verify(body, headers),
    allow: async (phone) => {
      const { data, error } = await admin.rpc("sms_allow", {
        p_phone: phone,
        p_per_hour: Number(env("SMS_PER_HOUR") || 5),
        p_per_day: Number(env("SMS_PER_DAY") || 500),
      });
      if (error) throw error;
      return data;
    },
    send,
  })
);
