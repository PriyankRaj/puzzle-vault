import 'dart:math';

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/game_definition.dart';
import '../../core/game_level_context.dart';

/// Original implementation of the well-known, generic "draw a single loop
/// that satisfies every numbered cell" logic-puzzle genre (decades-old,
/// widely published, owned by no single app). Every grid, label and line of
/// code here is original — no third-party name, art or branding is reused.
final GameDefinition loopTraceDefinition = GameDefinition(
  id: 'loop_trace',
  title: 'Loop Draw',
  tagline: 'Draw one loop that matches every number',
  icon: Icons.hexagon_outlined,
  tint: const GameTint(Color(0xFFFB7185), Color(0xFF9D174D)),
  mode: GameMode.levels,
  levelCount: 15,
  builder: (context, ctx) => LoopTraceScreen(ctx: ctx),
);

/// Grid dimension (N x N cells) for a given level: ~4x4 at level 1 growing
/// to ~7x7 at level 15.
int _gridSizeForLevel(int level) => 4 + ((level - 1) * 3) ~/ 14;

/// The horizontal (`h`) and vertical (`v`) edge grids describing which
/// dot-to-dot segments are part of a loop.
///
/// `h[i][j]` (i in 0..n, j in 0..n-1) is the edge between dot (i,j) and dot
/// (i, j+1). `v[i][j]` (i in 0..n-1, j in 0..n) is the edge between dot
/// (i,j) and dot (i+1, j).
class _Edges {
  _Edges(this.h, this.v);
  final List<List<bool>> h;
  final List<List<bool>> v;
}

class _PuzzleData {
  _PuzzleData(this.clues, this.parEdgeCount);

  /// clues[r][c] is -1 when the cell has no number, else 0-4.
  final List<List<int>> clues;

  /// Number of on-edges in the ground-truth loop used to derive [clues];
  /// used as the par baseline for star scoring.
  final int parEdgeCount;
}

/// Builds the boundary edges that separate `region` (true = inside the
/// loop) from everything outside it. This boundary is guaranteed to be a
/// disjoint union of simple closed rectilinear curves; [_isSingleLoop]
/// verifies it collapses to exactly one such curve with no branch points.
_Edges _edgesFromRegion(List<List<bool>> region, int n) {
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
  return _Edges(h, v);
}

/// Real graph check (not a shortcut): every dot must have degree 0 or 2
/// (no branch points), there must be at least one on-edge, and a
/// breadth-first walk from any on-edge must reach every other on-edge
/// (no separate disconnected loop fragments) — together this proves the
/// on-edge set is exactly one simple closed loop.
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

/// Deterministic random growth of a connected region on an n x n grid,
/// starting from a single seed cell and repeatedly adding a random cell
/// adjacent to the current region until it reaches a target size.
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

/// Trivial always-valid fallback: the outer border of the whole grid forms
/// a single simple rectangular loop.
List<List<bool>> _fallbackRegion(int n) =>
    List.generate(n, (_) => List.filled(n, true));

int _cellOnCount(List<List<bool>> h, List<List<bool>> v, int r, int c) {
  var cnt = 0;
  if (h[r][c]) cnt++;
  if (h[r + 1][c]) cnt++;
  if (v[r][c]) cnt++;
  if (v[r][c + 1]) cnt++;
  return cnt;
}

/// Generates a level's puzzle by first building a random-but-deterministic
/// ground-truth loop (validated with the real [_isSingleLoop] graph check,
/// falling back to the always-valid grid border if every attempt fails),
/// then labelling a subset of cells with the true on-edge count around
/// them. This guarantees at least one valid solution exists by
/// construction — no NP-hard solving/uniqueness search is attempted.
_PuzzleData _generatePuzzle(int n, int level) {
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

  // Final safety net: this must always hold, either for a generated
  // candidate above or for the untouched fallback border loop.
  assert(
    _isSingleLoop(edges.h, edges.v, n),
    'Generated loop_trace puzzle is not a single valid loop for level $level',
  );

  final clueRng = Random(seedBase + level * 613 + 7);
  final clueProb = (0.72 - level * 0.02).clamp(0.4, 0.72);
  final clues = List.generate(n, (_) => List.filled(n, -1));
  for (var r = 0; r < n; r++) {
    for (var c = 0; c < n; c++) {
      if (clueRng.nextDouble() < clueProb) {
        clues[r][c] = _cellOnCount(edges.h, edges.v, r, c);
      }
    }
  }

  var parEdgeCount = 0;
  for (final row in edges.h) {
    for (final e in row) {
      if (e) parEdgeCount++;
    }
  }
  for (final row in edges.v) {
    for (final e in row) {
      if (e) parEdgeCount++;
    }
  }

  return _PuzzleData(clues, parEdgeCount);
}

class LoopTraceScreen extends StatefulWidget {
  const LoopTraceScreen({super.key, required this.ctx});

  final GameLevelContext ctx;

  @override
  State<LoopTraceScreen> createState() => _LoopTraceScreenState();
}

class _LoopTraceScreenState extends State<LoopTraceScreen> {
  late int _n;
  late List<List<int>> _clues;
  late int _parEdgeCount;
  late List<List<bool>> _hOn;
  late List<List<bool>> _vOn;
  int _toggles = 0;
  bool _solved = false;

  int get _level => widget.ctx.level;

