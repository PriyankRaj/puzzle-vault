import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/game_definition.dart';
import '../../core/game_level_context.dart';
import '../../core/motion.dart';

/// Original puzzle: an isometric-look terrain of raised/lowered "blocks".
/// A token steps across orthogonally-adjacent blocks (never diagonally),
/// only when the destination exists (isn't a gap) and its elevation
/// differs from the current block by at most one level, from a fixed
/// start block to a fixed goal block. Loosely inspired by "walk across a
/// 3D-looking block terrain to reach a goal" as a generic mechanic only —
/// every grid, name and pixel of rendering here is original.
final GameDefinition blockPathDefinition = GameDefinition(
  id: 'block_path',
  title: 'Step Blocks',
  tagline: 'Step across isometric blocks to the goal',
  icon: Icons.view_in_ar_rounded,
  tint: const GameTint(Color(0xFF22D3EE), Color(0xFF0E7490)),
  mode: GameMode.levels,
  levelCount: 15,
  builder: (context, ctx) => BlockPathScreen(ctx: ctx),
);

typedef _Cell = (int, int);

/// One hand-authored level: a rows x cols grid of elevations (0-3, or
/// `null` for a missing/gap block), a fixed start/goal cell, and the
/// designer-verified shortest solution path stored as compass directions
/// purely so authoring correctness can be double-checked by inspection
/// (each direction was traced by hand against [grid] while writing this
/// file and confirmed to only cross existing blocks with an elevation
/// step of at most one).
class _LevelSpec {
  const _LevelSpec({
    required this.grid,
    required this.start,
    required this.goal,
    required this.verifiedSolutionSteps,
  });

  final List<List<int?>> grid;
  final _Cell start;
  final _Cell goal;

  /// 'N' / 'E' / 'S' / 'W' — the hand-verified minimal path from [start]
  /// to [goal]. Used only as the "par" step count for star scoring.
  final List<String> verifiedSolutionSteps;

  int get rows => grid.length;
  int get cols => grid.first.length;
}

