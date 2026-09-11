# Architecture

Puzzle Vault is one Flutter app hosting 20 independent mini-games behind a
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
    sound.dart                Sfx (system click + haptic feedback patterns)
    motion.dart                Motion (zero-durations when animations are off)
    widgets/
      game_host.dart          GameHost (wraps every game screen)
      level_select_screen.dart
      result_dialog.dart      showLevelCompleteDialog / showLevelFailedDialog
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
  builder: (context, ctx) => LightsOutScreen(ctx: ctx),
)
```

`lib/games/registry.dart` lists all 20 definitions in display order — this is
the single source of truth for what appears on the home screen.

A game screen receives a `GameLevelContext` (gameId, level, isEndless,
`onComplete(stars)`, `onExit()`) and is otherwise a normal `StatefulWidget`
that owns its own board state. Games don't touch `SharedPreferences`,
navigation, or dialogs directly — they call `ctx.onComplete(...)` /
`ctx.onExit()` and let `GameHost` handle the rest.

## GameHost — the single choke point

`GameHost` (`lib/core/widgets/game_host.dart`) wraps every game screen. It:

- owns the current level/attempt counter and remounts the game via a changing
  `ValueKey('${def.id}_${level}_$attempt')` on retry,
- shows `showLevelCompleteDialog` / `showLevelFailedDialog` from
  `result_dialog.dart` when the game calls back,
- persists level completion/star count through `ProgressStore`,
- is wrapped in `ValueListenableBuilder<bool>` on
  `AppSettingsStore.instance.isDarkMode` so a theme toggle reaches every game
  immediately, not just on next navigation.

Because `GameHost` is the only place all 20 games funnel through, this is
also the only place that had to be touched to make dark/light mode reach
every game — no per-game plumbing needed.

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

## Persistence

`ProgressStore` (`lib/core/progress_store.dart`) is a `SharedPreferences`-backed
singleton keyed by game id + level, storing completion and star count.
`resetAll(gameIds)` iterates and clears every registered game.

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
5. Register it in `lib/games/registry.dart`.
6. Add it to `test/game_smoke_test.dart` coverage (it's automatic — the smoke
   test iterates `gameRegistry`) and re-run `flutter test`.