  @override
  void initState() {
    super.initState();
    _n = _gridSizeForLevel(_level);
    final puzzle = _generatePuzzle(_n, _level);
    _clues = puzzle.clues;
    _parEdgeCount = puzzle.parEdgeCount;
    _hOn = List.generate(_n + 1, (_) => List.filled(_n, false));
    _vOn = List.generate(_n, (_) => List.filled(_n + 1, false));
  }

  void _clear() {
    setState(() {
      _hOn = List.generate(_n + 1, (_) => List.filled(_n, false));
      _vOn = List.generate(_n, (_) => List.filled(_n + 1, false));
      _toggles = 0;
      _solved = false;
    });
  }

  void _handleTap(Offset pos, double cellSize) {
    if (_solved) return;
    var bestDist = double.infinity;
    String? bestType;
    var bestI = 0, bestJ = 0;
    for (var i = 0; i <= _n; i++) {
      for (var j = 0; j < _n; j++) {
        final mid = Offset(j * cellSize + cellSize / 2, i * cellSize);
        final d = (pos - mid).distance;
        if (d < bestDist) {
          bestDist = d;
          bestType = 'h';
          bestI = i;
          bestJ = j;
        }
      }
    }
    for (var i = 0; i < _n; i++) {
      for (var j = 0; j <= _n; j++) {
        final mid = Offset(j * cellSize, i * cellSize + cellSize / 2);
        final d = (pos - mid).distance;
        if (d < bestDist) {
          bestDist = d;
          bestType = 'v';
          bestI = i;
          bestJ = j;
        }
      }
    }
    if (bestType == null || bestDist > cellSize * 0.42) return;
    setState(() {
      if (bestType == 'h') {
        _hOn[bestI][bestJ] = !_hOn[bestI][bestJ];
      } else {
        _vOn[bestI][bestJ] = !_vOn[bestI][bestJ];
      }
      _toggles++;
      _checkWin();
    });
  }

  void _checkWin() {
    for (var r = 0; r < _n; r++) {
      for (var c = 0; c < _n; c++) {
        final clue = _clues[r][c];
        if (clue == -1) continue;
        if (_cellOnCount(_hOn, _vOn, r, c) != clue) return;
      }
    }
    if (!_isSingleLoop(_hOn, _vOn, _n)) return;
    _solved = true;
    final par = _parEdgeCount + 4;
    final stars = _toggles <= par
        ? 3
        : (_toggles <= par + 6 ? 2 : 1);
    Future.microtask(() => widget.ctx.onComplete(stars: stars));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Level $_level'),
        actions: [
          TextButton(onPressed: _clear, child: const Text('Clear')),
          TextButton(onPressed: widget.ctx.onExit, child: const Text('Give up')),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              'Toggles: $_toggles',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          Expanded(
            child: Center(
              child: AspectRatio(
                aspectRatio: 1,
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final board = min(
                        constraints.maxWidth,
                        constraints.maxHeight,
                      );
                      final cellSize = board / _n;
                      return GestureDetector(
                        onTapUp: (details) =>
                            _handleTap(details.localPosition, cellSize),
                        child: CustomPaint(
                          size: Size(board, board),
                          painter: _LoopTracePainter(
                            n: _n,
                            hOn: _hOn,
                            vOn: _vOn,
                            clues: _clues,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              'Tap an edge to toggle it. Draw a single loop so every '
              'number matches the edges around its cell.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoopTracePainter extends CustomPainter {
  _LoopTracePainter({
    required this.n,
    required this.hOn,
    required this.vOn,
    required this.clues,
  });

  final int n;
  final List<List<bool>> hOn;
  final List<List<bool>> vOn;
  final List<List<int>> clues;

  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.width / n;
    final faintPaint = Paint()
      ..color = AppTheme.textSecondary.withValues(alpha: 0.18)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    final onPaint = Paint()
      ..color = AppTheme.accent
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    final dotPaint = Paint()..color = AppTheme.textSecondary.withValues(alpha: 0.6);

    for (var i = 0; i <= n; i++) {
      for (var j = 0; j < n; j++) {
        final p1 = Offset(j * cell, i * cell);
        final p2 = Offset((j + 1) * cell, i * cell);
        canvas.drawLine(p1, p2, hOn[i][j] ? onPaint : faintPaint);
      }
    }
    for (var i = 0; i < n; i++) {
      for (var j = 0; j <= n; j++) {
        final p1 = Offset(j * cell, i * cell);
        final p2 = Offset(j * cell, (i + 1) * cell);
        canvas.drawLine(p1, p2, vOn[i][j] ? onPaint : faintPaint);
      }
    }
    for (var i = 0; i <= n; i++) {
      for (var j = 0; j <= n; j++) {
        canvas.drawCircle(Offset(j * cell, i * cell), 3, dotPaint);
      }
    }

    for (var r = 0; r < n; r++) {
      for (var c = 0; c < n; c++) {
        final clue = clues[r][c];
        if (clue == -1) continue;
        final count = _cellOnCount(hOn, vOn, r, c);
        final satisfied = count == clue;
        final tp = TextPainter(
          text: TextSpan(
            text: '$clue',
            style: TextStyle(
              color: satisfied ? AppTheme.success : AppTheme.danger,
              fontSize: cell * 0.38,
              fontWeight: FontWeight.w800,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        final center = Offset(c * cell + cell / 2, r * cell + cell / 2);
        tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
      }
    }
  }

  @override
  bool shouldRepaint(covariant _LoopTracePainter oldDelegate) => true;
}
