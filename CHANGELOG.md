# Changelog

All notable changes to Puzzle Vault are recorded here. Format loosely
follows [Keep a Changelog](https://keepachangelog.com/); dates are the day
the work landed, not a formal release date, since this app hasn't shipped
to a store yet.

## [Unreleased]

### Verified

- iOS build confirmed working for the first time (2026-09-11), on a
  machine with a full Xcode 26.6 install rather than just Command Line
  Tools: `flutter build ios --debug --no-codesign` succeeds, and the app
  runs correctly on an iPhone 16 Pro Max simulator. 2 of the 5 usual App
  Store screenshots were captured (`store/screenshots/ios/`); gameplay,
  Settings, and light-theme home remain — see `store/APP_STORE_READINESS.md`
  for why (Simulator UI-automation reliability issue, not an app bug).
- Android release signing verified end-to-end (2026-09-11): generated an
  upload keystore, wired it into `android/app/build.gradle.kts`, and
  confirmed `flutter build appbundle --release` / `apk --release` both
  produce artifacts signed with it (checked via `apksigner verify
  --print-certs`), not the debug key.

### Store submission prep

- Privacy policy is now hosted publicly at
  https://priyankraj.github.io/puzzle-vault-privacy/ (a small dedicated
  GitHub repo containing just the policy page, not the app's source),
  satisfying both Play Console's and App Store Connect's requirement for a
  public privacy policy URL. Contact address: priyank@hams.co.in.
- Play Console app record created for Puzzle Vault
  (`com.katariya.topgames`) and all 11 App content policy declarations
  completed (privacy policy, ads, sign-in details, content ratings —
  IARC questionnaire, all-ages/general rating — target audience, data
  safety, advertising ID, government apps, financial features, health
  apps). Target audience was declared as all ages including children, at
  the user's explicit choice, which enrolls the app in Google Play's
  Families Policy program. Store listing text (name/short/full
  description) saved as a draft; graphics and screenshots still need a
  manual upload — see `store/PLAY_STORE_READINESS.md`.

### Added

- 20 original, offline-only puzzle/logic mini-games behind a shared
  framework (`GameDefinition`, `GameHost`, `LevelSelectScreen`) — see
  `README.md` for the full list.
- Light/dark theme toggle, reaching every screen including all 20 games.
- Settings screen: dark mode, sound effects, and animations toggles, each
  independently persisted.
- "How to play" info tip (ⓘ) on every game — on `LevelSelectScreen` for the
  18 level-based games, and in-AppBar for the 2 endless games.
- "Reset progress" for a single game (level-select AppBar / endless games'
  own AppBar), in addition to the existing "Reset all progress" in Settings.
- Real logic-driving tests for every one of the 20 games
  (`test/games/*_logic_test.dart`) — most replay a genuine win through the
  actual UI rather than just asserting "boots without crashing".
- `test/game_smoke_test.dart` now also asserts every registered game has
  non-empty `helpText` and a corresponding logic test file, so a future
  21st game can't silently ship without either.
- Custom app icon (a vault-dial glyph on the app's brand gradient),
  installed at every required Android/iOS resolution, plus a proper
  Android adaptive icon (`mipmap-anydpi-v26/ic_launcher.xml` +
  foreground/background layers) so modern launchers mask it correctly
  instead of cropping the flat square icon into their own shape.
- CI (`.github/workflows/ci.yml`): `dart format --set-exit-if-changed`,
  `flutter analyze`, `flutter test`, and a debug APK build on every push/PR.
- `ARCHITECTURE.md` and `CONTEXT.md` documenting the shared framework and
  the non-obvious decisions/incidents behind it.

### Fixed

- `defuse_protocol_game.dart`: completing a level's last module could throw
  `RangeError` on the next frame, because the result dialog opens as an
  overlay on top of the still-mounted game screen, and that screen's
  `build()` indexed a now-out-of-range module counter. Fixed by rendering a
  "cleared" placeholder once the level is done instead of indexing past the
  end of the module list.
- `physics_logic_game.dart`: its physics ticker kept stepping simulation
  and calling `setState` every frame even after the level was won (as long
  as the result dialog stayed open), unlike the two sibling physics games
  (`ragdoll_trials`, `snip_logic`) which already guarded against this. Added
  the same `if (_completed) return;` guard.

### Changed

- Renamed the app to **Puzzle Vault** across all user-facing surfaces
  (in-app title/AppBar, iOS `CFBundleDisplayName`/`CFBundleName`, Android
  `android:label`) and the root widget class. The Dart package name
  (`topgames` in `pubspec.yaml`) and `package:topgames/...` imports were
  deliberately left as-is — internal identifiers, not user-visible.
- Locked the app to portrait orientation everywhere (Dart-side
  `SystemChrome.setPreferredOrientations`, plus native locks in `Info.plist`
  and `AndroidManifest.xml`), since none of the 20 games' layouts were built
  with landscape in mind.
- Removed the unused `provider` dependency (added early, never actually
  wired in).

## Earlier (pre-changelog)

The initial 20-game app, its theming/settings/sound framework, and this
repo's git history predate this file — see `git log` and `CONTEXT.md` for
that history.
