import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:topgames/core/game_level_context.dart';
import 'package:topgames/games/loop_trace/loop_trace_game.dart';

/// The following four helpers replicate the private generation algorithm in
/// `loop_trace_game.dart` (`_edgesFromRegion`, `_isSingleLoop`,
/// `_growRegion`, `_generatePuzzle`'s attempt loop) exactly — same seed
/// formula, same call order, same RNG consumption — so this test can
/// compute the real winning edge set for a level without reaching into
/// private state. If the in-game generation algorithm changes, update this
/// to match.
({List<List<bool>> h, List<List<bool>> v}) _edgesFromRegion(
  List<List<bool>> region,
  int n,
) {
  bool inside(int r, int c) {
    if (r < 0 || r >= n || c < 0 || c >= n) return false;
    return region[r][c];
  }

  final h = List.generate(n + 1, (_) => List.filled(n, false));
  final v = List.generate(n, (_) => List.filled(n + 1, false));
  for (var i = 0; i <= n; i++) {
    for (var j = 0; j < n; j++) {
      h[i][j] = inside(i - 1, j) != inside(i, j);
    }
  }
  for (var i = 0; i < n; i++) {
    for (var j = 0; j <= n; j++) {
      v[i][j] = inside(i, j - 1) != inside(i, j);
    }
  }
  return (h: h, v: v);
}

bool _isSingleLoop(List<List<bool>> h, List<List<bool>> v, int n) {
  var totalOn = 0;
  for (final row in h) {
    for (final e in row) {
      if (e) totalOn++;
    }
  }
  for (final row in v) {
    for (final e in row) {
      if (e) totalOn++;
    }
  }
  if (totalOn == 0) return false;

  int degreeAt(int i, int j) {
    var deg = 0;
    if (j > 0 && h[i][j - 1]) deg++;
    if (j < n && h[i][j]) deg++;
    if (i > 0 && v[i - 1][j]) deg++;
    if (i < n && v[i][j]) deg++;
    return deg;
  }

  int? startI, startJ;
  for (var i = 0; i <= n && startI == null; i++) {
    for (var j = 0; j <= n; j++) {
      final deg = degreeAt(i, j);
      if (deg != 0 && deg != 2) return false;
      if (deg > 0 && startI == null) {
        startI = i;
        startJ = j;
      }
    }
  }
  if (startI == null) return false;

  final visitedDots = <int>{startI * (n + 1) + startJ!};
  final visitedEdges = <String>{};
  final queue = <List<int>>[
    [startI, startJ],
  ];
  var head = 0;
  while (head < queue.length) {
    final cur = queue[head++];
    final i = cur[0], j = cur[1];
    void relax(bool on, String key, int ni, int nj) {
      if (!on) return;
      visitedEdges.add(key);
      final id = ni * (n + 1) + nj;
      if (visitedDots.add(id)) queue.add([ni, nj]);
    }

    if (j > 0) relax(h[i][j - 1], 'h$i,${j - 1}', i, j - 1);
    if (j < n) relax(h[i][j], 'h$i,$j', i, j + 1);
    if (i > 0) relax(v[i - 1][j], 'v${i - 1},$j', i - 1, j);
    if (i < n) relax(v[i][j], 'v$i,$j', i + 1, j);
  }
  return visitedEdges.length == totalOn;
}

List<List<bool>> _growRegion(int n, Random rng, int targetSize) {
  final region = List.generate(n, (_) => List.filled(n, false));
  final startR = rng.nextInt(n), startC = rng.nextInt(n);
  region[startR][startC] = true;
  var count = 1;
  const dirs = [
    [-1, 0],
    [1, 0],
    [0, -1],
    [0, 1],
  ];
  while (count < targetSize) {
    final frontier = <List<int>>[];
    for (var i = 0; i < n; i++) {
      for (var j = 0; j < n; j++) {
        if (region[i][j]) continue;
        for (final d in dirs) {
          final ni = i + d[0], nj = j + d[1];
          if (ni >= 0 && ni < n && nj >= 0 && nj < n && region[ni][nj]) {
            frontier.add([i, j]);
            break;
          }
        }
      }
    }
    if (frontier.isEmpty) break;
    final pick = frontier[rng.nextInt(frontier.length)];
    region[pick[0]][pick[1]] = true;
    count++;
  }
  return region;
}

