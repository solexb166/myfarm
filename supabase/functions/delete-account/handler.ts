// Logic of delete-account, kept apart from the HTTP server and Supabase
// clients so it can be tested (supabase/functions/tests).

export interface Deps {
  /** The account an access token belongs to, or null if it isn't valid. */
  userFor(jwt: string): Promise<{ id: string; phone?: string } | null>;
  /** Up to 100 object names in the farmer's photo folder. */
  listPhotos(userId: string): Promise<string[]>;
  removePhotos(paths: string[]): Promise<void>;
  /** Removes the number from the SMS rate-limit log. */
  forgetPhone(phone: string): Promise<void>;
  /** Deletes the login. Scans, plan and profile go with it (on delete
   * cascade). */
  deleteUser(userId: string): Promise<void>;
}

function error(status: number, message: string): Response {
  return Response.json({ error: message }, { status });
}

export async function handleDeleteAccount(
  req: Request,
  deps: Deps,
): Promise<Response> {
  if (req.method !== "POST") return error(405, "Method not allowed");
  const jwt = (req.headers.get("Authorization") ?? "").replace(
    /^Bearer\s+/i,
    "",
  );
  const user = jwt ? await deps.userFor(jwt) : null;
  if (user == null) return error(401, "Not signed in");

  try {
    // Photos first: once the login is gone, nothing would point to them.
    // If this fails, the account stays and the farmer can try again.
    for (let round = 0; round < 1000; round++) {
      const names = await deps.listPhotos(user.id);
      if (names.length === 0) break;
      await deps.removePhotos(names.map((n) => `${user.id}/${n}`));
    }
    if (user.phone) await deps.forgetPhone(user.phone.replace(/\D/g, ""));
    await deps.deleteUser(user.id);
  } catch (e) {
    console.error("Account deletion failed", user.id, e);
    return error(500, "Could not delete the account. Try again.");
  }
  return Response.json({ deleted: true });
}
