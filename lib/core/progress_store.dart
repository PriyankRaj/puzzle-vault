import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Per-game local progress: highest unlocked level (1-based) and a star
/// rating (0-3) per completed level. Backed by [SharedPreferences] only —
/// no network calls, matching the offline-first requirement.
class ProgressStore {
  ProgressStore._();
  static final ProgressStore instance = ProgressStore._();

  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  SharedPreferences get _p {
    final p = _prefs;
    if (p == null) {
      throw StateError('ProgressStore.init() must be awaited before use');
    }
    return p;
  }

  String _unlockedKey(String gameId) => 'unlocked_$gameId';
  String _starsKey(String gameId) => 'stars_$gameId';
  String _bestScoreKey(String gameId) => 'best_score_$gameId';

  int unlockedLevel(String gameId) => _p.getInt(_unlockedKey(gameId)) ?? 1;

  Future<void> unlockUpTo(String gameId, int level) async {
    final current = unlockedLevel(gameId);
    if (level > current) {
      await _p.setInt(_unlockedKey(gameId), level);
    }
  }

  Map<int, int> starsByLevel(String gameId) {
    final raw = _p.getString(_starsKey(gameId));
    if (raw == null) return {};
    final map = jsonDecode(raw) as Map<String, dynamic>;
    return map.map((k, v) => MapEntry(int.parse(k), v as int));
  }

  Future<void> setStars(String gameId, int level, int stars) async {
    final map = starsByLevel(gameId);
    if ((map[level] ?? 0) < stars) {
      map[level] = stars;
      final encoded = jsonEncode(map.map((k, v) => MapEntry(k.toString(), v)));
      await _p.setString(_starsKey(gameId), encoded);
    }
  }

  int bestScore(String gameId) => _p.getInt(_bestScoreKey(gameId)) ?? 0;

  Future<void> setBestScore(String gameId, int score) async {
    if (score > bestScore(gameId)) {
      await _p.setInt(_bestScoreKey(gameId), score);
    }
  }

  Future<void> resetGame(String gameId) async {
    await _p.remove(_unlockedKey(gameId));
    await _p.remove(_starsKey(gameId));
    await _p.remove(_bestScoreKey(gameId));
  }

  /// Wipes unlocked levels, stars and best scores for every game. Used by
  /// Settings > Reset all progress.
  Future<void> resetAll(Iterable<String> gameIds) async {
    for (final id in gameIds) {
      await resetGame(id);
    }
  }
}
