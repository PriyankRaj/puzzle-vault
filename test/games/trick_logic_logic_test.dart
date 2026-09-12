import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:topgames/core/game_level_context.dart';
import 'package:topgames/games/trick_logic/trick_logic_game.dart';

/// Level 2's instruction: "Check the box below ONLY IF 7 is an even
/// number." Since 7 is odd, the "obvious" action (ticking the checkbox
/// before confirming) is the trap — the real solution is to leave it
/// unchecked and press Confirm.
void main() {
  testWidgets(
    'trick_logic: following the instruction literally (leaving the box '
    'unchecked, since 7 is odd) and confirming reports completion',
    (tester) async {
      var completed = false;
      int? completedStars;

      await tester.pumpWidget(
        MaterialApp(
          home: TrickLogicScreen(
            ctx: GameLevelContext(
              gameId: 'trick_logic',
              level: 2,
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

      await tester.tap(find.widgetWithText(ElevatedButton, 'Confirm'));
      await tester.pump();

      expect(completed, isTrue);
      expect(completedStars, 3);
    },
  );

  testWidgets(
    'trick_logic: falling for the obvious trap (checking the box, since 7 '
    "looks like it 'should' be checked) does not report completion",
    (tester) async {
      var completed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: TrickLogicScreen(
            ctx: GameLevelContext(
              gameId: 'trick_logic',
              level: 2,
              isEndless: false,
              onComplete: ({int stars = 0, int? score}) => completed = true,
              onExit: () {},
            ),
          ),
        ),
      );

      await tester.tap(find.byType(Checkbox));
      await tester.pump();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Confirm'));
      await tester.pump();

      expect(completed, isFalse);
      // The trap shows a hint via SnackBar rather than completing.
      expect(
        find.text('7 is odd — the box should stay unchecked.'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'trick_logic: level 7 requires tapping the star then the moon, in that '
    'exact order — tapping the moon first does nothing, and only the '
    'correct order completes the level',
    (tester) async {
      var completed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: TrickLogicScreen(
            ctx: GameLevelContext(
              gameId: 'trick_logic',
              level: 7,
              isEndless: false,
              onComplete: ({int stars = 0, int? score}) => completed = true,
              onExit: () {},
            ),
          ),
        ),
      );

      // Icons are laid out moon-then-star in the widget tree (star tap
      // handler is wired to the second IconButton).
      final moonButton = find.byIcon(Icons.nightlight_round);
      final starButton = find.byIcon(Icons.star_rounded);

      // Wrong order: moon before star must not complete the level.
      await tester.tap(moonButton);
      await tester.pump();
      expect(completed, isFalse);

      // Correct order: star then moon completes it.
      await tester.tap(starButton);
      await tester.pump();
      await tester.tap(moonButton);
      await tester.pump();

      expect(completed, isTrue);
    },
  );

  testWidgets('trick_logic: level 10 drag-and-drop still works inside the '
      'SingleChildScrollView — dragging the smallest square onto the target '
      'completes the level, and dragging a larger one shows the hint instead', (
    tester,
  ) async {
    var completed = false;

    await tester.pumpWidget(
      MaterialApp(
        home: TrickLogicScreen(
          ctx: GameLevelContext(
            gameId: 'trick_logic',
            level: 10,
            isEndless: false,
            onComplete: ({int stars = 0, int? score}) => completed = true,
            onExit: () {},
          ),
        ),
      ),
    );

    // Draggable squares are sized 70, 40, 55 in source order — the second
    // one (40) is the smallest and is the correct answer.
    final draggables = find.byType(Draggable<double>);
    expect(draggables, findsNWidgets(3));
    final target = find.byType(DragTarget<double>);

    // Dragging the largest square onto the target should not complete
    // the level, and should surface the "too big" hint.
    await tester.drag(
      draggables.at(0),
      tester.getCenter(target) - tester.getCenter(draggables.at(0)),
    );
    await tester.pumpAndSettle();
    expect(completed, isFalse);
    expect(find.text('Too big — drag the SMALLEST square.'), findsOneWidget);

    // Dragging the smallest square onto the target completes the level.
    await tester.drag(
      draggables.at(1),
      tester.getCenter(target) - tester.getCenter(draggables.at(1)),
    );
    await tester.pumpAndSettle();
    expect(completed, isTrue);
  });
}
