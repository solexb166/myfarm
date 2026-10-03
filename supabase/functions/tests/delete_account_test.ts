// deno test supabase/functions/tests
import { assertEquals } from "jsr:@std/assert@1";
import { handleDeleteAccount } from "../delete-account/handler.ts";

function setup(photos: number, failRemove = false) {
  let left = Array.from({ length: photos }, (_, i) => `${i}.jpg`);
  const log: string[] = [];
  return {
    log,
    deps: {
      userFor: (jwt: string) =>
        Promise.resolve(
          jwt === "good" ? { id: "u1", phone: "256772123456" } : null,
        ),
      listPhotos: (_: string) => Promise.resolve(left.slice(0, 100)),
      removePhotos: (paths: string[]) => {
        if (failRemove) return Promise.reject(new Error("storage down"));
        log.push(`remove ${paths.length} ${paths[0]}`);
        left = left.slice(paths.length);
        return Promise.resolve();
      },
      forgetPhone: (p: string) => {
        log.push(`forget ${p}`);
        return Promise.resolve();
      },
      deleteUser: (id: string) => {
        log.push(`delete ${id}`);
        return Promise.resolve();
      },
    },
  };
}

const req = (token?: string) =>
  new Request("http://x", {
    method: "POST",
    headers: token ? { Authorization: `Bearer ${token}` } : {},
  });

Deno.test("deletes every photo, then the account", async () => {
  const s = setup(230);
  const res = await handleDeleteAccount(req("good"), s.deps);
  assertEquals(res.status, 200);
  assertEquals(s.log, [
    "remove 100 u1/0.jpg",
    "remove 100 u1/100.jpg",
    "remove 30 u1/200.jpg",
    "forget 256772123456",
    "delete u1",
  ]);
});

Deno.test("needs a valid sign-in", async () => {
  for (const token of [undefined, "bad"]) {
    const s = setup(1);
    const res = await handleDeleteAccount(req(token), s.deps);
    assertEquals(res.status, 401);
    assertEquals(s.log, []);
  }
});

Deno.test("keeps the account if photos can't be removed", async () => {
  const s = setup(3, true);
  const res = await handleDeleteAccount(req("good"), s.deps);
  assertEquals(res.status, 500);
  assertEquals(s.log.includes("delete u1"), false);
});
