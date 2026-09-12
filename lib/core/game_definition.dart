import 'package:flutter/material.dart';

import '../app/theme.dart';
import 'game_level_context.dart';

/// Whether a game is played level-by-level (with a level-select screen) or
/// as a single endless/free-play session.
enum GameMode { levels, endless }

/// Static metadata + entry point for one mini-game. Every game in the app
/// registers exactly one of these in `lib/games/registry.dart`.
class GameDefinition {
  const GameDefinition({
    required this.id,
    required this.title,
    required this.tagline,
    required this.icon,
    required this.tint,
    required this.mode,
    this.levelCount = 1,
    required this.helpText,
    required this.builder,
  });

  /// Stable, unique, snake_case identifier. Used as the persistence key
  /// prefix, so it must never change once a game ships.
  final String id;

  final String title;

  /// One short line shown on the home-screen card.
  final String tagline;

  final IconData icon;

  final GameTint tint;

  final GameMode mode;

  /// Number of levels when [mode] is [GameMode.levels]. Capped at 15 per
  /// product requirement. Ignored for endless games.
  final int levelCount;

  /// Plain-language "how to play" instructions shown from an info tip
  /// (level select for [GameMode.levels] games, in-game for
  /// [GameMode.endless] games). Keep it short — a few sentences.
  final String helpText;

  /// Builds the gameplay screen for a given [GameLevelContext]. For endless
  /// games this is called once with `level == 1`.
  final Widget Function(BuildContext context, GameLevelContext ctx) builder;
}
