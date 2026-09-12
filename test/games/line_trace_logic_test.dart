import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:topgames/core/game_level_context.dart';
import 'package:topgames/games/line_trace/line_trace_game.dart';

/// Level 1's verified solution path, copied from the private `_staircase3`
/// constant used by `_levels[0]` in `line_trace_game.dart`: a diagonal
/// staircase from the top-left dot to the bottom-right dot on the 4x4 dot
/// grid that separates the two color-1 cells from the two color-0 cells. If
/// the level data changes, update this to match.
const List<Point<int>> _level1Solution = [
  Point(0, 0),
  Point(1, 0),
  Point(1, 1),
  Point(2, 1),
  Point(2, 2),
  Point(3, 2),
  Point(3, 3),
];

/// A path that only hugs the grid's outer border (down the left edge, then
/// across the bottom edge). Every wall segment it draws lies on the board's
/// boundary, so it carves no interior division at all: the whole panel
/// stays one connected region containing both constraint colors, which must
/// be rejected.
const List<Point<int>> _boundaryHuggingPath = [
  Point(0, 0),
  Point(1, 0),
  Point(2, 0),
  Point(3, 0),
  Point(3, 1),
  Point(3, 2),
  Point(3, 3),
];

Future<void> _dragPath(
  WidgetTester tester,
  List<Point<int>> path,
  Offset origin,
  double cellSize,
) async {
  Offset posFor(Point<int> dot) =>
      origin + Offset(dot.x * cellSize, dot.y * cellSize);

  final gesture = await tester.startGesture(posFor(path.first));
  for (final dot in path.skip(1)) {
    await gesture.moveTo(posFor(dot));
    await tester.pump();
  }
  await gesture.up();
  await tester.pump();
}

void main() {
  testWidgets(
    'line_trace: tracing the verified solution path separates the colors and reports completion',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      var completed = false;
      int? completedStars;

      await tester.pumpWidget(
        MaterialApp(
          home: LineTraceScreen(
            ctx: GameLevelContext(
              gameId: 'line_trace',
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

      final rect = tester.getRect(
        find.ancestor(
          of: find.byType(CustomPaint),
          matching: find.byType(GestureDetector),
        ),
      );
      final cellSize = rect.width / 3; // dotsX = 4 -> 3 cells across

      await _dragPath(tester, _level1Solution, rect.topLeft, cellSize);
      // Completion is reported after a 600ms success-flash delay.
      await tester.pump(const Duration(milliseconds: 700));

      expect(
        completed,
        isTrue,
        reason:
            'a path that fully separates the colors must complete the level',
      );
      expect(
        completedStars,
        3,
        reason: 'a first-try success must earn the maximum star rating',
      );
    },
  );

  testWidgets(
    'line_trace: a path that fails to separate the colors is rejected and never reports completion',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      var completed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: LineTraceScreen(
            ctx: GameLevelContext(
              gameId: 'line_trace',
              level: 1,
              isEndless: false,
              onComplete: ({int stars = 0, int? score}) => completed = true,
              onExit: () {},
            ),
          ),
        ),
      );

      final rect = tester.getRect(
        find.ancestor(
          of: find.byType(CustomPaint),
          matching: find.byType(GestureDetector),
        ),
      );
      final cellSize = rect.width / 3;

      await _dragPath(tester, _boundaryHuggingPath, rect.topLeft, cellSize);

      // The failed attempt is flagged (and counted) synchronously, before
      // the board resets.
      expect(find.text('Attempts: 1'), findsOneWidget);
      expect(completed, isFalse);

      // Let the failure-flash reset delay elapse; completion still must
      // never fire for this attempt.
      await tester.pump(const Duration(milliseconds: 700));
      expect(
        completed,
        isFalse,
        reason:
            'a path that mixes colors in one region must never report completion',
      );
    },
  );
}
