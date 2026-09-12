import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:topgames/core/game_level_context.dart';
import 'package:topgames/games/flow_connect/flow_connect_game.dart';

/// Locates the game board's [CustomPaint] (identified by its private
/// painter type name, since it's the only reliable way to find the exact
/// drawing surface without a key) so pixel-space drag coordinates can be
/// computed from grid cells.
Rect _boardRect(WidgetTester tester) {
  final finder = find.byWidgetPredicate(
    (w) =>
        w is CustomPaint &&
        w.painter.runtimeType.toString() == '_FlowConnectPainter',
  );
  return tester.getRect(finder);
}

/// Drags from the center of each cell in [path] in order, simulating a
/// real finger drag across the board. Consecutive cells in [path] must be
/// grid-adjacent, matching the in-game adjacency rule.
Future<void> _dragPath(
  WidgetTester tester,
  List<Point<int>> path,
  double cellSize,
  Offset boardTopLeft,
) async {
  Offset centerOf(Point<int> p) =>
      boardTopLeft + Offset((p.x + 0.5) * cellSize, (p.y + 0.5) * cellSize);

  final gesture = await tester.startGesture(centerOf(path.first));
  await tester.pump();
  for (final cell in path.skip(1)) {
    await gesture.moveTo(centerOf(cell));
    await tester.pump();
  }
  await gesture.up();
  await tester.pump();
}

void main() {
  // Level 1's three endpoint pairs and one verified, non-crossing solution
  // path per pair (a contiguous slice of a full-grid snake traversal, per
  // the level-authoring comment in flow_connect_game.dart). Replaying these
  // drags exactly should connect every pair and win the level.
  const pairA = [
    Point(0, 0),
    Point(1, 0),
    Point(2, 0),
    Point(3, 0),
    Point(4, 0),
    Point(4, 1),
    Point(3, 1),
    Point(2, 1),
    Point(1, 1),
  ];
  const pairB = [
    Point(0, 1),
    Point(0, 2),
    Point(1, 2),
    Point(2, 2),
    Point(3, 2),
    Point(4, 2),
    Point(4, 3),
    Point(3, 3),
  ];
  const pairC = [
    Point(2, 3),
    Point(1, 3),
    Point(0, 3),
    Point(0, 4),
    Point(1, 4),
    Point(2, 4),
    Point(3, 4),
    Point(4, 4),
  ];

  testWidgets(
    'flow_connect: replaying the verified solution paths for all pairs '
    'connects every pipe and reports completion',
    (tester) async {
      var completed = false;
      int? completedStars;

      await tester.pumpWidget(
        MaterialApp(
          home: FlowConnectScreen(
            ctx: GameLevelContext(
              gameId: 'flow_connect',
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

      final rect = _boardRect(tester);
      final cellSize = rect.width / 5; // level 1 is a 5x5 grid

      await _dragPath(tester, pairA, cellSize, rect.topLeft);
      await _dragPath(tester, pairB, cellSize, rect.topLeft);
      await _dragPath(tester, pairC, cellSize, rect.topLeft);
      // onComplete fires after a short delay once the last pair connects.
      await tester.pump(const Duration(milliseconds: 500));

      expect(completed, isTrue);
      expect(completedStars, inInclusiveRange(1, 3));
    },
  );

  testWidgets(
    'flow_connect: lifting a drag before it reaches the matching endpoint '
    'abandons that pipe instead of falsely completing the level',
    (tester) async {
      var completed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: FlowConnectScreen(
            ctx: GameLevelContext(
              gameId: 'flow_connect',
              level: 1,
              isEndless: false,
              onComplete: ({int stars = 0, int? score}) => completed = true,
              onExit: () {},
            ),
          ),
        ),
      );
      await tester.pump();

      final rect = _boardRect(tester);
      final cellSize = rect.width / 5;

      // Start pair A's pipe but lift halfway through, well short of its
      // matching endpoint at (1,1).
      await _dragPath(
        tester,
        const [Point(0, 0), Point(1, 0), Point(2, 0)],
        cellSize,
        rect.topLeft,
      );
      expect(completed, isFalse);
      expect(find.text('Connected: 0/3   Restarts: 1'), findsOneWidget);

      // Now finish all three pairs for real, proving the earlier abandoned
      // attempt didn't leave the board in a broken or falsely-won state.
      await _dragPath(tester, pairA, cellSize, rect.topLeft);
      await _dragPath(tester, pairB, cellSize, rect.topLeft);
      await _dragPath(tester, pairC, cellSize, rect.topLeft);
      await tester.pump(const Duration(milliseconds: 500));

      expect(completed, isTrue);
    },
  );
}
