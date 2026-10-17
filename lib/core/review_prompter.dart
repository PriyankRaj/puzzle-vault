import 'package:flutter/foundation.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Asks for a store rating after the player has had a few wins, via the
/// native in-app review sheet (App Store / Play). No custom "do you like us?"
/// pre-prompt — both stores require the system sheet, and they also cap how
/// often it actually appears, so this only decides *when* it's worth asking.
///
/// Rules: first ask on the [firstAskAt]th win, then at most once every
/// [minGap], and never more than [maxAsks] times in total.
class ReviewPrompter {
  static const _winsKey = 'review_wins_v1';
  static const _asksKey = 'review_asks_v1';
  static const _lastAskKey = 'review_last_ask_ms_v1';

  static const firstAskAt = 5;
  static const maxAsks = 3;
  static const minGap = Duration(days: 90);

  /// Call after a genuine success (lesson finished, puzzle solved). Safe to
  /// fire-and-forget: never throws, and does nothing where the review API
  /// isn't available (tests, emulators without Play, desktop).
  static Future<void> recordWin() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final wins = (prefs.getInt(_winsKey) ?? 0) + 1;
      await prefs.setInt(_winsKey, wins);

      if (wins < firstAskAt) return;
      final asks = prefs.getInt(_asksKey) ?? 0;
      if (asks >= maxAsks) return;
      final lastAsk = prefs.getInt(_lastAskKey);
      if (lastAsk != null &&
          DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(lastAsk)) < minGap) {
        return;
      }

      final review = InAppReview.instance;
      if (!await review.isAvailable()) return;

      await prefs.setInt(_asksKey, asks + 1);
      await prefs.setInt(_lastAskKey, DateTime.now().millisecondsSinceEpoch);
      // Let the success screen land before the sheet slides over it.
      await Future<void>.delayed(const Duration(milliseconds: 1500));
      await review.requestReview();
    } catch (e) {
      debugPrint('ReviewPrompter: $e');
    }
  }
}