List<List<bool>> _fallbackRegion(int n) =>
    List.generate(n, (_) => List.filled(n, true));

/// Reproduces `_generatePuzzle`'s attempt loop to find the exact same
/// ground-truth loop the real widget generates for [level] on an [n]x[n]
/// grid, returning it as a flat list of "on" edges described by
/// `(isHorizontal, i, j)`.
List<(bool isHorizontal, int i, int j)> _solvedEdgesFor(int n, int level) {
  const seedBase = 424242;
  var region = _fallbackRegion(n);
  var edges = _edgesFromRegion(region, n);

  for (var attempt = 0; attempt < 60; attempt++) {
    final rng = Random(seedBase + level * 977 + attempt * 131 + 1);
    final target = (n * n * (0.4 + rng.nextDouble() * 0.3)).round().clamp(
      n,
      n * n - 1,
    );
    final candidate = _growRegion(n, rng, target);
    final candidateEdges = _edgesFromRegion(candidate, n);
    if (_isSingleLoop(candidateEdges.h, candidateEdges.v, n)) {
      region = candidate;
      edges = candidateEdges;
      break;
    }
  }

  final on = <(bool, int, int)>[];
  for (var i = 0; i <= n; i++) {
    for (var j = 0; j < n; j++) {
      if (edges.h[i][j]) on.add((true, i, j));
    }
  }
  for (var i = 0; i < n; i++) {
    for (var j = 0; j <= n; j++) {
      if (edges.v[i][j]) on.add((false, i, j));
    }
  }
  return on;
}

/// Nudges a coordinate exactly on the board's outer boundary (0 or the
/// board size) inward by half a pixel. `tester.tapAt` hit-tests against the
/// gesture detector's box, and a point sitting exactly on its far edge can
/// fail to register as inside — this keeps every synthetic tap safely
/// within bounds without changing which edge is nearest.
double _nudgeInward(double value, double boardSize) {
  if (value <= 0) return 0.5;
  if (value >= boardSize) return boardSize - 0.5;
  return value;
}

void main() {
  const level = 1;
  const n = 4; // _gridSizeForLevel(1)

  testWidgets(
    'loop_trace: tapping every edge of the true generated loop draws a valid single loop and reports completion',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final solvedEdges = _solvedEdgesFor(n, level);
      expect(solvedEdges, isNotEmpty);

      var completed = false;
      int? completedStars;

      await tester.pumpWidget(
        MaterialApp(
          home: LoopTraceScreen(
            ctx: GameLevelContext(
              gameId: 'loop_trace',
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

      final rect = tester.getRect(
        find.ancestor(
          of: find.byType(CustomPaint),
          matching: find.byType(GestureDetector),
        ),
      );
      final cellSize = rect.width / n;
      final boardSize = rect.width;

      for (final (isHorizontal, i, j) in solvedEdges) {
        final raw = isHorizontal
            ? Offset(j * cellSize + cellSize / 2, i * cellSize)
            : Offset(j * cellSize, i * cellSize + cellSize / 2);
        final local = Offset(
          _nudgeInward(raw.dx, boardSize),
          _nudgeInward(raw.dy, boardSize),
        );
        await tester.tapAt(rect.topLeft + local);
        await tester.pump();
      }

      expect(
        completed,
        isTrue,
        reason: 'recreating the exact generated loop must report completion',
      );
      expect(completedStars, inInclusiveRange(1, 3));
    },
  );

  testWidgets(
    'loop_trace: toggling on only one edge of the true loop leaves it incomplete and never reports completion',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final solvedEdges = _solvedEdgesFor(n, level);
      expect(solvedEdges.length, greaterThan(1));

      var completed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: LoopTraceScreen(
            ctx: GameLevelContext(
              gameId: 'loop_trace',
              level: level,
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
      final cellSize = rect.width / n;
      final boardSize = rect.width;

      final (isHorizontal, i, j) = solvedEdges.first;
      final raw = isHorizontal
          ? Offset(j * cellSize + cellSize / 2, i * cellSize)
          : Offset(j * cellSize, i * cellSize + cellSize / 2);
      final local = Offset(
        _nudgeInward(raw.dx, boardSize),
        _nudgeInward(raw.dy, boardSize),
      );
      await tester.tapAt(rect.topLeft + local);
      await tester.pump();

      expect(
        completed,
        isFalse,
        reason: 'a single toggled edge cannot form a valid closed loop',
      );
    },
  );
}
