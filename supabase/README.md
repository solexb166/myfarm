# MY FARM backend (Supabase)

The backend is **optional**. The app works fully offline. When it is built
with Supabase settings and has a connection, it also:

- **backs up scans**: diagnosis, confidence, model label and photo
  (table `scans`, bucket `scan-photos`)
- **backs up the crop plan**: the active season plan, including ticked-off
  tasks (table `crop_plans`)
- **downloads treatment text**: the table `treatments` overrides the text
  bundled in `lib/services/treatment_db.dart`, so an agronomist can fix
  advice without a new app release

Everything is saved on the phone first, and `lib/services/backend.dart` syncs
in the background (on start-up and after every scan or plan change). If the
phone is offline, it tries again next time.

Each phone signs in **anonymously** the first time it is online. Row Level
Security means a phone can only read and write its own scans, plan and
photos. Treatments are read-only to the app.

## Schema

| Object | Purpose |
|---|---|
| `scans` | One row per diagnosis. `(user_id, taken_at)` is unique, so retried uploads don't duplicate |
| `crop_plans` | One row per user: the active plan, with tasks as JSON |
| `treatments` | `(label, lang)` → cause / organic / chemical / prevent. Seeded from `treatment_db.dart` |
| `disease_counts` | View: scans per disease per week, for analysis in the dashboard |
| `scan-photos` | Private storage bucket. Each user's photos are in a `<user id>/` folder |

## Setup

1. **Create a project** at <https://supabase.com/dashboard> (the free tier is
   enough to start).
2. **Turn on anonymous sign-ins**: Authentication → Sign In / Providers →
   *Allow anonymous sign-ins*. Turning on CAPTCHA protection there as well is
   a good idea before a public release.
3. **Create the tables**, using either method:
   - **CLI:** `npx supabase login`, then `npx supabase link --project-ref <ref>`,
     then `npx supabase db push`
   - **Dashboard:** open the SQL Editor and run the files in
     `supabase/migrations/` in name order
4. **Get the keys** from Project Settings → API Keys: the project URL and the
   *publishable* key (`sb_publishable_…`). These are safe to put in the app,
   because RLS protects the data. **Never** put the secret / `service_role`
   key in the app.
5. **Run the app with them:**

   ```bash
   flutter run \
     --dart-define=SUPABASE_URL=https://<ref>.supabase.co \
     --dart-define=SUPABASE_PUBLISHABLE_KEY=sb_publishable_...
   ```

   For Codemagic, add both values to an environment variable group called
   `supabase` and uncomment `groups: - supabase` in `codemagic.yaml`.

## Editing treatment advice

In the dashboard, go to Table Editor → `treatments` and edit a row. Phones get
the new text on their next sync, and keep it for offline use. Deleting a row
makes the app fall back to the bundled text.

When you add a new disease class, add it to `treatment_db.dart` (so it works
offline) **and** add the row here. To regenerate the full seed from the Dart
file:

```bash
python3 tool/export_treatments.py > supabase/migrations/<timestamp>_seed_treatments.sql
```

The seed uses `on conflict do nothing`, so it never overwrites edits made in
the dashboard.

## Looking at the data

In the SQL Editor (which runs as the database owner, so it sees every user):

```sql
select * from disease_counts order by week desc, scans desc;
```

## Privacy

Uploaded photos and scans are linked to an anonymous user ID, with no name or
phone number. Before a public release, mention in the app's privacy notice
that photos are uploaded to improve the service.
