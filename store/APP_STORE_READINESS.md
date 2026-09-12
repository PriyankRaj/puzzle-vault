# Apple App Store readiness — Puzzle Vault

Status: **the App Store Connect listing is fully created and configured —
app record, metadata, age rating, privacy, pricing/availability, and 6 real
device screenshots are all in place. The only remaining step is attaching a
signed build and submitting for review.**

## App identity

⚠️ **Stale as of the "19 games" UX-feedback pass**: the game count dropped
from 20 to 19 (one genuine duplicate, "Sequence Merge", was removed — see
`CONTEXT.md`), and the Sudoku-style game was renamed from "Number Grid" to
"Sudoku". The listing name, subtitle, promotional text, and screenshots
below were already pushed **live** to App Store Connect via browser
automation with the user's real Apple Developer account (see the "done"
section below) — editing this file does not change the live listing. This
needs the user to log into App Store Connect themselves and update the
listing name, subtitle/promo text, and re-capture the 2 screenshots that
show the now-renamed game (`02_gameplay_number_grid.png`), or explicitly
decide it's not worth doing before the first submission.

| Field | Value |
|---|---|
| App Store listing name | **Puzzle Vault: 20 Games** (live in App Store Connect as of 2026-09-12; now stale, see the note above — the plain name "Puzzle Vault" was already taken by another app on the App Store — in-app branding, Android listing, and icon are unaffected) |
| Bundle ID | `com.katariya.topgames` (matches Android's `applicationId`) — registered as an App ID in the Apple Developer portal on 2026-09-12 |
| Apple ID (App Store Connect numeric ID) | 6811286658 |
| Version / build | `1.0.0` / `1` (`pubspec.yaml`'s `1.0.0+1`) |

## ✅ App Store Connect listing — done (2026-09-12)

Completed end-to-end via browser automation, with the user logged into
their own Apple Developer account:

- App record created (iOS, Bundle ID `com.katariya.topgames`, SKU
  `puzzlevault-com-katariya-topgames`, Full Access).
- Subtitle, promotional text, full description, and keywords filled in
  (same copy as drafted below).
- Category: Games > Puzzle. Content Rights: no third-party content.
- Age Rating questionnaire completed (all None/No) → calculated **4+**,
  confirmed across 172+ countries/regions.
- App Privacy published: **Data Not Collected**, privacy policy URL set.
- Pricing: **Free** ($0.00) across all 175 countries/regions.
- Availability: all countries/regions, available on release.
- **6 real-device screenshots** uploaded to the 6.9" iPhone slot (from the
  user's own iPhone, 1179×2556 native, resized to 1290×2796 with `sips` to
  match Apple's accepted 6.9" dimensions) — home screen + 5 different
  games' gameplay (Number Grid, Rule Puzzle, Snip Logic, Tactics Grid,
  Number Merge). The 6.5" slot auto-reuses this same 6.9" set. Files live
  in `store/screenshots/ios/` (renamed `01_home.png` through
  `06_gameplay_number_merge.png`), superseding the earlier 2
  simulator-captured screenshots.

## What's still needed

1. Sign the app in Xcode with the user's paid Apple Developer account
   (Runner target → Signing & Capabilities → Automatically manage signing)
   — confirmed done by the user on 2026-09-12 for running on their own
   iPhone; a fresh **Release/Archive** signing pass is still needed for the
   actual App Store build (running on-device via ⌘R uses Debug/Development
   signing, not the Distribution certificate App Store submission needs).
2. Archive and upload via Xcode Organizer (Product → Archive → Distribute
   App → App Store Connect) or `xcodebuild`/Transporter.
3. Attach the uploaded build to this app version in App Store Connect, then
   Add for Review.

## ✅ Now verified on this machine (2026-09-11)

This machine (unlike the one that did the rest of this work) has a full
Xcode 26.6 install, not just Command Line Tools. `flutter doctor` shows
Xcode fully configured with CocoaPods, and:

- `flutter build ios --debug --no-codesign` succeeds:
  `✓ Built build/ios/iphoneos/Runner.app`. This is the first time an iOS
  build of Puzzle Vault has ever been produced.
- The app runs correctly on an iPhone 16 Pro Max simulator (iOS 26.5,
  created fresh for this — a 6.9" device, matching what App Store Connect
  requires screenshots at). Dark-theme home screen and one game's
  level-select screen were captured and saved to
  `store/screenshots/ios/01_home.png` / `02_level_select.png`.

🚫 **Still not captured: gameplay, Settings, and light-theme home
screenshots.** Simulated mouse-click automation (`cliclick` driving the
Simulator window) reliably opened the home screen and one game's
level-select screen, but repeatedly failed to register a tap on a level
tile to reach actual gameplay — root cause not resolved (window-focus
churn from another unrelated foreground app on the same desktop was ruled
in as a contributing factor, since it was observed stealing focus from
Simulator mid-sequence, but even with focus confirmed immediately
before/after a click, the tap still didn't register — so something else
about that specific tap target is also at play). Automation was stopped
rather than continuing to guess-click on a desktop with another window
actively in use. **Retry from a real device or Simulator session with
exclusive foreground focus**, or capture the remaining 3 screenshots by
hand (home → a game → level select → gameplay → Settings → light theme,
same flow as `store/screenshots/android/README.md`) using Simulator's own
Cmd+S screenshot shortcut instead of programmatic clicking.

## Store listing copy

**Subtitle** (≤30 characters):

> 20 offline puzzle games

**Promotional text** (≤170 characters, editable without a new build):

> No ads, no account, no wifi needed. 20 original puzzle & logic games,
> light or dark, all saved privately on your device.

**Description** (≤4000 characters) — same copy as the Play listing's full
description, reusable as-is (see `PLAY_STORE_READINESS.md`).

**Keywords** (≤100 characters, comma-separated, no spaces needed):

> puzzle,logic,offline,brain,sudoku,2048,sliding,tile,strategy,mind

**Category:** Primary: Games. Secondary: Puzzle.

**Age rating questionnaire:** answer every content-descriptor question
(violence, mature/suggestive themes, gambling, horror, alcohol/drugs,
profanity, unrestricted web access) with **None/No** — this should land at
4+.

**App Privacy (Apple's "privacy nutrition label"):** declare **Data Not
Collected** — accurate per `store/PRIVACY_POLICY.md`, since the app makes
no network requests and stores everything only via on-device
`UserDefaults` (`shared_preferences`'s iOS backing store).

✅ **Privacy policy URL** — hosted at
**https://priyankraj.github.io/puzzle-vault-privacy/** (same page used for
Play Console). Paste this into App Store Connect's App Privacy section.
Contact address on the page: priyank@hams.co.in.

## Visual assets

| Asset | Path | Spec | Status |
|---|---|---|---|
| App icon | `ios/Runner/Assets.xcassets/AppIcon.appiconset/*.png` | all required sizes, full-bleed square (no pre-baked rounding — iOS applies its own mask) | ✅ regenerated this pass |
| Screenshots | `store/screenshots/ios/*.png` | 6.9" iPhone (required), 1290×2796 | ✅ 6 uploaded — real iPhone screenshots (home + 5 games' gameplay), resized from native 1179×2556 |

**Fixed while preparing this:** the iOS icon set was previously resized
from the same rounded-square master used for the Android/in-app icon,
which meant it had a pre-baked rounded shape with flat-color fill in the
true corners — visible as a mismatched patch once iOS applies its *own*
corner mask on top. Regenerated all 15 `Icon-App-*.png` files from a fresh
full-bleed square render (same vault-dial glyph and brand gradient, no
rounding, no padding) so iOS's masking is the only rounding applied. See
`CONTEXT.md` for the full writeup.

## Pre-submission checklist

- [x] App icon (regenerated, full-bleed, no baked-in rounding)
- [x] Subtitle, promotional text, description, keywords drafted and entered in App Store Connect
- [x] Age rating questionnaire completed in App Store Connect → 4+
- [x] App Privacy published in App Store Connect → Data Not Collected
- [x] Privacy policy drafted
- [x] Privacy policy hosted at a public URL (https://priyankraj.github.io/puzzle-vault-privacy/)
- [x] Screenshots captured and uploaded (6 real-device screenshots, 2026-09-12)
- [x] Bundle ID confirmed final (`com.katariya.topgames`, registered as an App ID)
- [x] App ID + App Store Connect record created (Apple ID 6811286658)
- [x] Pricing (Free) and availability (all countries) set
- [x] Development signing configured in Xcode, app runs on the user's own iPhone (2026-09-12)
- [ ] Distribution (Release/Archive) signing configured in Xcode
- [ ] Archive uploaded via Xcode Organizer or Transporter
- [ ] Build attached to the app version in App Store Connect
- [ ] Submitted for review
