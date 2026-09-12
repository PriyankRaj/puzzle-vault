import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:topgames/core/game_level_context.dart';
import 'package:topgames/core/progress_store.dart';
import 'package:topgames/games/merge_threes/merge_threes_game.dart';

/// The board is seeded from an unseeded `Random()` (see
/// `_MergeThreesScreenState` in merge_threes_game.dart), so this test can't
/// know the exact tile layout ahead of time and can't deterministically
/// force a specific pre-built scenario. Instead it replicates the game's
/// own merge predicate/line-merge algorithm as a test-local oracle (mirroring
/// `_canMerge`/`_mergedValue`/`_mergeLine`/`_move`) and, across many swipes
/// on the real widget, predicts the pre-spawn board and diffs it against
/// the actual rendered board (locating the one newly spawned tile). This
/// proves the real widget's behaviour matches the documented special rule —
/// a lone `1` next to a lone `2` merges into `3`, while bare `1`+`1` or
/// `2`+`2` never merge — by tallying real, observed instances of both
/// outcomes on the actual board, not just asserting the oracle agrees with
/// itself.
bool _canMerge(int a, int b) {
  if ((a == 1 && b == 2) || (a == 2 && b == 1)) return true;
  if (a == b && a >= 3) return true;
  return false;
}

int _mergedValue(int a, int b) {
  if ((a == 1 && b == 2) || (a == 2 && b == 1)) return 3;
  return a * 2;
}

class _LineResult {
  _LineResult(this.line, this.oneTwoMerges, this.blockedEqualPairs);
  final List<int> line;
  final int oneTwoMerges;
  final int blockedEqualPairs;
}

_LineResult _mergeLine(List<int> line, int size) {
  final compact = line.where((v) => v != 0).toList();
  final result = <int>[];
  var oneTwoMerges = 0;
  var blockedEqualPairs = 0;
  var i = 0;
  while (i < compact.length) {
    if (i + 1 < compact.length && _canMerge(compact[i], compact[i + 1])) {
      final a = compact[i];
      final b = compact[i + 1];
      result.add(_mergedValue(a, b));
      if ((a == 1 && b == 2) || (a == 2 && b == 1)) oneTwoMerges++;
      i += 2;
    } else {
      if (i + 1 < compact.length &&
          compact[i] == compact[i + 1] &&
          compact[i] < 3) {
        blockedEqualPairs++;
      }
      result.add(compact[i]);
      i += 1;
    }
  }
  while (result.length < size) {
    result.add(0);
  }
  return _LineResult(result, oneTwoMerges, blockedEqualPairs);
}

/// Predicts the post-merge, pre-spawn board for [before] after a swipe in
/// direction ([dx], [dy]), mirroring `_move`'s row/column extraction and
/// reversal handling exactly. Also tallies how many `1`+`2` -> `3` merges
/// and how many blocked bare-equal-pairs occurred across every line.
class _MovePrediction {
  _MovePrediction(this.board, this.oneTwoMerges, this.blockedEqualPairs);
  final List<List<int>> board;
  final int oneTwoMerges;
  final int blockedEqualPairs;
}

_MovePrediction _predictMove(List<List<int>> before, int size, int dx, int dy) {
  final board = before.map((r) => List<int>.from(r)).toList();
  var oneTwoMerges = 0;
  var blockedEqualPairs = 0;

  if (dx == -1 || dx == 1) {
    for (var r = 0; r < size; r++) {
      var line = board[r];
      if (dx == 1) line = line.reversed.toList();
      final res = _mergeLine(line, size);
      board[r] = dx == 1 ? res.line.reversed.toList() : res.line;
      oneTwoMerges += res.oneTwoMerges;
      blockedEqualPairs += res.blockedEqualPairs;
    }
  } else {
    for (var c = 0; c < size; c++) {
      var line = [for (var r = 0; r < size; r++) board[r][c]];
      if (dy == 1) line = line.reversed.toList();
      final res = _mergeLine(line, size);
      final ordered = dy == 1 ? res.line.reversed.toList() : res.line;
      for (var r = 0; r < size; r++) {
        board[r][c] = ordered[r];
      }
      oneTwoMerges += res.oneTwoMerges;
      blockedEqualPairs += res.blockedEqualPairs;
    }
  }
  return _MovePrediction(board, oneTwoMerges, blockedEqualPairs);
}

int? _tileValueOf(AnimatedContainer c) {
  final child = c.child;
  if (child == null) return 0;
  final text = (child as Text).data!;
  return int.parse(text);
}

