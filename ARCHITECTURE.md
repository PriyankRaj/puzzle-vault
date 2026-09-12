# Architecture

Puzzle Vault is one Flutter app hosting 19 independent mini-games behind a
shared framework. The framework exists so that theming, settings, sound,
level progression, and win/fail UX are implemented exactly once, and every
game just plugs into it.

## Layers

```
lib/
  app/theme.dart              theme tokens + ThemeData builders
  core/
    game_definition.dart      GameDefinition (static metadata per game)
    game_level_context.dart   GameLevelContext (passed into each game screen)
    progress_store.dart       ProgressStore (per-game/per-level persistence)
    settings_store.dart       AppSettingsStore (dark mode / sound / animations)
    sound.dart                Sfx (generated SFX via soundpool + haptic patterns)
    motion.dart                Motion (zero-durations when animations are off)
    widgets/
      game_host.dart          GameHost (wraps every game screen)
      level_select_screen.dart  in-game level picker (see below)
      result_dialog.dart      LevelCompleteOverlay / showLevelFailedDialog
      game_actions.dart       gameActions() — shared AppBar actions
      info_tip_button.dart    InfoTipButton ("How to play" ⓘ dialog)
      swipe_area.dart         SwipeArea — full-area, distance-based swipe detector
  games/<game_id>/<game_id>_game.dart   one file per game
  home/home_screen.dart
  settings/settings_screen.dart
  main.dart
```

## The game contract

Every game registers a single `GameDefinition` (`lib/core/game_definition.dart`):

```dart
GameDefinition(
  id: 'lights_out',          // stable, snake_case, used as persistence key — never rename
  title: 'Tile Toggle',
  tagline: 'Toggle tiles until the whole grid goes dark',
  icon: Icons.lightbulb_outline,
  tint: GameTint(...),
  mode: GameMode.levels,     // or GameMode.endless
  levelCount: 15,            // capped at 15 by product requirement
  helpText: 'Tap any tile to flip it and its neighbours...',
  builder: (context, ctx) => LightsOutScreen(ctx: ctx),
)
```

`lib/games/registry.dart` lists all 19 definitions in display order — this is
the single source of truth for what appears on the home screen.

A game screen receives a `GameLevelContext` (gameId, level, isEndless,
`onComplete(stars)`, `onExit()`, `onOpenLevelSelect`) and is otherwise a
normal `StatefulWidget` that owns its own board state. Games don't touch
`SharedPreferences`, navigation, or dialogs directly — they call
`ctx.onComplete(...)` / `ctx.onExit()` / `ctx.onOpenLevelSelect?.call()` and
let `GameHost` handle the rest.

## Home → GameHost, and the in-game level picker

`HomeScreen` pushes `GameHost` directly on tap, at
`ProgressStore.instance.unlockedLevel(def.id)` for `GameMode.levels` games
(or level 1 for endless) — it no longer stops at `LevelSelectScreen` first.
`LevelSelectScreen` still exists, but only as a picker `GameHost` itself
opens via the "Levels" action (see `gameActions()` below): it's pushed as a
route on top of the already-open `GameHost`, and simply
`Navigator.pop(level)`s with the chosen level number instead of pushing a
nested `GameHost` — `GameHost._openLevelSelect()` awaits that pop and
applies the level to itself.

## GameHost — the single choke point

`GameHost` (`lib/core/widgets/game_host.dart`) wraps every game screen. It:

- owns the current level/attempt counter and remounts the game via a changing
  `ValueKey('${def.id}_${level}_$attempt')` on retry,
- shows a `LevelCompleteOverlay` (`result_dialog.dart`) — a non-modal
  `Stack` overlay, not a dialog route — over the still-visible solved board
  when the game calls `onComplete`, or `showLevelFailedDialog` (still a
  modal `AlertDialog`, since a failed attempt has no solved board worth
  keeping visible) on failure,
- persists level completion/star count through `ProgressStore`,
- is wrapped in `ValueListenableBuilder<bool>` on
  `AppSettingsStore.instance.isDarkMode` so a theme toggle reaches every game
  immediately, not just on next navigation.

Because `GameHost` is the only place all 19 games funnel through, this is
also the only place that had to be touched to make dark/light mode reach
every game — no per-game plumbing needed.

