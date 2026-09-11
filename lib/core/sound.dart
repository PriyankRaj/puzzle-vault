import 'package:flutter/services.dart';

import 'settings_store.dart';

/// Shared, tiny sound-effect layer.
///
/// This deliberately uses only Flutter's built-in [SystemSound] and
/// [HapticFeedback] APIs — no bundled audio assets, no audio-player
/// dependency, no network. An `audioplayers`-based version with real
/// synthesized tones was tried and reverted: on this machine the plugin's
/// transitive `path_provider_foundation` → `objective_c` native-asset
/// build step fails against the installed (Command-Line-Tools-only)
/// macOS SDK, which also broke `flutter test` outright. Revisit once a
/// full Xcode install is available to build/verify it properly.
///
/// Each event gets its own short haptic *pattern* (not just a single
/// pulse) so tap/success/error feel distinct even without custom audio.
/// Every call is a no-op when Sound is off in Settings.
class Sfx {
  Sfx._();

  static bool get _enabled => AppSettingsStore.instance.soundEnabled.value;

  /// A light tap/selection sound — level tiles, home cards, toggles.
  static void tap() {
    if (!_enabled) return;
    SystemSound.play(SystemSoundType.click);
    HapticFeedback.selectionClick();
  }

  /// Positive feedback — level complete, puzzle solved. A quick two-pulse
  /// pattern reads as more "positive" than a single flat impact.
  static void success() {
    if (!_enabled) return;
    SystemSound.play(SystemSoundType.click);
    HapticFeedback.lightImpact();
    Future.delayed(const Duration(milliseconds: 70), () {
      if (_enabled) HapticFeedback.mediumImpact();
    });
  }

  /// Negative feedback — mistake, failed attempt, invalid move. A double
  /// heavy pulse reads as a "buzz" rather than a single generic thud.
  static void error() {
    if (!_enabled) return;
    HapticFeedback.heavyImpact();
    Future.delayed(const Duration(milliseconds: 90), () {
      if (_enabled) HapticFeedback.heavyImpact();
    });
  }
}
