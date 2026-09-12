# Context for anyone (human or AI) picking this up cold

This file exists so a future session — human or agent — doesn't have to
reconstruct intent from git history and code alone. Architecture mechanics
live in `ARCHITECTURE.md`; this file is about *why* things are the way they
are.

## What this project is

Puzzle Vault is a single Flutter app (iOS + Android target only) bundling 20
original puzzle/logic mini-games, inspired by (but not copies of) 20
well-known offline, logic/strategy-only mobile puzzle games. It was built
top-down: research the genre → pick 20 titles that are offline-capable and
purely logic/strategy (no reflex/twitch/internet-dependent games) → design
one original, non-infringing mechanic per title → implement all 20 behind a
shared app shell.

Constraints set by the user, in order given:
1. High polish, all 20 games, not a subset. **Superseded** during a later
   UX-feedback pass: "Sequence Merge" turned out to be a genuine mechanical
   duplicate of "Number Merge" (same grid, gesture, and slide/merge/spawn
   engine — only the merge rule differed) and was removed with the user's
   explicit go-ahead, dropping the roster to 19. This was a deliberate,
   confirmed exception to constraint 1, not drift — every other game was
   checked against its nearest-looking neighbour and kept because it
   differed in real input model or win condition, not just theming. The
   roster was later restored to 20 with "Code Breaker" (`code_breaker`), an
   original Mastermind-style deduction puzzle (guess a hidden color
   sequence, get exact/partial-match feedback, deterministic secret per
   level) — a genuinely new mechanic, not a re-add of "Sequence Merge".
2. Local-only persistence, no backend, no network calls of any kind.
3. Max 15 levels/scenarios per game where levels apply (endless-mode games —
   Number Merge is exempt, it has no "level" concept).
4. Light/dark theme toggle.
5. Generic (non-infringing) names for every game — see below. **Partially
   revisited**: "Number Grid" was renamed to "Sudoku" (a generic,
   centuries-old public-domain puzzle name, not a trademark risk like a
   specific branded game would be) at the user's explicit request. "Number
   Merge" was deliberately left as-is rather than renamed to "2048", since
   that name is more closely associated with one specific game.
6. Settings for sound and animation control (independently toggleable, not
   just a single "effects" switch).
7. App name: **Puzzle Vault** (chosen after brainstorming; explicit final
   instruction from the user, overriding the working name "Top Games").

## IP-safety approach

Every game is an original implementation of a generic, decades-old or
public-domain puzzle *mechanic* (Sudoku, Lights Out, Slitherlink,
Numberlink/Flow, sliding-block, sokoban-adjacent) or an original mechanic
only loosely inspired by a known title's *category* — never reusing a third
party's name, art, exact level layouts, or copy. Concretely:

- Original names throughout, with one exception: the Sudoku-style game is
  named "Sudoku" itself, since Sudoku is a generic, public-domain puzzle
  name with no single owner to infringe (unlike, say, "2048", which is
  closely tied to one specific game — the 2048-style game here stays named
  "Number Merge"). The Lights-Out-style game is "Tile Toggle", etc.
- All visuals are drawn with Flutter widgets/`CustomPainter` — no bundled
  image or audio assets, so there's nothing to have been copied from
  reference material in the first place.
- All level data is hand-authored or deterministically seeded in-code, not
  extracted from any existing game.

If you're asked to add a 21st game "like X", follow the same pattern: identify
the generic mechanic category X belongs to, design an original take on that
category, give it a generic name, and implement it from scratch.

## Decisions and why

- **Package name (`topgames` in `pubspec.yaml`) was deliberately NOT renamed**
  when the app was renamed to "Puzzle Vault". It's an internal Dart
  identifier, not user-facing, and every file does `import
  'package:topgames/...'` — renaming it means touching every file for zero
  visible benefit. Only user-facing surfaces were renamed: in-app title/
  AppBar, `CFBundleDisplayName`/`CFBundleName` (iOS), `android:label`
  (Android), and the `PuzzleVaultApp` root widget class.
- **`provider` was removed from `pubspec.yaml`.** It was added early and
  never actually wired in — state is plain `ValueNotifier`/`StatefulWidget`
  throughout; the only reference to the word "provider" anywhere in `lib/`
  was a comment about `path_provider`, not an actual import.
- **The app icon is generated, not hand-designed.** `assets/icon/icon.png`
  (a vault-dial glyph on the `AppTheme.accent` gradient, 1024x1024) is the
  source of truth; every Android `mipmap-*/ic_launcher.png` and iOS
  `AppIcon.appiconset/Icon-App-*.png` was produced by resizing it with Pillow
  (see the one-off script that produced them — not checked in; regenerate
  with any image tool if the source icon changes). No `flutter_launcher_icons`
  dependency was added; the existing filenames/`Contents.json` were reused
  as-is, only the pixel content changed. iOS icons are flattened onto an
  opaque background (App Store rejects icons with alpha).