**Gotcha the overlay change specifically had to avoid:** since
`LevelCompleteOverlay` is a `Stack` child, not a dialog route, its
Next/Retry callbacks must only `setState` to hide it — they must never call
`Navigator.pop()` for that (there's no dialog route to pop). Only `onMenu`
actually leaves the screen, with a single `Navigator.pop()`. An earlier
dialog-based version popped once for the dialog and once for the route on
every button; porting that double-pop to the overlay unchanged would have
over-popped past the intended screen.

## Theming

`AppTheme` (`lib/app/theme.dart`) exposes colors as `static Color get`
(not `static const`) keyed off a static `_brightness` field toggled via
`AppTheme.setBrightness(...)`. `AppTheme.dark({animate})` /
`AppTheme.light({animate})` are methods, not getters, that build a
`ThemeData` — when `animate == false` the `pageTransitionsTheme` swaps in an
`_InstantPageTransitionsBuilder` (a `PageTransitionsBuilder` that returns
`child` with no animation).

**Important gotcha:** static getters are not tied into Flutter's widget
dependency graph — a widget only re-reads `AppTheme.xxx` when *something*
causes it to rebuild. `HomeScreen`, `LevelSelectScreen`, `SettingsScreen`, and
`GameHost` are each wrapped in `ValueListenableBuilder<bool>` listening to
`AppSettingsStore.instance.isDarkMode` specifically to force that rebuild.
If you add a new always-mounted top-level screen, wrap it the same way or it
will show a stale palette until the next navigation.

## Settings

`AppSettingsStore` (`lib/core/settings_store.dart`) is a singleton holding
three `ValueNotifier<bool>`: `isDarkMode`, `soundEnabled`, `animationsEnabled`,
persisted via `SharedPreferences` under `settings_dark_mode`,
`settings_sound_enabled`, `settings_animations_enabled`. `main.dart` awaits
`AppSettingsStore.instance.init()` before `runApp`.

`SettingsScreen` (`lib/settings/settings_screen.dart`) exposes toggles for
all three, plus a "Reset all progress" action that shows a confirmation
`AlertDialog` and, on confirm, calls
`ProgressStore.instance.resetAll(gameRegistry.map((d) => d.id))`.

## Motion and sound

- `Motion.ms(int milliseconds)` (`lib/core/motion.dart`) returns the given
  duration, or `Duration.zero` when `animationsEnabled.value` is false. Used
  to gate decorative `Animated*` widget durations inside individual games
  without per-game settings plumbing. Do **not** use it for physics-simulation
  ticker loops — only for widget-level animation durations.
- Three games (`physics_logic`, `ragdoll_trials`, `snip_logic`) also gate a
  looping pulse `AnimationController`: it's created unconditionally but only
  `.repeat(reverse: true)` when animations are enabled; otherwise its value
  is pinned to `1`.
- `Sfx` (`lib/core/sound.dart`) is deliberately dependency-free: it plays
  `SystemSound.play(SystemSoundType.click)` plus varied `HapticFeedback`
  patterns (`tap()`, `success()`, `error()`), gated on
  `AppSettingsStore.instance.soundEnabled`. See "Sound is intentionally thin"
  in `CONTEXT.md` for why this isn't real synthesized audio.

## Shared game actions (How-to-play, Hint, Levels, Reset)

`gameActions()` (`lib/core/widgets/game_actions.dart`) returns the list of
`IconButton`s every game spreads into its own `AppBar.actions`: an optional
Hint button (only if the game passes `onHint`), the "How to play"
`InfoTipButton` (`lib/core/widgets/info_tip_button.dart`, an ⓘ icon-button
showing an `AlertDialog` with `def.helpText`), a "Levels" button (only when
`ctx.onOpenLevelSelect != null`, i.e. `GameMode.levels` games), and "Reset
progress" (`confirmAndResetGame`, also in this file).

This used to live only on `LevelSelectScreen`'s AppBar, back when every
level-based game was forced through that screen before `GameHost`. Now that
`HomeScreen` jumps straight into `GameHost` (see below), each game owns its
own copy of these actions instead. Deliberately **not** implemented by
having `GameHost` impose a shared `Scaffold` above every game — that would
change the widget tree above all 19 games at once and risk breaking
index-based test finders (e.g. `test/games/tactics_grid_logic_test.dart`'s
`_cellGestureDetectorOffset`). Each game still builds its own `Scaffold`;
`gameActions()` is just spread into its existing `AppBar.actions`.

Hint logic itself lives in each game's own `State`, since it needs live
board state — `gameActions()` only supplies the button. Most games compute a
genuine "correct next move" from data they already hold (a stored solution,
a solved-rotation delta, a GF(2) solve over the toggle matrix, etc.); a few
physics/strategy games (`physics_logic`, `snip_logic`, `ragdoll_trials`,
`tactics_grid`) give a directional/heuristic nudge instead, since a real
solver for those was out of scope for this pass.

If you add a 20th game, add `helpText` to its `GameDefinition` and call
`gameActions(...)` in its `AppBar.actions`, passing `onHint` if you can
give it a real hint.

## Persistence

`ProgressStore` (`lib/core/progress_store.dart`) is a `SharedPreferences`-backed
singleton keyed by game id + level, storing completion and star count.
`resetGame(gameId)` clears one game; `resetAll(gameIds)` iterates and calls
it for every registered game. Settings > "Reset all progress" uses
`resetAll`; every game's own "Reset progress" action (via `gameActions()`,
see above) uses `confirmAndResetGame` → `resetGame` scoped to just that
game's id. `LevelSelectScreen` also keeps its own reset action for players
who reach it directly.