/// 15 hand-designed levels, growing from a small 4x4 board with a gentle
/// slope up to a 6x6 board with two staggered single-cell "gates" that
/// force a long detour around gaps and elevation cliffs. Every grid below
/// was authored together with [verifiedSolutionSteps] by tracing the path
/// cell-by-cell and checking each step lands on a non-null cell whose
/// elevation differs from the previous cell by at most one.
final List<_LevelSpec> _levels = [
  // Level 1 — flat 4x4 warm-up, no gaps.
  const _LevelSpec(
    grid: [
      [0, 0, 0, 0],
      [0, 0, 0, 0],
      [0, 0, 0, 0],
      [0, 0, 0, 0],
    ],
    start: (0, 0),
    goal: (3, 3),
    verifiedSolutionSteps: ['E', 'E', 'E', 'S', 'S', 'S'],
  ),
  // Level 2 — a single gate column through a row of gaps.
  const _LevelSpec(
    grid: [
      [0, 0, 0, 0],
      [1, 1, 1, 1],
      [null, null, 2, null],
      [3, 3, 3, 3],
    ],
    start: (0, 0),
    goal: (3, 3),
    verifiedSolutionSteps: ['E', 'E', 'S', 'S', 'S', 'E'],
  ),
  // Level 3 — a straight line is blocked by a 2-level cliff; ramp around.
  const _LevelSpec(
    grid: [
      [0, 0, 0, 0],
      [1, 1, null, 1],
      [2, null, 2, 2],
      [3, 3, 3, 3],
    ],
    start: (0, 0),
    goal: (3, 3),
    verifiedSolutionSteps: ['S', 'S', 'S', 'E', 'E', 'E'],
  ),
  // Level 4 — narrower gate, elevation ramps through the middle column.
  const _LevelSpec(
    grid: [
      [0, 0, 0, 0],
      [null, 1, null, null],
      [2, 2, null, 2],
      [3, 3, 3, 3],
    ],
    start: (0, 0),
    goal: (3, 3),
    verifiedSolutionSteps: ['E', 'S', 'S', 'S', 'E', 'E'],
  ),
  // Level 5 — two separate gaps force a dogleg detour.
  const _LevelSpec(
    grid: [
      [0, 0, 1, 1],
      [0, 1, null, 2],
      [1, 1, 2, 2],
      [null, 2, 2, 3],
    ],
    start: (0, 0),
    goal: (3, 3),
    verifiedSolutionSteps: ['S', 'S', 'E', 'E', 'E', 'S'],
  ),
  // Level 6 — 5x5, single gate through a wall of gaps.
  const _LevelSpec(
    grid: [
      [0, 0, 0, 0, 0],
      [1, 1, 1, 1, 1],
      [null, null, 1, null, null],
      [2, 2, 2, 2, 2],
      [2, 2, 2, 2, 2],
    ],
    start: (0, 0),
    goal: (4, 4),
    verifiedSolutionSteps: ['E', 'E', 'S', 'S', 'S', 'E', 'E', 'S'],
  ),
  // Level 7 — two staggered gates on a 5x5 board.
  const _LevelSpec(
    grid: [
      [0, 0, 0, 0, 0],
      [null, 1, null, null, null],
      [1, 1, 1, 1, 1],
      [null, null, null, 2, null],
      [3, 3, 3, 3, 3],
    ],
    start: (0, 0),
    goal: (4, 4),
    verifiedSolutionSteps: ['E', 'S', 'S', 'E', 'E', 'S', 'S', 'E'],
  ),
  // Level 8 — gates pushed apart, forcing a wide zig-zag.
  const _LevelSpec(
    grid: [
      [0, 0, 0, 0, 0],
      [null, null, null, 1, null],
      [1, 1, 1, 1, 1],
      [null, 2, null, null, null],
      [3, 3, 3, 3, 3],
    ],
    start: (0, 0),
    goal: (4, 4),
    verifiedSolutionSteps: [
      'E', 'E', 'E', 'S', 'S', 'W', 'W', 'S', 'S', 'E', 'E', 'E',
    ],
  ),
  // Level 9 — same zig-zag shape plus a decorative extra gap.
  const _LevelSpec(
    grid: [
      [0, 0, 0, 0, 0],
      [null, null, null, 1, null],
      [1, 1, 1, 1, null],
      [null, 2, null, null, null],
      [3, 3, 3, 3, 3],
    ],
    start: (0, 0),
    goal: (4, 4),
    verifiedSolutionSteps: [
      'E', 'E', 'E', 'S', 'S', 'W', 'W', 'S', 'S', 'E', 'E', 'E',
    ],
  ),
  // Level 10 — gates at opposite edges of the 5x5 board.
  const _LevelSpec(
    grid: [
      [0, 0, 0, 0, 0],
      [null, null, null, null, 1],
      [1, 1, 1, 1, 1],
      [null, 2, null, null, null],
      [null, 3, 3, 3, 3],
    ],
    start: (0, 0),
    goal: (4, 4),
    verifiedSolutionSteps: [
      'E', 'E', 'E', 'E', 'S', 'S', 'W', 'W', 'W', 'S', 'S', 'E', 'E', 'E',
    ],
  ),
  // Level 11 — first 6x6 board, two nearby gates.
  const _LevelSpec(
    grid: [
      [0, 0, 0, 0, 0, 0],
      [null, null, 1, null, null, null],
      [1, 1, 1, 1, 1, 1],
      [null, null, null, 2, null, null],
      [2, 2, 2, 2, 2, 2],
      [3, 3, 3, 3, 3, 3],
    ],
    start: (0, 0),
    goal: (5, 5),
    verifiedSolutionSteps: [
      'E', 'E', 'S', 'S', 'E', 'S', 'S', 'E', 'E', 'S',
    ],
  ),
  // Level 12 — gates near opposite edges plus unused decorative gaps.
  const _LevelSpec(
    grid: [
      [0, 0, 0, null, 0, 0],
      [null, 1, null, null, null, null],
      [1, 1, 1, 1, 1, 1],
      [null, null, null, null, null, 2],
      [2, 2, 2, 2, 2, 2],
      [3, 3, null, 3, 3, 3],
    ],
    start: (0, 0),
    goal: (5, 5),
    verifiedSolutionSteps: [
      'E', 'S', 'S', 'E', 'E', 'E', 'E', 'S', 'S', 'S',
    ],
  ),
  // Level 13 — full-width zig-zag across both edges of the board.
  const _LevelSpec(
    grid: [
      [0, 0, 0, 0, 0, 0],
      [null, null, null, null, null, 1],
      [1, 1, 1, 1, 1, 1],
      [2, null, null, null, null, null],
      [2, 2, 2, 2, 2, 2],
      [3, 3, 3, 3, 3, 3],
    ],
    start: (0, 0),
    goal: (5, 5),
    verifiedSolutionSteps: [
      'E', 'E', 'E', 'E', 'E', 'S', 'S',
      'W', 'W', 'W', 'W', 'W', 'S', 'S',
      'E', 'E', 'E', 'E', 'E', 'S',
    ],
  ),
  // Level 14 — asymmetric gates plus a decorative gap near the goal.
  const _LevelSpec(
    grid: [
      [0, 0, 0, 0, 0, 0],
      [null, null, null, null, 1, null],
      [1, 1, 1, 1, 1, 1],
      [2, null, null, null, null, null],
      [2, 2, 2, 2, 2, 2],
      [3, 3, 3, null, 3, 3],
    ],
    start: (0, 0),
    goal: (5, 5),
    verifiedSolutionSteps: [
      'E', 'E', 'E', 'E', 'S', 'S',
      'W', 'W', 'W', 'W', 'S', 'S',
      'E', 'E', 'E', 'E', 'E', 'S',
    ],
  ),
  // Level 15 — hardest: gates flanked by gaps on both sides of every
  // connector row, full elevation range 0-3.
  const _LevelSpec(
    grid: [
      [0, 0, 0, 0, 0, null],
      [null, null, null, null, 1, null],
      [null, 1, 1, 1, 1, null],
      [null, 2, null, null, null, null],
      [null, 2, 2, 2, 2, 2],
      [3, 3, 3, 3, 3, 3],
    ],
    start: (0, 0),
    goal: (5, 5),
    verifiedSolutionSteps: [
      'E', 'E', 'E', 'E', 'S', 'S',
      'W', 'W', 'W', 'S', 'S',
      'E', 'E', 'E', 'E', 'S',
    ],
  ),
];