- **Android also has a proper adaptive icon**, not just the legacy square
  PNG. `mipmap-anydpi-v26/ic_launcher.xml` + `mipmap-*/ic_launcher_foreground.png`
  (glyph only, transparent background, scaled to fit inside the ~66% "safe
  zone" launchers don't clip) + `values/colors.xml`'s
  `ic_launcher_background` (the gradient's darker end, `#1E2982`, since an
  adaptive icon's background layer must be a flat color, not a gradient).
  Without this, modern launchers would mask the already-rounded flat icon
  with their own shape, double-rounding or cropping it. Android resolves
  `@mipmap/ic_launcher` to the `-v26` adaptive version on API 26+
  automatically and falls back to the legacy PNG below that — no manifest
  change needed, both live under the same resource name.
- **Every game has a "How to play" info tip** (`GameDefinition.helpText` +
  `InfoTipButton`) — see `ARCHITECTURE.md` for where it's wired in and why
  only 2 of the 20 game files needed a direct edit for it.
- **Every game has a real logic-driving test**, not just a boot smoke test
  — see `ARCHITECTURE.md`'s testing section. These were written by 4
  parallel agents each covering ~5 games; every test was independently
  verified green via `flutter test` and `flutter analyze` before being
  accepted, and one of them (batch covering `defuse_protocol`) surfaced a
  real bug — see "Bugs found and fixed" above.
- **Sound is intentionally thin** (`Sfx` = `SystemSound.play` +
  `HapticFeedback` patterns only, no real synthesized tones). A richer
  version using the `audioplayers` package was attempted and reverted: adding
  it transitively pulled in `path_provider_foundation` → `objective_c`
  (Dart's native-assets/hooks-runner build system), whose native build hook
  failed on this machine with `ld: tapi error: malformed file... unknown
  architecture arm64e.x1-macos` — an incomplete Xcode Command Line Tools SDK
  (no full Xcode installed). This didn't block `flutter build apk` (Android
  target, unaffected) but completely blocked `flutter test` (needs a host
  macOS native-asset build), which made the change unverifiable and also
  meant the "test-first" discipline for this repo would've silently
  degraded. Reverted rather than ship something unverifiable. **Revisit this
  once a full Xcode install is available on the build machine** — the
  correct fix is almost certainly just fixing the Xcode CLT install, not
  avoiding the dependency forever.
- **A second real-audio attempt, `soundpool`, was also tried and reverted**
  during the UX-feedback pass that added `gameActions`/hints/etc. It avoids
  the `objective_c` dependency chain entirely and passed `flutter test`
  cleanly — but its bundled Android Kotlin plugin code calls
  `PluginRegistry.Registrar`, an API removed from the current Flutter
  Android embedding, so `flutter build apk --debug` failed with
  `Unresolved reference 'Registrar'`. The package is also marked
  discontinued on pub.dev. This is the more important lesson than the
  specific package: **`flutter test` alone is not sufficient to verify an
  audio plugin** — it never compiles platform (Android/iOS) plugin code,
  only the Dart side. Any future attempt must be verified against BOTH
  `flutter test` and a real `flutter build apk --debug` (and ideally an iOS
  build too, once Xcode is available) before being considered safe to keep.
- **A third attempt, `just_audio`** (during the same pass that added home
  progress badges/onboarding/accessibility) — actively maintained, the most
  widely used Flutter audio package — was tried specifically because it's
  *not* abandoned like `soundpool`. It still transitively pulls in
  `path_provider_foundation` → `objective_c` (via `audio_session`) and hit
  the exact same `ld: tapi error: malformed file... unknown architecture`
  as the original `audioplayers` attempt. **This confirms the blocker is
  environmental, not a matter of picking a better-maintained package**:
  essentially every cross-platform Flutter audio plugin needs
  `path_provider_foundation` somewhere, and building it needs a full Xcode
  install — Command Line Tools alone isn't enough, no matter which
  package sits on top. Don't spend more effort trying other pub.dev
  packages on this machine; install full Xcode first.
- **`flutter analyze` and even a Gradle-cached `flutter build apk --debug`
  both missed a real compile error** (`const Icon(..., color:
  AppTheme.success, ...)` after `AppTheme` colors were converted from
  `static const` to `static get` — a `const`-expression error) that only a
  clean `flutter test` run caught. The analyzer/CFE have a known strictness
  mismatch on this class of error, and the Gradle build likely used
  incremental/cached compilation that didn't re-validate the untouched code
  path. **Treat `flutter test` as the authoritative compile-correctness
  check**, not `flutter analyze` or an unclean `flutter build`. When in
  doubt, `flutter clean` before a build you're trusting as verification.
- **Manual emulator UI testing was abandoned in favor of widget tests.**
  `adb shell input tap` on the local Android emulator (`bhasha_test`,
  `emulator-5554`) intermittently registered taps as scroll/drag gestures,
  producing misleading results (e.g. landing on a different level or a
  scrolled screen than intended). This is an adb/emulator input-timing quirk,
  not an app bug. Anything requiring precise interaction verification should
  go through a widget test (see `test/theme_propagation_test.dart` and
  `test/reset_progress_test.dart` for the pattern: `pumpWidget` →
  `find.text(...)`/`find.byType(...)` → `tester.tap(...)` →
  `pumpAndSettle()`), not manual `adb` taps.
- **`AppTheme` colors are `static get`, not `static const`,** because the
  theme needs to flip at runtime based on a settings toggle, and a `const`
  can't do that. The cost is that ~50 call sites across 11 game files had to
  drop `const` from expressions that referenced them (map/list literals,
  `const Icon(...)`, etc.) — if you add a new game and get
  `const_initialized_with_non_constant_value` or similar, this is why: don't
  mark something `const` if it touches `AppTheme.*`.

## Bugs found and fixed while adding logic tests

Writing real logic-driving tests (as opposed to boot smoke tests) surfaced an
actual production bug in `defuse_protocol_game.dart`: `build()` indexed
`_modules[_moduleIndex]` unconditionally, but `_advance()` bumps
`_moduleIndex` to `_modules.length` via `setState` the moment the last module
is solved — and the result dialog opens as an *overlay* on top of the still-
mounted `DefuseProtocolScreen`, not in place of it, so the screen keeps
rebuilding (e.g. for the dialog's own entrance animation) with an
out-of-range index. This would throw `RangeError` on completing the last
module of any level in real play. Fixed by rendering a "cleared" placeholder
when `_moduleIndex >= _modules.length` instead of indexing into `_modules`.
The regression test in `test/games/defuse_protocol_logic_test.dart`
deliberately pumps an extra frame after the completing action specifically
to catch this class of bug — don't "simplify" that pump away.

This is worth generalizing: any game whose `build()` indexes into a list
using a counter that can be incremented past the list's bounds by the same
`setState` that reports completion should either clamp/guard that index or
check for the completed state before indexing, since `GameHost` never
unmounts the screen synchronously on `onComplete` — it shows a dialog on top
of it first.

A follow-up audit of the same "screen stays mounted under the result
dialog" hazard, this time for `Timer`/`AnimationController`/`Ticker`
lifecycles, found: `defuse_protocol`'s `Timer.periodic` was already
correctly cancelled in `dispose()`; `ragdoll_trials` and `snip_logic`'s
physics `Ticker`s already short-circuited in `_onTick` once
`_completed`/`_failed` was set; but `physics_logic`'s `_onTick` had no such
guard — it kept stepping physics and calling `setState` every frame for as
long as the result dialog stayed open after a win. Fixed by adding the same
`if (_completed) return;` guard the other two games already had. This
wasn't a crash, just wasted CPU/battery and unnecessary rebuilds, but it's
the same root cause shape as the `defuse_protocol` bug: don't assume a
callback/ticker stops just because the level "ended" — `GameHost` keeps the
screen alive and ticking until the player dismisses the dialog.

## Store readiness

`store/` holds everything prepared for Play Store / App Store submission
that could be done without an Apple Developer account, a Play Console
account, or a full Xcode install — see `store/PLAY_STORE_READINESS.md` and
`store/APP_STORE_READINESS.md` for the full checklists (each explicitly
marks what's ready vs. what still needs a human decision or an environment
this machine doesn't have).

- **The iOS app icon was regenerated mid-pass.** It had been resized from
  the same rounded-square master used for the in-app/Android icon
  (`assets/icon/icon.png`), which bakes a rounded shape into a flat-color
  square. iOS applies its *own* corner mask at render time, so a
  pre-rounded icon shows a visible mismatched patch in the true corners
  once iOS re-masks it — a real defect, not just a style nit. Fixed by
  rendering a second, full-bleed square master (same vault-dial glyph and
  gradient, no rounding, no padding) specifically for
  `ios/Runner/Assets.xcassets/AppIcon.appiconset/*.png`. The Android
  adaptive icon doesn't have this problem since its foreground/background
  split was already designed for launcher-applied masking from the start
  (see the icon bullet above) — only the *legacy* pre-adaptive-icon PNGs
  and the in-app icon still intentionally use the pre-rounded master, since
  those are displayed as-is with no further masking.
- **Screenshots exist only for Android**, captured from the `bhasha_test`
  emulator after temporarily overriding its display to 1080×1920/440dpi
  (see `store/screenshots/android/README.md` for the exact repro). No iOS
  screenshots exist — this machine has Xcode Command Line Tools but not a
  full Xcode install, so no iOS build has ever been run, let alone
  screenshotted.
- **Android upload keystore was generated on 2026-09-11, with the user's
  explicit go-ahead** (asked first, since this is exactly the kind of
  action too consequential to do speculatively — see the superseded
  bullet below). Kept outside this repo at
  `~/keystores/puzzle-vault/upload-keystore.jks`, wired into
  `android/app/build.gradle.kts` (falls back to debug signing if
  `android/key.properties` is absent, so other checkouts/CI still build),
  and verified with a real signed release build. The user still needs to
  personally back up the keystore file + password somewhere durable — see
  `~/keystores/puzzle-vault/README.txt`, which has the password and
  explains the stakes (losing it permanently blocks future updates to the
  app under the same Play listing).
- **iOS signing/provisioning is still not done** — needs an active Apple
  Developer Program account, which nothing here can create (requires the
  user's own login + payment).
- ~~No signing/keystore work was done for either platform.~~ Superseded
  for Android by the bullet above; still true for iOS.
- **The privacy policy is hosted at
  https://priyankraj.github.io/puzzle-vault-privacy/** — a small,
  separate, dedicated public GitHub repo (`PriyankRaj/puzzle-vault-privacy`)
  containing only the policy page, deliberately *not* this app's source.
  Publishing this whole repo publicly wasn't asked for and wasn't done;
  only the one page needed for store submission was published.

## Orientation

The app is locked to portrait everywhere (`SystemChrome.setPreferredOrientations`
in `main.dart`, plus native-level locks in `Info.plist` and
`AndroidManifest.xml`'s `android:screenOrientation="portrait"`). None of the
20 games' layouts (AppBar + padded board in a `Column`, fixed-aspect grids)
were built with landscape in mind, so this was a deliberate simplification
rather than a per-game landscape layout pass. If a future game genuinely
needs landscape (unlikely for this genre), it would need its own layout
work, not just removing this lock.

## Known gaps (not requested, not done)

- **iOS build was verified on 2026-09-11** on a machine with a full Xcode
  26.6 install (`flutter build ios --debug --no-codesign` succeeds; the app
  runs correctly on an iPhone 16 Pro Max simulator). This superseded the
  earlier "iOS build is unverified" gap — see `store/APP_STORE_READINESS.md`
  for the full writeup. What's still unverified: real device signing/
  provisioning (needs an Apple Developer account), and 3 of the 5 usual
  App Store screenshots (gameplay, Settings, light-theme home) — Simulator
  UI automation via synthetic mouse clicks (`cliclick`) reliably drove the
  app from home into a game's level-select screen, but repeatedly failed to
  register a tap on a level tile to reach actual gameplay, for reasons not
  root-caused (see below). Don't assume this means real device behavior is
  unverified too — only signing/provisioning and those 3 screenshots are.
- **Desktop GUI automation for iOS screenshots is unreliable and was
  abandoned mid-pass**, for a different reason than the Android emulator's
  known `adb input tap` flakiness (see the Android bullet below — same
  *symptom* class, different cause). Using `cliclick`/AppleScript System
  Events to drive the Simulator window: a tap on the home screen's game
  tile worked reliably (reproduced twice, clean launches both times), but
  an identically-computed tap on the resulting level-select screen's level
  tile never registered, even after confirming (via `System Events... get
  name of first application process whose frontmost is true`) that
  Simulator was frontmost immediately before and after the click, and after
  a full Simulator app restart. Also discovered mid-debugging: this
  machine's desktop was shared with another unrelated, actively-used
  terminal window (a different live Claude Code session on another
  project) — `tell application "Simulator" to activate` did not reliably
  keep Simulator frontmost against that window's own real-time activity,
  and at least one synthetic click landed on that other window instead
  (harmlessly, in empty scrollback — no keystrokes were ever sent to it,
  only mouse clicks). **Do not resume this kind of automation on a shared/
  multi-session desktop** — verify exclusive foreground focus first, or
  capture screenshots by hand via Simulator's own Cmd+S shortcut instead of
  programmatic clicking.
- **No accessibility pass** — no screen-reader semantics review, no
  text-scaling verification. Not requested by the user, flagged here so it
  isn't mistaken for "considered and rejected."

## Repo state

This directory was not a git repository until the README/ARCHITECTURE/
CONTEXT docs were added and the repo was initialized. `build/` and
`.dart_tool/` are regenerated by `flutter pub get`/`flutter build` and are
gitignored — don't expect them in a fresh clone; run `flutter pub get`
first.
