import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:topgames/core/game_level_context.dart';
import 'package:topgames/games/impossible_paths/impossible_paths_game.dart';

/// Level 1's path (from the private `_snakePath(3, 4, 0)` / `_levels[0]`
/// definition) visits grid cells (row, col):
///   (0,0) start -> (0,1) -> (0,2) -> (0,3) -> (1,3) -> (1,2) -> (1,1) ->
///   (1,0) -> (2,0) goal
/// on a 4x4 grid (crossAxisCount 4), so a cell's GestureDetector index is
/// `row * 4 + col`. Each tappable cell's initial rotation offset is
/// `(gridIndex * 2 + level) % 4` steps away from its solved rotation, and
/// every tap advances rotation by one step, so the number of taps needed to
/// bring a cell back to its solved rotation is `(4 - offset) % 4`. Working
/// through that formula for level 1 (see the algorithm in
/// `impossible_paths_game.dart`) gives the tap counts below. If the level
/// generation algorithm changes, update this to match.
const List<(int gridIndex, int tapsToSolve)> _level1SolveTaps = [
  (1, 1), // (0,1)
  (2, 3), // (0,2)
  (3, 1), // (0,3)
  (7, 1), // (1,3)
  (6, 3), // (1,2)
  (5, 1), // (1,1)
  (4, 3), // (1,0)
];

void main() {
  testWidgets(
    'impossible_paths: rotating every path tile to its solved orientation connects start to goal and reports completion',
    (tester) async {
      var completed = false;
      int? completedStars;

      await tester.pumpWidget(
        MaterialApp(
          home: ImpossiblePathsScreen(
            ctx: GameLevelContext(
              gameId: 'impossible_paths',
              level: 1,
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

      expect(find.text('Not connected'), findsOneWidget);

      for (final (gridIndex, taps) in _level1SolveTaps) {
        for (var i = 0; i < taps; i++) {
          await tester.tap(find.byType(GestureDetector).at(gridIndex));
          await tester.pump();
        }
      }
      // onComplete fires via a microtask on the tap that completes the path.
      await tester.pump();

      expect(
        completed,
        isTrue,
        reason: 'connecting start to goal must report completion',
      );
      expect(completedStars, inInclusiveRange(1, 3));
    },
  );

  testWidgets(
    'impossible_paths: rotating only one of several required tiles does not connect the path or report completion',
    (tester) async {
      var completed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: ImpossiblePathsScreen(
            ctx: GameLevelContext(
              gameId: 'impossible_paths',
              level: 1,
              isEndless: false,
              onComplete: ({int stars = 0, int? score}) => completed = true,
              onExit: () {},
            ),
          ),
        ),
      );

      // Solve only the first tile in the chain; every other tile on the
      // path remains in its scrambled orientation, so the chain from start
      // to goal must still be broken.
      final (gridIndex, taps) = _level1SolveTaps.first;
      for (var i = 0; i < taps; i++) {
        await tester.tap(find.byType(GestureDetector).at(gridIndex));
        await tester.pump();
      }
      await tester.pump();

      expect(find.text('Not connected'), findsOneWidget);
      expect(
        completed,
        isFalse,
        reason: 'a partially rotated path must not report completion',
      );
    },
  );
}
