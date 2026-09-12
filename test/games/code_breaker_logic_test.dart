import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:topgames/core/game_level_context.dart';
import 'package:topgames/games/code_breaker/code_breaker_game.dart';

/// Replicates the private secret-generation algorithm from
/// `_CodeBreakerScreenState._startLevel` (same `4000 + level` seed formula,
/// same peg/color-count scaling, same call order) so this test can drive a
/// real win through the public widget instead of reaching into private
/// state. If the in-game generation algorithm changes, update this to match.
List<int> _secretFor(int level) {
  final pegCount = level <= 5
      ? 4
      : level <= 10
      ? 4
      : 5;
  final colorCount = level <= 5
      ? 4
      : level <= 10
      ? 5
      : 6;
  final rng = Random(4000 + level);
  return List.generate(pegCount, (_) => rng.nextInt(colorCount));
}

Future<void> _submitGuess(WidgetTester tester, List<int> colors) async {
  for (final colorIndex in colors) {
    await tester.tap(find.byKey(ValueKey('palette_$colorIndex')));
    await tester.pump();
  }
  await tester.tap(find.byKey(const ValueKey('submit_guess')));
  await tester.pump();
}

void main() {
  testWidgets(
    'code_breaker: guessing the exact secret sequence reports completion',
    (tester) async {
      const level = 1;
      final secret = _secretFor(level);
      var completed = false;
      int? completedStars;

      await tester.pumpWidget(
        MaterialApp(
          home: CodeBreakerScreen(
            ctx: GameLevelContext(
              gameId: 'code_breaker',
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

      await _submitGuess(tester, secret);
      // onComplete fires via a microtask.
      await tester.pump();

      expect(
        completed,
        isTrue,
        reason: 'submitting the exact secret sequence should win the level',
      );
      expect(completedStars, inInclusiveRange(1, 3));
    },
  );

  testWidgets(
    'code_breaker: a wrong guess does not falsely report completion and '
    'updates the feedback history',
    (tester) async {
      const level = 1;
      final secret = _secretFor(level);
      // Flip every peg to a different color so this guess is guaranteed
      // wrong everywhere (colorCount is always >= 2, so (c + 1) % colorCount
      // never equals c).
      const colorCount = 4; // level 1 uses a 4-color palette
      final wrongGuess = secret.map((c) => (c + 1) % colorCount).toList();
      var completed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: CodeBreakerScreen(
            ctx: GameLevelContext(
              gameId: 'code_breaker',
              level: level,
              isEndless: false,
              onComplete: ({int stars = 0, int? score}) => completed = true,
              onExit: () {},
            ),
          ),
        ),
      );

      await _submitGuess(tester, wrongGuess);

      expect(completed, isFalse);
      expect(find.text('Guesses left: 9'), findsOneWidget);
      // A fresh, empty guess row is ready for the next attempt.
      expect(find.text('Your guesses will appear here'), findsNothing);
    },
  );

  testWidgets(
    'code_breaker: running out of guesses without winning shows the failed '
    'dialog instead of completing',
    (tester) async {
      const level = 1;
      final secret = _secretFor(level);
      const colorCount = 4;
      final wrongGuess = secret.map((c) => (c + 1) % colorCount).toList();
      var completed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: CodeBreakerScreen(
            ctx: GameLevelContext(
              gameId: 'code_breaker',
              level: level,
              isEndless: false,
              onComplete: ({int stars = 0, int? score}) => completed = true,
              onExit: () {},
            ),
          ),
        ),
      );

      for (var i = 0; i < 10; i++) {
        await _submitGuess(tester, wrongGuess);
      }
      // Sfx.error() schedules a delayed second haptic pulse; let it resolve
      // before the test ends, or the pending-timer check fails the test.
      await tester.pump(const Duration(milliseconds: 100));

      expect(completed, isFalse);
      expect(find.text('Try again'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Retry'), findsOneWidget);
    },
  );
}
