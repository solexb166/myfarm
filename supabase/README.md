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

## Accounts (email sign-in)

Farmers can sign in from the account button on the home screen. They enter
their email and type the 6-digit code they receive; there is no password.
Signing in is optional, and diagnosis never needs it.

- **Keeping what the phone already backed up:** before the code is sent, the
  phone asks for a one-time *merge ticket* (`start_account_merge`). After
  sign-in it hands the ticket back (`finish_account_merge`), and the server
  moves the anonymous scans and plan onto the email account. This works
  whether the email is new or the farmer already has an account (e.g. a new
  phone). If the account already has a plan, it keeps it.
- **Photos uploaded before sign-in** stay in the anonymous user's folder in
  `scan-photos`. Their `photo_path` on the moved scans still points there,
  and you can see them in the dashboard.
- **Signing out** removes the farmer's scans and plan from the phone. They
  stay in the account. The app warns first if any scans haven't uploaded.
- **Making sign-in required for backup:** if you turn off anonymous
  sign-ins, nothing uploads until the farmer signs in. Scans wait on the
  phone and upload after sign-in.

## Schema

| Object | Purpose |
|---|---|
| `scans` | One row per diagnosis. `(user_id, taken_at)` is unique, so retried uploads don't duplicate |
| `crop_plans` | One row per user: the active plan, with tasks as JSON |
| `profiles` | One row per signed-in farmer: display name |
| `start_account_merge()` / `finish_account_merge(ticket)` | Move a phone's anonymous data to the account it signs in to |
| `treatments` | `(label, lang)` → cause / organic / chemical / prevent. Seeded from `treatment_db.dart` |
| `disease_counts` | View: scans per disease per week, for analysis in the dashboard |
| `scan-photos` | Private storage bucket. Each user's photos are in a `<user id>/` folder |

## Setup

1. **Create a project** at <https://supabase.com/dashboard> (the free tier is
   enough to start).
2. **Auth settings** (Authentication → Sign In / Providers):
   - Turn on *Allow anonymous sign-ins*.
   - Keep the **Email** provider on.
   - Turning on CAPTCHA protection is a good idea before a public release.
3. **Email code templates** (Authentication → Emails → Templates): edit both
   **Confirm signup** (sent to new emails) and **Magic Link** (sent to
   existing accounts) so they show the code, for example:

   ```html
   <h2>Your MY FARM sign-in code</h2>
   <p>Enter this code in the app: <strong>{{ .Token }}</strong></p>
   <p>It expires in one hour. If you didn't ask for it, ignore this email.</p>
   ```

   The default templates only contain a link, which the app does not use.
4. **Email sending** (Authentication → Emails → SMTP Settings): Supabase's
   built-in sender is for testing only. It only delivers to your project
   team's addresses, and only a few emails per hour. Before farmers use the
   app, connect a real email provider (e.g. Resend, Brevo, Amazon SES or
   Mailgun). Then raise the email rate limit under Authentication → Rate
   Limits.
5. **Create the tables**, using either method:
   - **CLI:** `npx supabase login`, then `npx supabase link --project-ref <ref>`,
     then `npx supabase db push`
   - **Dashboard:** open the SQL Editor and run the files in
     `supabase/migrations/` in name order
6. **Get the keys** from Project Settings → API Keys: the project URL and the
   *publishable* key (`sb_publishable_…`). These are safe to put in the app,
   because RLS protects the data. **Never** put the secret / `service_role`
   key in the app.
7. **Run the app with them:**

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
