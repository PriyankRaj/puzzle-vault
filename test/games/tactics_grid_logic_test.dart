import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:topgames/core/game_level_context.dart';
import 'package:topgames/games/tactics_grid/tactics_grid_game.dart';

/// Drives real turn-based battle logic through the public grid taps and
/// the "End Turn" button (never reaching into private state), following
/// the hand-traced winning strategy documented above level 1 in
/// tactics_grid_game.dart: 6x6 grid, Guardian(5,0) + Marksman(5,5) vs a
/// single Grunt(0,2) with 8hp/atk3.
///
/// T1: select Marksman, move it from (5,5) to (3,5) (Chebyshev distance 3
/// from the Grunt, within Marksman's range 3), then attack the Grunt for
/// 4 (8 -> 4hp). End the turn without moving Guardian (irrelevant to the
/// win condition). The deterministic enemy AI cannot reach attack range
/// this turn (nearest-then-weakest targeting picks Marksman, but closing
/// the Chebyshev-3 gap needs more than its move-2 budget), so it just
/// repositions — no damage taken, consistent with the source comment.
///
/// T2: with the Grunt now within Marksman's range 3, select Marksman
/// again and attack directly (no move needed) for another 4 damage,
/// dropping the Grunt to 0hp and winning.
/// The board's `GestureDetector`s are not the only ones in the widget tree:
/// the AppBar's "Give up" `TextButton` renders one `GestureDetector` ahead
/// of the grid (verified by locating a known unit's icon and checking its
/// ancestor's position among all `GestureDetector`s), so cell indices need
/// a `+1` offset.
const _cellGestureDetectorOffset = 1;

Future<void> _tapCell(
  WidgetTester tester,
  int row,
  int col,
  int gridWidth,
) async {
  final index = row * gridWidth + col + _cellGestureDetectorOffset;
  await tester.tap(find.byType(GestureDetector).at(index));
  await tester.pump();
}

void main() {
  testWidgets(
    'tactics_grid: the hand-traced level-1 winning sequence defeats the enemy and completes',
    (tester) async {
      int? completedStars;
      var completed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: TacticsGridScreen(
            ctx: GameLevelContext(
              gameId: 'tactics_grid',
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
      await tester.pump();

      const gridWidth = 6;

      // Turn 1: select Marksman (5,5), move to (3,5), attack Grunt at (0,2).
      await _tapCell(tester, 5, 5, gridWidth);
      await _tapCell(tester, 3, 5, gridWidth);
      await _tapCell(tester, 0, 2, gridWidth);

      expect(
        completed,
        isFalse,
        reason: 'a single 4-damage hit on 8hp should not yet win',
      );

      // End the turn (Guardian never acts — irrelevant to the win condition)
      // and let the enemy phase resolve (fires after a 400ms delay).
      await tester.tap(find.widgetWithText(ElevatedButton, 'End Turn'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(
        completed,
        isFalse,
        reason: 'the Grunt cannot reach attack range on turn 1',
      );

      // Turn 2: select Marksman again (still at (3,5)) and attack. The
      // deterministic AI's best repositioning move brings the Grunt within
      // Chebyshev distance 2 of (3,5) — well inside Marksman's range 3 — at
      // (1,3), so no further move is needed before attacking.
      await _tapCell(tester, 3, 5, gridWidth);
      await _tapCell(tester, 1, 3, gridWidth);
      // onComplete fires via a microtask.
      await tester.pump();

      expect(
        completed,
        isTrue,
        reason:
            'the second 4-damage hit drops the 4hp Grunt to 0 and should '
            'defeat the only enemy, winning the battle',
      );
      expect(completedStars, inInclusiveRange(1, 3));
    },
  );

  testWidgets(
    'tactics_grid: a single non-decisive attack does not end the battle prematurely',
    (tester) async {
      var completed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: TacticsGridScreen(
            ctx: GameLevelContext(
              gameId: 'tactics_grid',
              level: 1,
              isEndless: false,
              onComplete: ({int stars = 0, int? score}) => completed = true,
              onExit: () {},
            ),
          ),
        ),
      );
      await tester.pump();

      const gridWidth = 6;

      // Same opening move+attack as the winning sequence, landing exactly
      // one 4-damage hit on the Grunt's 8hp — not remotely lethal on its
      // own.
      await _tapCell(tester, 5, 5, gridWidth);
      await _tapCell(tester, 3, 5, gridWidth);
      await _tapCell(tester, 0, 2, gridWidth);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(completed, isFalse);
    },
  );
}
