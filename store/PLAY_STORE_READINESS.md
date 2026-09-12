# Google Play Store readiness — Puzzle Vault

Status: **everything this repo can prepare is done and verified — assets,
copy, signing, and a real smoke-tested signed build. Nothing has been
uploaded to Play Console yet.** That last step needs your Play Console
login, which isn't something I can do from this repo alone (see "Creating
the listing" below).

## App identity

| Field | Value |
|---|---|
| App name | Puzzle Vault |
| Package name (`applicationId`) | `com.katariya.topgames` |
| Version name / code | `1.0.0` / `1` (`pubspec.yaml`'s `1.0.0+1`) |

⚠️ **The package name can never be changed after your first upload to Play
Console.** `com.katariya.topgames` is already a real, non-placeholder
identifier (not `com.example.*`), so it's usable as-is — but confirm this is
the identifier you want to be permanently stuck with before the first
release. If not, change `applicationId` in `android/app/build.gradle.kts`
(and `namespace`, and the matching iOS bundle ID for consistency) now,
before ever uploading.

## Store listing copy

**Short description** (≤80 characters):

> 19 original offline puzzle & logic games. No ads, no wifi, no account.

**Full description** (≤4000 characters):

> Puzzle Vault is a collection of 19 original puzzle and logic games in one
> app — no internet connection required, ever.
>
> Every game is a fresh, original take on a classic puzzle mechanic: number
> grids, tile-toggling, sliding blocks, path tracing, loop drawing, rule
> rewriting, tile merging, and more. Each level-based game has up to 15
> hand-designed levels with a star rating for how efficiently you solve
> them; one game is an endless high-score chaser.
>
> Features:
> • 19 distinct games, all playable offline
> • Light and dark themes
> • Independent sound and animation toggles
> • Per-game or all-at-once progress reset
> • A "how to play" tip on every game
> • No ads, no in-app purchases, no account, no tracking, no network access
>   of any kind
>
> Your progress is saved privately on your own device and never leaves it.

**Category:** Games > Puzzle

**Content rating (IARC questionnaire answers):** every "does your app
contain/allow X" question should be answered **No** — no violence, no
sexual content, no profanity, no controlled substances, no gambling
(simulated or real), no user-to-user interaction/chat, no user-generated
content, no location sharing, no personal-information collection. This
should land the app at "Everyone" / PEGI 3 / equivalent in every region.

**Data safety section:** declare **no data collected, no data shared** —
accurate per `PRIVACY_POLICY.md`, since the app has no network access and
uses only on-device `shared_preferences`.

✅ **Privacy policy URL** — hosted at
**https://priyankraj.github.io/puzzle-vault-privacy/** (a small dedicated
public GitHub repo, `PriyankRaj/puzzle-vault-privacy`, containing just the
policy page — not the app's source). Paste this URL into Play Console's
"App content" > "Privacy policy" field. Contact address on the page:
priyank@hams.co.in.

## Visual assets

All generated and saved under `store/`:

| Asset | Path | Spec | Status |
|---|---|---|---|
| App icon (hi-res, for Play Console upload) | `store/graphics/play_store_icon_512.png` | 512×512, 32-bit PNG | ✅ ready |
| Feature graphic | `store/graphics/feature_graphic.png` | 1024×500 PNG | ✅ ready |
| Phone screenshots | `store/screenshots/android/*.png` | 1080×1920 (9:16), PNG, no alpha | ✅ 5 captured (see below) |

Screenshots captured from a real Android emulator run (`bhasha_test`,
resized to a modern 1080×1920/440dpi profile for the capture — see
`store/screenshots/android/README.md`):

1. `01_home.png` — home screen, dark theme
2. `02_level_select.png` — the Sudoku-style game's level-select screen (info
   tip + per-game reset icons visible in the AppBar) — captured when this
   game was still named "Number Grid" in-app; it's since been renamed to
   "Sudoku" and the level-select screen it's no longer the mandatory entry
   point (home now jumps straight into gameplay). The screenshot's UI text
   is stale — recapture if you want it to match current in-app copy.
3. `03_gameplay.png` — same game's (Sudoku-style) gameplay — same staleness
   note as above.
4. `04_settings.png` — Settings screen
5. `05_home_light.png` — home screen, light theme

Play requires 2–8 phone screenshots; these 5 already satisfy that, and
show off the theme toggle and per-game controls without needing every one
of the 19 games captured. ⚠️ If you want more/different screens (e.g. an
endless game, a different puzzle type, tablet screenshots, or just
refreshed captures reflecting the renamed Sudoku game and the new jump-
straight-into-gameplay home flow), rerun the same capture flow — see
`store/screenshots/android/README.md`.

⚠️ **Not attempted:** a tablet screenshot set. Play Console doesn't require
tablet screenshots for a phone-only listing; only add these if you decide
to explicitly support/list tablet form factors.

