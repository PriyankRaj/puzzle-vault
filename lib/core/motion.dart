import 'settings_store.dart';

/// Shared helper for decorative UI animation durations (tile moves, pop-ins,
/// dialog transitions). Every game's `Animated*` widgets should route their
/// duration through this so the Settings > Animations toggle genuinely
/// turns them off app-wide, without each game needing its own flag.
///
/// Deliberately NOT used for physics-simulation tick loops (e.g. the
/// gravity/collision games) — those durations drive gameplay itself, not
/// decoration, and must keep running regardless of this setting.
class Motion {
  Motion._();

  static bool get _enabled => AppSettingsStore.instance.animationsEnabled.value;

  static Duration ms(int milliseconds) =>
      _enabled ? Duration(milliseconds: milliseconds) : Duration.zero;
}
