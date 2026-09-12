import 'package:flutter/material.dart';

/// Handed to every gameplay screen so it can report outcomes without
/// knowing anything about navigation or persistence.
class GameLevelContext {
  const GameLevelContext({
    required this.gameId,
    required this.level,
    required this.isEndless,
    required this.onComplete,
    required this.onExit,
    this.onOpenLevelSelect,
  });

  final String gameId;

  /// 1-based level index. Always 1 for endless games.
  final int level;

  final bool isEndless;

  /// Call when the player finishes the level/run successfully.
  /// [stars] is 0-3 (ignored for endless games). [score] is an optional
  /// numeric score tracked as a best-score for endless games.
  final void Function({int stars, int? score}) onComplete;

  /// Call to let the player bail out back to level-select / home.
  final VoidCallback onExit;

  /// Opens the level picker without leaving the game screen. Null for
  /// endless games (there is nothing to pick). Games wire this into their
  /// own AppBar via `gameActions` rather than requiring a level-select
  /// screen before every game — see `lib/core/widgets/game_actions.dart`.
  final VoidCallback? onOpenLevelSelect;
}
