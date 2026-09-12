import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:topgames/core/game_level_context.dart';
import 'package:topgames/games/dungeon_logic/dungeon_logic_game.dart';

/// Level 1's room (see `_levels[0]` in dungeon_logic_game.dart):
///   P.R..
///   .....
///   ..#..
///   ..r.E
///   .....
/// Hand-verified 9-move solve recorded in that file's comment:
/// R,R,D,R,D,D,L,R,R — picks up the 'R' key at (0,2), then unlocks/passes
/// the matching 'r' door at (3,2), then reaches the 'E' exit at (3,4).
const List<String> _level1Solution = [
  'R',
  'R',
  'D',
  'R',
  'D',
  'D',
  'L',
  'R',
  'R',
];

Future<void> _press(WidgetTester tester, String direction) async {
  final icon = switch (direction) {
    'U' => Icons.keyboard_arrow_up_rounded,
    'D' => Icons.keyboard_arrow_down_rounded,
    'L' => Icons.keyboard_arrow_left_rounded,
    'R' => Icons.keyboard_arrow_right_rounded,
    _ => throw ArgumentError('unknown direction $direction'),
  };
  await tester.tap(find.byIcon(icon));
  await tester.pump();
}

void main() {
  testWidgets(
    'dungeon_logic: replaying the verified solve picks up the key, opens the door, and reaches the exit',
    (tester) async {
      var completed = false;
      int? completedStars;

      await tester.pumpWidget(
        MaterialApp(
          home: DungeonLogicScreen(
            ctx: GameLevelContext(
              gameId: 'dungeon_logic',
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

      for (final move in _level1Solution) {
        await _press(tester, move);
      }
      await tester.pump();

      expect(
        completed,
        isTrue,
        reason:
            'the hand-verified 9-move solve should pick up the key, clear the door, and reach the exit',
      );
      // The solve uses exactly the level's recorded par (9 moves), so it
      // should earn full stars.
      expect(completedStars, 3);
    },
  );

  testWidgets(
    'dungeon_logic: walking into a locked door without the matching key is blocked',
    (tester) async {
      var completed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: DungeonLogicScreen(
            ctx: GameLevelContext(
              gameId: 'dungeon_logic',
              level: 1,
              isEndless: false,
              onComplete: ({int stars = 0, int? score}) => completed = true,
              onExit: () {},
            ),
          ),
        ),
      );

      // Walk down the left column to row 3, then attempt to step onto the
      // 'r' door at (3,2) without ever having picked up the 'R' key
      // (which sits at (0,2), never visited by this path).
      await _press(tester, 'D'); // (0,0) -> (1,0)
      await _press(tester, 'D'); // (1,0) -> (2,0)
      await _press(tester, 'D'); // (2,0) -> (3,0)
      await _press(tester, 'R'); // (3,0) -> (3,1)
      await _press(
        tester,
        'R',
      ); // attempt (3,1) -> (3,2) 'r': blocked, no key held

      expect(
        find.text('Moves: 4'),
        findsOneWidget,
        reason:
            'the blocked move into the locked door must not count as a move',
      );
      expect(completed, isFalse);
    },
  );
}