List<List<int>> _readBoard(WidgetTester tester, int size) {
  final containers = find
      .descendant(
        of: find.byType(GridView),
        matching: find.byType(AnimatedContainer),
      )
      .evaluate()
      .map((el) => el.widget as AnimatedContainer)
      .toList();
  final flat = containers.map((c) => _tileValueOf(c)!).toList();
  return List.generate(size, (r) => flat.sublist(r * size, r * size + size));
}

Future<void> _swipe(WidgetTester tester, Offset direction) async {
  await tester.fling(find.byType(GridView), direction, 1200);
  await tester.pump();
}

void main() {
  SharedPreferences.setMockInitialValues({});

  setUp(() async {
    await ProgressStore.instance.init();
  });

  testWidgets(
    'merge_threes: real swipes match the oracle, proving 1+2->3 merges happen and bare equal pairs never merge',
    (tester) async {
      const size = 4;
      var completed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: MergeThreesScreen(
            ctx: GameLevelContext(
              gameId: 'merge_threes',
              level: 1,
              isEndless: true,
              onComplete: ({int stars = 0, int? score}) => completed = true,
              onExit: () {},
            ),
          ),
        ),
      );
      await tester.pump();

      const directions = [
        Offset(300, 0), // right -> dx=1
        Offset(0, 300), // down -> dy=1
        Offset(-300, 0), // left -> dx=-1
        Offset(0, -300), // up -> dy=-1
      ];
      const dxdy = [
        [1, 0],
        [0, 1],
        [-1, 0],
        [0, -1],
      ];

      var totalOneTwoMerges = 0;
      var totalBlockedEqualPairs = 0;

      for (var i = 0; i < 80 && !completed; i++) {
        final before = _readBoard(tester, size);
        final dx = dxdy[i % 4][0];
        final dy = dxdy[i % 4][1];
        final prediction = _predictMove(before, size, dx, dy);

        await _swipe(tester, directions[i % 4]);

        final after = _readBoard(tester, size);
        final beforeFlat = before.expand((r) => r).toList();
        final predictedFlat = prediction.board.expand((r) => r).toList();
        final afterFlat = after.expand((r) => r).toList();

        if (predictedFlat.toString() == beforeFlat.toString()) {
          // No-op swipe: nothing could slide/merge in this direction.
          expect(
            afterFlat,
            beforeFlat,
            reason: 'a no-op swipe must not change the board',
          );
          continue;
        }

        // The real board after the swipe must equal the oracle's predicted
        // post-merge board, except for exactly one newly spawned tile.
        var diffCount = 0;
        var spawnValue = 0;
        for (var idx = 0; idx < afterFlat.length; idx++) {
          if (afterFlat[idx] != predictedFlat[idx]) {
            diffCount++;
            expect(
              predictedFlat[idx],
              0,
              reason:
                  'a mismatch must only occur where the oracle expected an empty cell (the spawn site)',
            );
            spawnValue = afterFlat[idx];
          }
        }
        expect(
          diffCount,
          1,
          reason:
              'exactly one freshly spawned tile should differ from the oracle prediction',
        );
        expect(
          [1, 2, 3],
          contains(spawnValue),
          reason: 'the spawned tile value must be 1, 2 or 3',
        );

        totalOneTwoMerges += prediction.oneTwoMerges;
        totalBlockedEqualPairs += prediction.blockedEqualPairs;
      }

      expect(
        totalOneTwoMerges,
        greaterThan(0),
        reason:
            'expected at least one real 1-next-to-2 -> 3 merge to occur '
            'and match the real board across 80 swipes',
      );
      expect(
        totalBlockedEqualPairs,
        greaterThan(0),
        reason:
            'expected at least one real bare-equal-pair (1+1 or 2+2) to '
            'stay unmerged, side by side, matching the real board',
      );
    },
  );

  testWidgets(
    'merge_threes: a slow drag below the velocity threshold does not move or merge anything',
    (tester) async {
      const size = 4;
      var completed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: MergeThreesScreen(
            ctx: GameLevelContext(
              gameId: 'merge_threes',
              level: 1,
              isEndless: true,
              onComplete: ({int stars = 0, int? score}) => completed = true,
              onExit: () {},
            ),
          ),
        ),
      );
      await tester.pump();

      final boardBefore = _readBoard(tester, size);

      await tester.timedDrag(
        find.byType(GridView),
        const Offset(40, 0),
        const Duration(seconds: 2),
      );
      await tester.pump();

      final boardAfter = _readBoard(tester, size);

      expect(
        boardAfter,
        boardBefore,
        reason: 'a below-threshold drag must not slide/merge any tile',
      );
      expect(completed, isFalse);
    },
  );
}