class BlockPathScreen extends StatefulWidget {
  const BlockPathScreen({super.key, required this.ctx});

  final GameLevelContext ctx;

  @override
  State<BlockPathScreen> createState() => _BlockPathScreenState();
}

class _BlockPathScreenState extends State<BlockPathScreen> {
  static const double _tileHalfWidth = 26;
  static const double _tileHalfHeight = 15;
  static const double _elevationHeight = 12;
  static const double _cubeDepth = 16;

  late _LevelSpec _spec;
  late _Cell _current;
  int _steps = 0;
  bool _finished = false;
  _Cell? _flashCell;
  Timer? _flashTimer;

  int get _level => widget.ctx.level;

  @override
  void initState() {
    super.initState();
    _spec = _levels[(_level - 1).clamp(0, _levels.length - 1)];
    _current = _spec.start;
  }

  @override
  void dispose() {
    _flashTimer?.cancel();
    super.dispose();
  }

  int? _elevationAt(_Cell cell) => _spec.grid[cell.$1][cell.$2];

  bool _isAdjacent(_Cell a, _Cell b) {
    final dr = (a.$1 - b.$1).abs();
    final dc = (a.$2 - b.$2).abs();
    return (dr == 1 && dc == 0) || (dr == 0 && dc == 1);
  }

  void _flash(_Cell cell) {
    _flashTimer?.cancel();
    setState(() => _flashCell = cell);
    _flashTimer = Timer(const Duration(milliseconds: 220), () {
      if (!mounted) return;
      setState(() => _flashCell = null);
    });
  }

