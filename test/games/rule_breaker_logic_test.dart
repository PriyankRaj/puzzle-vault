import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:topgames/core/game_level_context.dart';
import 'package:topgames/games/rule_breaker/rule_breaker_game.dart';

Future<void> _tapDirection(WidgetTester tester, IconData icon) async {
  await tester.tap(find.byIcon(icon));
  await tester.pump();
}

void main() {
  testWidgets(
    'rule_breaker: walking onto a flag while FLAG IS WIN is active reports completion',
    (tester) async {
      // Level 1 layout is:
      //   .....
      //   .P...
      //   .....
      //   .gin.
      //   ..F..
      // `g i n` (FLAG IS WIN) is already a formed rule at load time, so the
      // player just needs to walk onto the flag at (row 4, col 2) without
      // disturbing the word-tiles that form the rule. Going right along row
      // 1, down column 4, then left avoids every word-tile entirely.
      var completed = false;
      int? completedStars;

      await tester.pumpWidget(
        MaterialApp(
          home: RuleBreakerScreen(
            ctx: GameLevelContext(
              gameId: 'rule_breaker',
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

      for (var i = 0; i < 3; i++) {
        await _tapDirection(tester, Icons.keyboard_arrow_right_rounded);
      }
      for (var i = 0; i < 3; i++) {
        await _tapDirection(tester, Icons.keyboard_arrow_down_rounded);
      }
      for (var i = 0; i < 2; i++) {
        await _tapDirection(tester, Icons.keyboard_arrow_left_rounded);
      }
      // onComplete fires via a microtask after the winning move.
      await tester.pump();

      expect(
        completed,
        isTrue,
        reason: 'reaching the WIN-flagged flag must report completion',
      );
      expect(completedStars, 3);
    },
  );

  testWidgets(
    'rule_breaker: pushing into a wall that is currently STOP is a no-op',
    (tester) async {
      // Level 4 layout is:
      //   P.#.F
      //   .wis.
      //   .....
      //   .gin.
      // `w i s` (WALL IS STOP) is active from the start, so the wall at
      // (row 0, col 2) blocks the player outright rather than being pushed.
      var completed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: RuleBreakerScreen(
            ctx: GameLevelContext(
              gameId: 'rule_breaker',
              level: 4,
              isEndless: false,
              onComplete: ({int stars = 0, int? score}) => completed = true,
              onExit: () {},
            ),
          ),
        ),
      );

      // First move onto the empty cell right of the player succeeds.
      await _tapDirection(tester, Icons.keyboard_arrow_right_rounded);
      expect(find.text('Moves: 1'), findsOneWidget);

      // Second move attempts to walk into the STOP-flagged wall and must be
      // rejected: the move counter must not advance.
      await _tapDirection(tester, Icons.keyboard_arrow_right_rounded);
      expect(
        find.text('Moves: 1'),
        findsOneWidget,
        reason: 'a move blocked by an active STOP rule must not be counted',
      );
      expect(find.text('Moves: 2'), findsNothing);
      expect(completed, isFalse);
    },
  );
}
