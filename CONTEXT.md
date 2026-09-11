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
1. High polish, all 20 games, not a subset.
2. Local-only persistence, no backend, no network calls of any kind.
3. Max 15 levels/scenarios per game where levels apply (endless-mode games —
   Number Merge / Sequence Merge — are exempt, they have no "level" concept).
4. Light/dark theme toggle.
5. Generic (non-infringing) names for every game — see below.
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

- Original names throughout (e.g. the Sudoku-style game is "Number Grid", the
  2048-style game is "Number Merge", the Lights-Out-style game is "Tile
  Toggle").
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
- **`provider` is in `pubspec.yaml` but unused.** It was added early and
  never actually wired in — state is plain `ValueNotifier`/`StatefulWidget`
  throughout. Safe to remove if you want to trim dependencies; not removed
  yet because no one asked.
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

## Known gaps (not requested, not done)

- **iOS build is unverified** on this machine — Xcode Command Line Tools only,
  no full Xcode, so no iOS simulator/device build has actually been run.
  Android (`flutter build apk --debug`) is the verified baseline. Don't
  assume iOS parity without building on a machine with full Xcode.
- **No accessibility pass** — no screen-reader semantics review, no
  text-scaling verification. Not requested by the user, flagged here so it
  isn't mistaken for "considered and rejected."

## Repo state

This directory was not a git repository until the README/ARCHITECTURE/
CONTEXT docs were added and the repo was initialized. `build/` and
`.dart_tool/` are regenerated by `flutter pub get`/`flutter build` and are
gitignored — don't expect them in a fresh clone; run `flutter pub get`
first.