  void _tapCell(_Cell cell) {
    if (_finished) return;
    final targetElevation = _elevationAt(cell);
    if (targetElevation == null) return; // gap: silently ignore
    if (cell == _current) return;

    final currentElevation = _elevationAt(_current)!;
    final valid = _isAdjacent(cell, _current) &&
        (targetElevation - currentElevation).abs() <= 1;

    if (!valid) {
      _flash(cell);
      return;
    }

    setState(() {
      _current = cell;
      _steps++;
    });

    if (_current == _spec.goal) {
      _finished = true;
      final par = _spec.verifiedSolutionSteps.length;
      final stars = _steps == par
          ? 3
          : (_steps <= par + 3 ? 2 : 1);
      Future.microtask(() => widget.ctx.onComplete(stars: stars, score: _steps));
    }
  }

  void _restart() {
    _flashTimer?.cancel();
    setState(() {
      _current = _spec.start;
      _steps = 0;
      _finished = false;
      _flashCell = null;
    });
  }

  Offset _screenPos(_Cell cell, {double? elevationOverride}) {
    final elevation = elevationOverride ?? (_elevationAt(cell) ?? 0).toDouble();
    final r = cell.$1;
    final c = cell.$2;
    final offsetX = _spec.rows * _tileHalfWidth;
    final offsetY = 3 * _elevationHeight + _tileHalfHeight + 24;
    final x = (c - r) * _tileHalfWidth + offsetX;
    final y = (c + r) * _tileHalfHeight - elevation * _elevationHeight + offsetY;
    return Offset(x, y);
  }

  Size _boardSize() {
    final width = (_spec.rows + _spec.cols) * _tileHalfWidth;
    final height = (_spec.rows + _spec.cols) * _tileHalfHeight +
        3 * _elevationHeight +
        _cubeDepth +
        60;
    return Size(width, height);
  }

  Offset _tokenTopLeft() {
    final radius = _tileHalfHeight * 0.75;
    final center = _screenPos(_current) - Offset(0, _tileHalfHeight * 0.55);
    return center - Offset(radius, radius);
  }

  _Cell? _hitTest(Offset localPos) {
    _Cell? best;
    for (var r = 0; r < _spec.rows; r++) {
      for (var c = 0; c < _spec.cols; c++) {
        if (_spec.grid[r][c] == null) continue;
        final center = _screenPos((r, c));
        final dx = (localPos.dx - center.dx).abs() / _tileHalfWidth;
        final dy = (localPos.dy - center.dy).abs() / _tileHalfHeight;
        if (dx + dy <= 1.0) {
          best = (r, c);
        }
      }
    }
    return best;
  }

