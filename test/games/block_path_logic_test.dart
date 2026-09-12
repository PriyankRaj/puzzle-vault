import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:topgames/core/game_level_context.dart';
import 'package:topgames/games/block_path/block_path_game.dart';

/// Level 1 is a flat 4x4 grid (no gaps, no elevation change) with a fixed
/// start (0,0) and goal (3,3), and a hand-verified solution path of
/// ['E','E','E','S','S','S'] (see `_levels[0]` in block_path_game.dart).
/// This mirrors that verified step list to drive a real win through the
/// public widget rather than reaching into private state.
const List<String> _level1SolutionSteps = ['E', 'E', 'E', 'S', 'S', 'S'];

/// Replicates the private `_screenPos` isometric-projection formula from
/// `BlockPathScreen` (same tile half-width/height and offsets) so the test
/// can compute where to tap for a given grid cell. If the projection
/// constants change in the widget, update these to match.
const double _tileHalfWidth = 26;
const double _tileHalfHeight = 15;
const double _elevationHeight = 12;

Offset _cellOffset(int rows, int r, int c, int elevation) {
  final offsetX = rows * _tileHalfWidth;
  final offsetY = 3 * _elevationHeight + _tileHalfHeight + 24;
  final x = (c - r) * _tileHalfWidth + offsetX;
  final y = (c + r) * _tileHalfHeight - elevation * _elevationHeight + offsetY;
  return Offset(x, y);
}

Future<void> _tapCell(
  WidgetTester tester,
  int rows,
  int r,
  int c,
  int elevation,
) async {
  // The board's GestureDetector is the one directly wrapping the
  // CustomPaint that renders the isometric grid; other GestureDetectors in
  // the tree belong to ancestor widgets (e.g. scroll/tap-region wrappers).
  final finder = find.ancestor(
    of: find.byType(CustomPaint),
    matching: find.byType(GestureDetector),
  );
  final origin = tester.getTopLeft(finder.first);
  // The board is now responsively scaled to fill available space (see
  // `BlockPathScreen.build`'s `LayoutBuilder`), so the rendered board is no
  // longer necessarily at the game's natural/unscaled tile size. Derive the
  // actual scale factor from the rendered size vs. the natural size (both
  // known to be square boards in these tests, `rows == cols`) and apply it
  // to the natural-size cell offset, rather than assuming scale == 1.
  final renderedWidth = tester.getSize(finder.first).width;
  final naturalWidth = (rows + rows) * _tileHalfWidth;
  final scale = renderedWidth / naturalWidth;
  final local = _cellOffset(rows, r, c, elevation) * scale;
  await tester.tapAt(origin + local);
  await tester.pump();
}

void main() {
  testWidgets(
    'block_path: replaying the verified solution path reaches the goal and reports completion',
    (tester) async {
      var completed = false;
      int? completedScore;

      await tester.pumpWidget(
        MaterialApp(
          home: BlockPathScreen(
            ctx: GameLevelContext(
              gameId: 'block_path',
              level: 1,
              isEndless: false,
              onComplete: ({int stars = 0, int? score}) {
                completed = true;
                completedScore = score;
              },
              onExit: () {},
            ),
          ),
        ),
      );

      // Level 1's flat 4x4 grid: elevation is always 0 everywhere, so every
      // step lands at elevation 0. Trace the verified step list from (0,0).
      var r = 0;
      var c = 0;
      for (final step in _level1SolutionSteps) {
        switch (step) {
          case 'E':
            c += 1;
            break;
          case 'S':
            r += 1;
            break;
          case 'N':
            r -= 1;
            break;
          case 'W':
            c -= 1;
            break;
        }
        await _tapCell(tester, 4, r, c, 0);
      }
      await tester.pump();

      expect(r, 3);
      expect(c, 3);
      expect(
        completed,
        isTrue,
        reason:
            'reaching (3,3) via the verified path should complete the level',
      );
      expect(completedScore, 6);
    },
  );

  testWidgets(
    'block_path: tapping a non-adjacent block is rejected and does not advance or complete',
    (tester) async {
      var completed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: BlockPathScreen(
            ctx: GameLevelContext(
              gameId: 'block_path',
              level: 1,
              isEndless: false,
              onComplete: ({int stars = 0, int? score}) => completed = true,
              onExit: () {},
            ),
          ),
        ),
      );

      // The goal (3,3) is not adjacent to the start (0,0), so tapping it
      // directly must be rejected: the token should not move and the level
      // should not be reported complete.
      await _tapCell(tester, 4, 3, 3, 0);
      await tester.pump();

      expect(find.text('Steps: 0'), findsOneWidget);
      expect(completed, isFalse);
    },
  );
}