## CI

`.github/workflows/ci.yml` runs on every push/PR: `dart format
--set-exit-if-changed .`, `flutter analyze`, `flutter test`, then (in a
second job, gated on the first passing) a debug APK build. This is the
automated version of the "Verifying changes" steps in `README.md` — if you
add a game and its test file, this is what actually guarantees the smoke
test, logic test, and registry-completeness check (see below) all still
pass before anything merges.

## Testing

- `test/widget_test.dart` — home screen renders, title is correct.
- `test/game_smoke_test.dart` — boots every registered game through
  `GameHost`, asserts no exception, asserts unique ids, asserts
  `levelCount <= 15` for every `GameMode.levels` game.
- `test/theme_propagation_test.dart` — proves a theme toggle reaches
  `SettingsScreen` tiles and a live `GameHost`-wrapped game; proves
  `Motion.ms` zeroes durations; proves a live game's `AnimatedContainer`
  duration actually becomes zero; proves `pageTransitionsTheme` swaps builder
  type.
- `test/reset_progress_test.dart` — `ProgressStore.resetAll` unit test, plus
  a full tap-through of the Settings reset-confirmation flow.
- `test/games/<id>_logic_test.dart` — one per game, driving *real* gameplay
  logic (not just "boots without crashing"). The common pattern: construct
  the game's screen widget directly (not through `GameHost`) with a
  hand-built `GameLevelContext` whose `onComplete`/`onExit` are captured in
  local test variables, then drive it through its actual tap/drag interface
  to a genuine win, asserting the callback fires — and separately assert an
  incomplete/incorrect interaction does *not* falsely fire it. For games with
  a seeded `Random()` level generator, the test replicates that generation
  algorithm locally (same seed formula, same call order) to know exactly
  what to tap/drag; see `test/games/lights_out_logic_test.dart` for the
  reference example. The one endless game (`merge2048`) uses an unseeded
  RNG for tile spawns, so its test asserts invariants (score accounting, an
  oracle-predicted merge outcome) across many real swipes instead of a
  scripted win.
- `test/game_smoke_test.dart` also asserts every `gameRegistry` entry has a
  non-empty `helpText` and a corresponding `test/games/<id>_logic_test.dart`
  file — a 20th game can't silently ship without both.

**Authoritative check:** run `flutter test`, not just `flutter analyze` or a
possibly Gradle-cached `flutter build apk`. Both of the latter have been
observed to miss real `const`-expression compile errors that only a fresh
`flutter test` CFE compile catches — see `CONTEXT.md` for the specific
incident.

## Adding a new game

1. Create `lib/games/<id>/<id>_game.dart` with a top-level
   `final GameDefinition <id>Definition = GameDefinition(...)`.
2. Keep `levelCount <= 15` if `mode: GameMode.levels`.
3. Use `Motion.ms(...)` for any decorative `Animated*` widget duration instead
   of a bare `Duration(...)`, so the animations toggle covers it.
4. Call `Sfx.tap()` / rely on `GameHost`'s `Sfx.success()`/`Sfx.error()` for
   feedback rather than adding a new sound path.
5. Spread `gameActions(context: context, def: <id>Definition, ctx: ctx,
   onHint: ...)` into your `AppBar.actions`. Pass `onHint` if you can give a
   real "reveal a correct move" hint from data your game already holds
   (see the Hint paragraph above for the pattern); otherwise a directional
   nudge is an acceptable fallback — just don't oversell it as more than that.
6. Register it in `lib/games/registry.dart`.
7. Add it to `test/game_smoke_test.dart` coverage (it's automatic — the smoke
   test iterates `gameRegistry`) and re-run `flutter test`.
