import 'package:flutter/services.dart';

import 'settings_store.dart';

/// Shared, tiny sound-effect layer.
///
/// This deliberately uses only Flutter's built-in [SystemSound] and
/// [HapticFeedback] APIs — no bundled audio assets, no audio-player
/// dependency, no network. Three real-audio attempts have been tried and
/// reverted here:
///
/// 1. `audioplayers` — its transitive `path_provider_foundation` →
///    `objective_c` native-asset build step fails on this machine's
///    Command-Line-Tools-only macOS SDK, which also broke `flutter test`
///    outright (this repo's authoritative compile check).
/// 2. `soundpool` — avoids that dependency chain and passes `flutter test`,
///    but its bundled Android Kotlin plugin code references
///    `PluginRegistry.Registrar`, an API removed from the current Flutter
///    Android embedding, so `flutter build apk` fails outright. The
///    package is also marked discontinued on pub.dev.
/// 3. `just_audio` — a currently-maintained, widely-used package — still
///    pulls in `path_provider_foundation` → `objective_c` transitively
///    (via `audio_session`) and fails `flutter test` with the exact same
///    `ld: tapi error: malformed file... unknown architecture` as
///    `audioplayers`. Confirms this isn't a quirk of one abandoned
///    package: essentially any cross-platform Flutter audio plugin with
///    macOS/iOS support depends on `path_provider_foundation` somewhere,
///    and that dependency's native-asset build needs a full Xcode
///    install, not just Command Line Tools, on this machine.
///
/// **Conclusion: this is an environment limitation, not a package-choice
/// problem.** Don't try a fourth pub.dev package expecting a different
/// result — install full Xcode first, then any of the three above should
/// work (re-try `audioplayers` or `just_audio` first; both are actively
/// maintained, unlike `soundpool`). Whatever's tried, verify against BOTH
/// `flutter test` and `flutter build apk` — the `soundpool` attempt is a
/// reminder that passing one doesn't imply the other.
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
