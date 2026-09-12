import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:topgames/core/game_level_context.dart';
import 'package:topgames/games/lights_out/lights_out_game.dart';

/// Replicates the private scramble algorithm from `LightsOutScreen.initState`
/// (same seed formula `1000 + level`, same per-iteration call order) so this
/// test can drive a real win condition through the public widget instead of
/// reaching into private state. If the in-game scramble algorithm changes,
/// update this to match.
List<Point<int>> _scrambleSequence(int level, int size) {
  final scrambleCount = 4 + level;
  final rng = Random(1000 + level);
  final taps = <Point<int>>[];
  final grid = List.generate(size, (_) => List.filled(size, false));

  void flip(int r, int c) {
    if (r < 0 || r >= size || c < 0 || c >= size) return;
    grid[r][c] = !grid[r][c];
  }

  void toggle(int r, int c) {
    flip(r, c);
    flip(r - 1, c);
    flip(r + 1, c);
    flip(r, c - 1);
    flip(r, c + 1);
  }

  for (var i = 0; i < scrambleCount; i++) {
    final r = rng.nextInt(size);
    final c = rng.nextInt(size);
    toggle(r, c);
    taps.add(Point(r, c));
  }

  final solved = grid.every((row) => row.every((v) => !v));
  if (solved) {
    toggle(0, 0);
    taps.add(const Point(0, 0));
  }

  return taps;
}

void main() {
  testWidgets(
    'lights_out: replaying the scramble taps solves the board and reports completion',
    (tester) async {
      const level = 1;
      const size = 3; // level 1 uses a 3x3 grid
      int? completedStars;
      var completed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: LightsOutScreen(
            ctx: GameLevelContext(
              gameId: 'lights_out',
              level: level,
              isEndless: false,
              onComplete: ({int stars = 0, int? score}) {
                completed = true;
                completedStars = stars;
              },
              onExit: () {},
            ),
          ),
        ),
      );

      for (final tap in _scrambleSequence(level, size)) {
        final index = tap.x * size + tap.y;
        await tester.tap(find.byType(GestureDetector).at(index));
        await tester.pump();
      }
      // onComplete fires via a microtask.
      await tester.pump();

      expect(
        completed,
        isTrue,
        reason:
            'replaying the exact scramble taps XORs the board back to all-off',
      );
      expect(completedStars, inInclusiveRange(1, 3));
    },
  );

  testWidgets(
    'lights_out: a single tap on a multi-move puzzle does not falsely report completion',
    (tester) async {
      var completed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: LightsOutScreen(
            ctx: GameLevelContext(
              gameId: 'lights_out',
              level: 5, // deeper scramble; one tap cannot solve it
              isEndless: false,
              onComplete: ({int stars = 0, int? score}) => completed = true,
              onExit: () {},
            ),
          ),
        ),
      );

      await tester.tap(find.byType(GestureDetector).first);
      await tester.pump();
      await tester.pump();

      expect(completed, isFalse);
    },
  );
}
