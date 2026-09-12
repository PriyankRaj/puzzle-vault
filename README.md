# Puzzle Vault

A single Flutter app (iOS + Android) bundling 20 original, offline-only puzzle
and logic mini-games behind one generic shell: home grid, level select,
settings, and progress persistence.

No backend, no network calls, no bundled media assets. Everything runs and
saves locally on-device via `shared_preferences`.

## Games

| Title | Tagline | Mode |
|---|---|---|
| Sudoku | Classic 9x9 number logic | 15 levels |
| Number Merge | Slide and merge tiles to reach 2048 | Endless |
| Rule Puzzle | Push words to rewrite the rules | 15 levels |
| Path Rotate | Rotate tiles to connect the path | 15 levels |
| Region Trace | Trace a path that separates the colors | 15 levels |
| Loop Draw | Draw one loop that matches every number | 15 levels |
| Tile Toggle | Toggle tiles until the whole grid goes dark | 15 levels |
| Step Blocks | Step across isometric blocks to the goal | 15 levels |
| Color Sort | Arrange the chips into a perfect gradient | 15 levels |
| Key Escape | Collect keys and flip switches to escape | 15 levels |
| Route Planner | Connect every station with limited lines | 15 levels |
| Rule Manual | Follow the manual, defuse the device | 15 levels |
| Draw Physics | Draw shapes to guide the ball home | 15 levels |
| Brain Trick | Read carefully — the obvious answer is a trap | 15 levels |
| Pipe Connect | Link every matching pair without crossing | 15 levels |
| Slide Escape | Slide blocks aside to free the exit path | 15 levels |
| Rope Cut | Cut ropes at the right moment to land the parcel | 15 levels |
| Tumble Course | Push and tumble the blob to the goal | 15 levels |
| Squad Battle | Command your squad to victory | 15 levels |
| Code Breaker | Crack the secret color code before you run out of guesses | 15 levels |

Every game is an original implementation of a generic/public-domain puzzle
mechanic (or a loosely-inspired original mechanic) — original names (except
"Sudoku", a generic public-domain puzzle name), original art (drawn with
Flutter widgets, no image assets), and original level data. See `CONTEXT.md`
for the IP-safety rationale behind each game.

An earlier 20th game, "Sequence Merge" ("Threes"-style: slide 1s and 2s
together), was removed — it shared the same grid, swipe gesture, and
slide/merge/spawn engine as "Number Merge" (2048-style), differing only in
the merge rule. See `CONTEXT.md` for the dedup rationale. The roster was
later restored to 20 with "Code Breaker", an original Mastermind-style
deduction puzzle, rather than reintroducing the duplicate.

## Features

- Light/dark theme toggle, applied instantly everywhere (home, level select,
  settings, and inside every game).
- Settings: dark mode, sound effects, animations — each independently
  toggleable and persisted.
- "Reset all progress" (Settings) or "Reset progress" for just one game
  (level-select AppBar / endless games' own AppBar), each behind a
  confirmation dialog.
- Per-game star/lock progress tracked locally, capped at 15 levels per game.
- "How to play" info tip (ⓘ) on every game — on the level-select screen for
  the 19 level-based games, and in the AppBar for the one endless game.
- Real logic-driving tests for every game (`test/games/*.dart`), not just
  boot smoke tests — most replay a genuine win via the actual UI.

## Getting started

```bash
flutter pub get
flutter run            # requires a connected device/simulator
```

## Verifying changes

```bash
flutter analyze
flutter test
flutter build apk --debug   # Android sanity build
```

`flutter analyze` and a Gradle-cached `flutter build apk` have both been
observed to miss real compile errors that only a clean `flutter test` run
catches (see `ARCHITECTURE.md`). Treat `flutter test` as the authoritative
check. CI (`.github/workflows/ci.yml`) runs `dart format --set-exit-if-changed`,
`flutter analyze`, `flutter test`, and a debug APK build on every push/PR.

iOS build has not been verified on this machine (incomplete Xcode Command
Line Tools install, no full Xcode). The Android target is the verified
baseline.

## Project docs

- `ARCHITECTURE.md` — how the shared framework, theming, settings, and sound
  layers work, and why they're built the way they are.
- `CONTEXT.md` — background for anyone (human or AI) picking this project up
  cold: original intent, constraints, decisions made, and open items.
- `CHANGELOG.md` — notable changes, in Keep-a-Changelog style.
- `store/PLAY_STORE_READINESS.md` / `store/APP_STORE_READINESS.md` — store
  listing copy, visual assets, and submission checklists for each
  platform, with what's ready vs. what still needs a human decision.
- `store/PRIVACY_POLICY.md` — drafted privacy policy (the app collects no
  data); needs to be hosted at a public URL before either store submission.