## Signing & release build

✅ **Done (2026-09-11), with your explicit go-ahead.** An upload keystore
was generated and wired in:

1. Keystore generated at `~/keystores/puzzle-vault/upload-keystore.jks`
   (**outside** this repo, RSA 2048, alias `upload`, valid ~27 years).
   Password + backup instructions are in
   `~/keystores/puzzle-vault/README.txt` — **you still need to copy both
   the keystore file and that password into a password manager or other
   durable encrypted backup.** Losing this file or its password permanently
   blocks future updates to the app under this Play listing.
2. `android/key.properties` created (gitignored, confirmed not tracked by
   git) pointing at the keystore.
3. Wired into `android/app/build.gradle.kts`'s `signingConfigs` — falls
   back to debug signing automatically if `key.properties` is ever absent
   (e.g. CI, or a fresh checkout without the keystore), so this doesn't
   break builds on other machines.
4. Verified: `flutter build appbundle --release` and `flutter build apk
   --release` both succeed, and `apksigner verify --print-certs` on the
   release APK confirms it's signed with this upload key (SHA-256
   `5C:AB:77:45:5B:EF:F0:14:6E:8C:EE:5D:21:50:B1:F8:6A:3C:E0:25:0B:5E:4F:C0:19:96:9F:44:60:3F:AC:B2`),
   not the debug key.

## Pre-submission checklist

- [x] App icon (legacy + adaptive)
- [x] Feature graphic
- [x] Phone screenshots
- [x] Short + full description drafted
- [x] Content rating answers drafted
- [x] Data safety answers drafted
- [x] Privacy policy drafted
- [x] Privacy policy hosted at a public URL (https://priyankraj.github.io/puzzle-vault-privacy/)
- [x] Support contact email decided and added to `PRIVACY_POLICY.md` (priyank@hams.co.in)
- [x] Package name confirmed final (`com.katariya.topgames`, confirmed 2026-09-11)
- [x] Upload keystore generated and backed up (local: `~/keystores/puzzle-vault/`; S3: `s3://app-bhasha/keys/puzzle-vault-upload.jks` + `.README.txt`)
- [x] Signing config wired into `build.gradle.kts`, verified with a real signed build
- [x] Release build smoke-tested (2026-09-11): the *upload-signed* release APK was installed and launched on the `bhasha_test` Android emulator (no physical device available) — runs correctly, no crash. Not tested on a physical device, but running the actual signed artifact (not just a debug build) on a real Android OS is a meaningfully stronger check than the build succeeding alone.
- [x] Play Console app record created (`com.katariya.topgames`, under the
      PRIYANKRAJ KATARIYA developer account) and every App content
      declaration completed — see "Creating the listing" below.
- [ ] Store listing graphics/screenshots uploaded (text fields saved as
      draft; icon/feature graphic/screenshots still need manual upload —
      see below)
- [ ] Signed `.aab` uploaded to a release track and sent for review

## Creating the listing (2026-09-11)

Done directly in Play Console via browser automation, with your
confirmation at each consequential step:

- **App created**: Puzzle Vault, `com.katariya.topgames`, Game, Free,
  under the PRIYANKRAJ KATARIYA developer account (confirmed — matches
  the package name; the account's other option was "Gittu").
- **Default store listing**: app name, short description, and full
  description saved as a draft (exact copy from this file). Visual assets
  (app icon, feature graphic, phone screenshots) were **not** uploaded —
  Play Console's upload buttons open a native OS file picker that browser
  automation can't see or interact with, so this needs a manual upload:
  go to Grow users > Store presence > Store listings > Default store
  listing, and drag in `store/graphics/play_store_icon_512.png`,
  `store/graphics/feature_graphic.png`, and the 5 files under
  `store/screenshots/android/`.
- **All 11 App content declarations completed**: Privacy policy (URL
  above), Ads (No), Sign in details (No), Content ratings (full IARC
  questionnaire, all "No" answers, resulting rating: Everyone/General/3+
  in every territory), Target audience (all ages 5 through 18+, per your
  explicit choice — this enrolled the app in the Families Policy
  program), App details children's-law certification, Data safety (no
  data collected, no data shared, committed to Play Families Policy),
  Advertising ID (No), Government apps (No), Financial features (none),
  Health apps (none).
- **Not joined**: the Teacher Approved program (optional, needs a
  separate review — left for you to opt into later if wanted).

⚠️ **One UI quirk worth knowing if you go back in**: on the Content
ratings questionnaire, the "Next" button can appear permanently disabled
even after every question is answered — click "Save" first (not "Next")
and it unlocks. Root cause unconfirmed; assume it's a draft-persistence
gate, not a real validation failure, if you hit it again.
