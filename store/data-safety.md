# Play Console answers

Answers for the forms under Play Console → Policy → App content, based on
what the app actually does (see `docs/privacy.html`). If you change what the
app collects, update these and the privacy policy together.

## Data safety

**Data collection and security**

| Question | Answer |
|---|---|
| Does your app collect or share any of the required user data types? | Yes |
| Is all of the user data collected by your app encrypted in transit? | Yes |
| Which of the following methods of account creation does your app support? | Other: email with a one-time code |
| Do you provide a way for users to request that their data is deleted? | Yes |
| Delete account URL | https://solexb166.github.io/myfarm/delete-account.html |

**Data types.** Service providers that process data for you (Supabase,
Africa's Talking, the email provider) don't count as "sharing". The area
totals other farmers see are aggregated and anonymous, which is not sharing
either. So every row below is **Collected: yes, Shared: no, Processed
ephemerally: no**.

| Category → type | Required or optional | Purposes |
|---|---|---|
| Personal info → Name | Optional (users can leave it empty) | App functionality, Account management |
| Personal info → Email address | Required (it is how farmers sign in) | Account management |

Phone sign-in is switched off for now (`PHONE_SIGN_IN`), so phone numbers
are not collected. When you turn it on, change the email row to Optional and
add **Personal info → Phone number: Optional, Account management**, and
switch the reviewer login below to the test phone number.
| Location → Approximate location | Optional (users can choose "Don't share") | App functionality |
| Photos and videos → Photos | Required (each scan's photo is backed up) | App functionality |
| App activity → Other user-generated content (scan results, season plan) | Required | App functionality |

Not collected: precise location (the app stores district, sub-county and a
position snapped to about 2 km, which is over 3 km², Play's limit for
"approximate"), contacts, messages, files, audio, health, financial info,
web browsing, app interactions, crash logs, diagnostics, device IDs.

If you later add crash reporting (Sentry, Firebase Crashlytics), add
**App info and performance → Crash logs / Diagnostics**.

## Other App content forms

| Form | Answer |
|---|---|
| Privacy policy | https://solexb166.github.io/myfarm/privacy.html |
| Ads | No, the app does not contain ads |
| App access | All or some functionality is restricted: give the reviewer test login (below) |
| Target audience and content | 18 and over. Not designed for children, so the Families policy doesn't apply |
| News app | No |
| COVID-19 contact tracing | No |
| Government app | No |
| Financial features | None |
| Health | None (it is about plant health, not people) |
| Data safety | As above |
| Content rating | Questionnaire below |

### App access: test login for Google's reviewers

Sign-in sends a code by email, so reviewers need an inbox they can open.

1. Create a Gmail account just for reviewers, e.g. `myfarm.review@gmail.com`,
   with a password you don't use anywhere else (no 2-Step Verification, so
   reviewers can open it).
2. Play Console → App access → Add instructions:
   - Name: `Reviewer login`
   - Username: the reviewer Gmail address
   - Password: its password
   - Instructions: "On the first screen enter the email above and tap Send
     code. Open that inbox at gmail.com with the same email and password,
     and type the 6-digit code from MY FARM into the app. To try a
     diagnosis, tap Scan a crop, choose Cassava, Beans or Matooke, then
     Gallery and pick a photo of that crop's leaf."

With phone sign-in on, use a test phone number instead: Supabase →
Authentication → Sign In / Providers → Phone → **Test Phone Numbers and
OTPs**: `256700000001=246810`; reviewers enter `0700 000001`, then
`246810`. Supabase sends no SMS for it.

### Content rating questionnaire (IARC)

- Category: **Reference, News, or Educational**
- Violence, fear, sexuality, language, controlled substances, crude humour,
  gambling: **No** to all. Pesticide advice is not a controlled substance.
- Does the app allow users to interact or exchange content? **No**. Farmers
  only see anonymous totals, not each other's content.
- Does the app share the user's location with other users? **No**
- Does the app allow purchases of digital goods? **No**
- Unrestricted internet access (a web browser or search engine)? **No**

Expected rating: Everyone / PEGI 3.

### Permissions Play may ask about

| Permission | Why |
|---|---|
| `ACCESS_COARSE_LOCATION` | Records the district a scan was made in, only after the farmer chooses "Use my location" |
| `INTERNET`, `ACCESS_NETWORK_STATE` | Sign-in, backup, area totals |
| Camera (through the system camera app) | Taking the leaf photo |

The geolocator plugin's background location service is removed in
`AndroidManifest.xml`, so there is no foreground-service declaration to make.
