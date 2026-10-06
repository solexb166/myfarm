# Releasing MY FARM on Google Play

Everything in the code is ready. These steps need your accounts, so only you
can do them. Do them in order; each says roughly how long it takes.

| File | What it is |
|---|---|
| `listing.md` | Store listing text: name, short and full description |
| `data-safety.md` | Answers for Data safety, App access, content rating and the other App content forms |
| `icon-512.png`, `feature-graphic.png`, `screenshots/` | Store graphics |
| `../docs/` | Privacy policy and account-deletion pages (GitHub Pages) |
| `../supabase/README.md` | Backend setup in detail |

## 1. Supabase production project (1 hour)

Follow `supabase/README.md` → Setup. In short:

1. Create the project. There is no African region; pick the closest one
   offered (e.g. Frankfurt or London).
2. Push the database: `npx supabase link --project-ref <ref>` then
   `npx supabase db push`.
3. Turn on the **Phone** and **Email** providers, set the email code
   templates, and connect a real email sender (SMTP).
4. Set up **Africa's Talking** and the **Send SMS hook** (section "Phone
   sign-in" in `supabase/README.md`).
5. Deploy the two functions:
   ```bash
   npx supabase functions deploy send-sms --no-verify-jwt
   npx supabase functions deploy delete-account --no-verify-jwt
   ```
6. Add the reviewer test number (see `data-safety.md` → App access).
7. Consider the **Pro plan** (US$25/month) before launch: daily backups,
   and free projects pause after a week without traffic.

## 2. Privacy pages on GitHub Pages (15 minutes)

1. Replace `REPLACE-WITH-YOUR-EMAIL@example.com` in `docs/index.html`,
   `docs/privacy.html` and `docs/delete-account.html` with your support email.
   Farmers and Google will use it.
2. Merge this branch into `main`.
3. GitHub → repository **Settings → Pages** → Source: *Deploy from a branch*
   → Branch `main`, folder `/docs` → Save.
4. After a minute, check https://solexb166.github.io/myfarm/privacy.html opens.

GitHub Pages on a free account needs a **public** repository. If the repo
stays private, host the three pages anywhere else and build the app with
`--dart-define=WEB_BASE_URL=https://your-site/path` (add it to the
`supabase` group in Codemagic and to the build command).

## 3. Upload key (10 minutes)

Google re-signs the app for users (Play App Signing). You sign each upload
with your own **upload key**. Create it once and **back it up**: if you lose
it you must ask Google to reset it, which takes days.

```bash
keytool -genkey -v -keystore myfarm-upload.jks -keyalg RSA -keysize 2048 \
  -validity 10000 -alias upload
base64 -w0 myfarm-upload.jks > myfarm-upload.jks.b64   # macOS: base64 -i ... -o ...
```

## 4. Codemagic (10 minutes)

App settings → Environment variables. Mark every value **Secure**.

| Group | Variables |
|---|---|
| `release` | `CM_KEYSTORE` (contents of the `.b64` file), `CM_KEYSTORE_PASSWORD`, `CM_KEY_ALIAS` (`upload`), `CM_KEY_PASSWORD` |
| `supabase` | `SUPABASE_URL`, `SUPABASE_PUBLISHABLE_KEY` |

Start the **MY FARM Google Play Release** (`play-release`) workflow. It stops
with a clear message if a variable is missing, checks the build is
release-signed and targets a recent Android version, then builds
`app-release.aab`. Each build gets a higher version code automatically. For
a new version, raise `version:` in `pubspec.yaml` (e.g. `1.0.1+1`; the part
after `+` is replaced).

The older `android-release` workflow loads the `supabase` group too, so
its test APKs can sign in. It does not load the `release` group, so its
builds are debug-signed and Play rejects them: use it for testing only.

## 5. Play Console (1 to 2 hours)

1. **Create app**: name "MY FARM: Crop Disease Doctor", default language
   English, App, Free.
2. **App content**: fill in every form using `data-safety.md`.
3. **Store listing**: paste from `listing.md`, upload the icon, feature
   graphic and screenshots.
4. **Countries**: Uganda, and any others you want.

## 6. Testing before production (at least 14 days)

Your developer account is **personal**, so Google requires a closed test
first: **at least 12 testers opted in for 14 days in a row**. Only then can you
apply for production access.

1. **Internal testing** first (no review wait, up to 100 testers): upload
   the `.aab`, add your own Google account, install from the Play link and
   test sign-in by SMS and email, a scan, backup, Diseases near you and
   Delete account.
2. **Closed testing**: create a track, add at least 12 testers by email or a
   Google Group, share the opt-in link, and upload the same `.aab`.
   Farmers, extension officers and friends with Android phones all count.
   Ask them to keep it installed and open it now and then.
3. After 14 days, **apply for production** from the Dashboard. Google asks
   how you tested and what you changed.

## 7. Production release

Create a production release with the tested `.aab`. Start with a staged
rollout (e.g. 20%), then increase it once crash reports look fine.

## After launch

- **Android vitals** in Play Console shows crashes and freezes. No extra
  SDK is needed for that.
- **Africa's Talking balance**: every sign-in code costs money. Top up before
  it runs out, or farmers can't sign in by SMS (email still works). The hook
  stops at `SMS_PER_DAY` codes per day (default 500) to cap the cost.
- **Supabase**: Logs → Edge Functions shows SMS hook errors.
- **Deletion requests by email**: in Supabase, open Storage → `scan-photos`,
  delete the folder named after the user's id, then Authentication → Users →
  delete the user. Their scans, plan and profile go with it.
- Reply to reviews; farmers notice.
