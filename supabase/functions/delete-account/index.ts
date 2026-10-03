// Deletes the signed-in farmer's account and everything in it: scan photos,
// scans, season plan, profile and the login itself. Called from Account →
// Delete account in the app. Google Play requires in-app account deletion.

import { createClient } from "jsr:@supabase/supabase-js@2";
import { handleDeleteAccount } from "./handler.ts";

const admin = createClient(
  Deno.env.get("SUPABASE_URL") ?? "",
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
);
const photos = admin.storage.from("scan-photos");

Deno.serve((req) =>
  handleDeleteAccount(req, {
    userFor: async (jwt) => {
      const { data, error } = await admin.auth.getUser(jwt);
      return error || !data.user ? null : data.user;
    },
    listPhotos: async (userId) => {
      const { data, error } = await photos.list(userId, { limit: 100 });
      if (error) throw error;
      return data.map((o) => o.name);
    },
    removePhotos: async (paths) => {
      const { error } = await photos.remove(paths);
      if (error) throw error;
    },
    forgetPhone: async (phone) => {
      const { error } = await admin.from("sms_log").delete().eq("phone", phone);
      if (error) throw error;
    },
    deleteUser: async (userId) => {
      const { error } = await admin.auth.admin.deleteUser(userId);
      if (error) throw error;
    },
  })
);
