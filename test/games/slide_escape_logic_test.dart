import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:topgames/core/game_level_context.dart';
import 'package:topgames/games/slide_escape/slide_escape_game.dart';

/// Level 1's blocks are built in this fixed order (matching
/// `_LevelSpec.blocks` in slide_escape_game.dart), so the Nth
/// [AnimatedPositioned] in the widget tree always corresponds to the same
/// block: 0 = T (the horizontal target, stops on column 3 because block A
/// blocks it), 1 = A (a vertical block blocking T's escape).
const _targetIndex = 0;
const _blockerIndex = 1;

/// A drag far larger than the board can ever need reliably lands on
/// whichever end of a block's *legal* range the direction implies — the
/// game clamps movement to that range, reproducing the "maximal slide"
/// gesture the level's verified solution assumes.
const _bigSlide = 2000.0;

void main() {
  testWidgets('slide_escape: sliding the blocking piece clear then sliding the '
      'target to the exit reports completion', (tester) async {
    var completed = false;
    int? completedStars;

    await tester.pumpWidget(
      MaterialApp(
        home: SlideEscapeScreen(
          ctx: GameLevelContext(
            gameId: 'slide_escape',
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

    final blocks = find.byType(AnimatedPositioned);
    expect(blocks.evaluate().length, 4, reason: 'level 1 has 4 blocks');

    // Block A is vertical: slide it up out of the target's row.
    await tester.drag(blocks.at(_blockerIndex), const Offset(0, -_bigSlide));
    await tester.pump();
    expect(completed, isFalse);

    // Block T is horizontal: slide it right into the now-clear exit.
    await tester.drag(blocks.at(_targetIndex), const Offset(_bigSlide, 0));
    await tester.pump();

    expect(completed, isTrue);
    expect(completedStars, inInclusiveRange(1, 3));
    expect(find.text('Escaped!'), findsOneWidget);
  });

  testWidgets(
    'slide_escape: an invalid slide is a no-op, and a slide blocked by '
    'another piece stops short instead of reaching the exit',
    (tester) async {
      var completed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: SlideEscapeScreen(
            ctx: GameLevelContext(
              gameId: 'slide_escape',
              level: 1,
              isEndless: false,
              onComplete: ({int stars = 0, int? score}) => completed = true,
              onExit: () {},
            ),
          ),
        ),
      );
      await tester.pump();

      final blocks = find.byType(AnimatedPositioned);

      // The target block is already flush against the left wall: sliding
      // it further left is illegal and must be a true no-op (no move
      // recorded at all).
      await tester.drag(blocks.at(_targetIndex), const Offset(-_bigSlide, 0));
      await tester.pump();
      expect(find.text('Moves: 0'), findsOneWidget);
      expect(completed, isFalse);

      // Sliding the target right *without* first moving the blocker is
      // legal for one cell but then physically stopped by block A — it
      // counts as a move but must not reach the exit.
      await tester.drag(blocks.at(_targetIndex), const Offset(_bigSlide, 0));
      await tester.pump();
      expect(find.text('Moves: 1'), findsOneWidget);
      expect(completed, isFalse);
      expect(find.text('Escaped!'), findsNothing);
    },
  );
}
