import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:topgames/core/game_level_context.dart';
import 'package:topgames/games/transit_planner/transit_planner_game.dart';

/// Level 1 uses `_ring(_ring5, 0)`: 5 stations placed evenly around a
/// circle, station types cycling `0,1,2,0,1` (see the level table and
/// `_ring` doc comment in transit_planner_game.dart). Per that file's
/// solvability proof, dragging a single line through every station in
/// order 0->1->2->3->4 ("the spine") touches every station and puts them
/// all in one connected component, satisfying both win conditions with
/// only 1 of the 2 available line slots.
const List<Offset> _ring5Normalized = [
  Offset(0.85, 0.50),
  Offset(0.61, 0.83),
  Offset(0.22, 0.71),
  Offset(0.22, 0.29),
  Offset(0.61, 0.17),
];

Offset _globalStationPos(WidgetTester tester, int stationIndex) {
  // The board's GestureDetector is the one directly wrapping the
  // CustomPaint that renders the stations; the line-slot chips above it
  // also build GestureDetectors internally (via InkWell), so anchor on the
  // CustomPaint's ancestor instead of picking by type/position alone.
  final finder = find.ancestor(
    of: find.byType(CustomPaint),
    matching: find.byType(GestureDetector),
  );
  final topLeft = tester.getTopLeft(finder.first);
  final size = tester.getSize(finder.first);
  final normalized = _ring5Normalized[stationIndex];
  return topLeft +
      Offset(normalized.dx * size.width, normalized.dy * size.height);
}

void main() {
  testWidgets(
    'transit_planner: dragging the spine through every station connects them all and reports completion',
    (tester) async {
      var completed = false;
      int? completedStars;

      await tester.pumpWidget(
        MaterialApp(
          home: TransitPlannerScreen(
            ctx: GameLevelContext(
              gameId: 'transit_planner',
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

      final gesture = await tester.startGesture(_globalStationPos(tester, 0));
      for (var i = 1; i < _ring5Normalized.length; i++) {
        await gesture.moveTo(_globalStationPos(tester, i));
        await tester.pump();
      }
      await gesture.up();
      await tester.pump();
      // onComplete fires after a 500ms success-flash delay.
      await tester.pump(const Duration(milliseconds: 600));

      expect(
        completed,
        isTrue,
        reason:
            'a single line touching every station in spine order should satisfy both win conditions',
      );
      // Solved using only 1 of the 2 available line slots (well within
      // half the budget), so it should earn full stars.
      expect(completedStars, 3);
    },
  );

  testWidgets(
    'transit_planner: leaving a station unconnected does not report completion',
    (tester) async {
      var completed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: TransitPlannerScreen(
            ctx: GameLevelContext(
              gameId: 'transit_planner',
              level: 1,
              isEndless: false,
              onComplete: ({int stars = 0, int? score}) => completed = true,
              onExit: () {},
            ),
          ),
        ),
      );

      // Drag through only the first 4 of the 5 stations, deliberately
      // leaving station 4 untouched.
      final gesture = await tester.startGesture(_globalStationPos(tester, 0));
      for (var i = 1; i < 4; i++) {
        await gesture.moveTo(_globalStationPos(tester, i));
        await tester.pump();
      }
      await gesture.up();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      expect(completed, isFalse);
    },
  );
}