  @override
  Widget build(BuildContext context) {
    final size = _boardSize();
    return Scaffold(
      appBar: AppBar(
        title: Text('Block Path · Level $_level'),
        actions: [
          TextButton(onPressed: _restart, child: const Text('Restart')),
          TextButton(onPressed: widget.ctx.onExit, child: const Text('Menu')),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Steps: $_steps', style: Theme.of(context).textTheme.titleMedium),
                Text(
                  _finished ? 'Goal reached!' : 'Reach the highlighted goal block',
                  style: TextStyle(
                    color: _finished ? AppTheme.success : AppTheme.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Center(
              child: SizedBox(
                width: size.width,
                height: size.height,
                child: GestureDetector(
                  onTapUp: (details) {
                    final hit = _hitTest(details.localPosition);
                    if (hit != null) _tapCell(hit);
                  },
                  child: Stack(
                    children: [
                      CustomPaint(
                        size: size,
                        painter: _BlockPathPainter(
                          spec: _spec,
                          flashCell: _flashCell,
                          tileHalfWidth: _tileHalfWidth,
                          tileHalfHeight: _tileHalfHeight,
                          elevationHeight: _elevationHeight,
                          cubeDepth: _cubeDepth,
                          screenPos: _screenPos,
                        ),
                      ),
                      AnimatedPositioned(
                        duration: Motion.ms(220),
                        curve: Curves.easeOut,
                        left: _tokenTopLeft().dx,
                        top: _tokenTopLeft().dy,
                        child: _PlayerToken(radius: _tileHalfHeight * 0.75),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              'Tap an adjacent block to step onto it. You can only step to a '
              'block that exists and is at most one level up or down.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlayerToken extends StatelessWidget {
  const _PlayerToken({required this.radius});

  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppTheme.warning,
        border: Border.all(color: Colors.black.withValues(alpha: 0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
    );
  }
}

class _BlockPathPainter extends CustomPainter {
  _BlockPathPainter({
    required this.spec,
    required this.flashCell,
    required this.tileHalfWidth,
    required this.tileHalfHeight,
    required this.elevationHeight,
    required this.cubeDepth,
    required this.screenPos,
  });

  final _LevelSpec spec;
  final _Cell? flashCell;
  final double tileHalfWidth;
  final double tileHalfHeight;
  final double elevationHeight;
  final double cubeDepth;
  final Offset Function(_Cell cell, {double? elevationOverride}) screenPos;

  Color _topColorForElevation(int elevation) {
    final t = elevation / 3.0;
    return Color.lerp(AppTheme.surfaceHigh, const Color(0xFF7DE6F2), t * 0.7)!;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final cells = <_Cell>[];
    for (var r = 0; r < spec.rows; r++) {
      for (var c = 0; c < spec.cols; c++) {
        if (spec.grid[r][c] != null) cells.add((r, c));
      }
    }
    // Paint back-to-front so nearer cubes correctly overlap farther ones.
    cells.sort((a, b) => (a.$1 + a.$2).compareTo(b.$1 + b.$2));

    for (final cell in cells) {
      final elevation = spec.grid[cell.$1][cell.$2]!;
      final center = screenPos(cell);
      final isStart = cell == spec.start;
      final isGoal = cell == spec.goal;
      final isFlash = cell == flashCell;

      var topColor = _topColorForElevation(elevation);
      if (isGoal) topColor = AppTheme.accent;
      if (isFlash) topColor = AppTheme.danger;

      final leftColor = Color.lerp(topColor, Colors.black, 0.35)!;
      final rightColor = Color.lerp(topColor, Colors.black, 0.55)!;

      final top = Offset(center.dx, center.dy - tileHalfHeight);
      final right = Offset(center.dx + tileHalfWidth, center.dy);
      final bottom = Offset(center.dx, center.dy + tileHalfHeight);
      final left = Offset(center.dx - tileHalfWidth, center.dy);

      // Left face.
      final leftFace = Path()
        ..moveTo(left.dx, left.dy)
        ..lineTo(bottom.dx, bottom.dy)
        ..lineTo(bottom.dx, bottom.dy + cubeDepth)
        ..lineTo(left.dx, left.dy + cubeDepth)
        ..close();
      canvas.drawPath(leftFace, Paint()..color = leftColor);

      // Right face.
      final rightFace = Path()
        ..moveTo(right.dx, right.dy)
        ..lineTo(bottom.dx, bottom.dy)
        ..lineTo(bottom.dx, bottom.dy + cubeDepth)
        ..lineTo(right.dx, right.dy + cubeDepth)
        ..close();
      canvas.drawPath(rightFace, Paint()..color = rightColor);

      // Top face.
      final topFace = Path()
        ..moveTo(top.dx, top.dy)
        ..lineTo(right.dx, right.dy)
        ..lineTo(bottom.dx, bottom.dy)
        ..lineTo(left.dx, left.dy)
        ..close();
      canvas.drawPath(topFace, Paint()..color = topColor);
      canvas.drawPath(
        topFace,
        Paint()
          ..color = Colors.black.withValues(alpha: 0.18)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2,
      );

      if (isStart) {
        canvas.drawPath(
          topFace,
          Paint()
            ..color = AppTheme.success
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _BlockPathPainter oldDelegate) =>
      oldDelegate.flashCell != flashCell || oldDelegate.spec != spec;
}
