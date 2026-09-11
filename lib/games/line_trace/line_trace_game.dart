import 'dart:math';

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/game_definition.dart';
import '../../core/game_level_context.dart';

/// Reference implementation: an original dot-grid path puzzle. The player
/// traces a single line from a fixed start dot to a fixed end dot along
/// grid edges; the line divides the panel into regions and every colored
/// square must share its region with only same-colored squares. This is a
/// generic "path divides regions / match colors per region" mechanic (a
/// long-standing puzzle genre) implemented with original layouts, an
/// original name and no third-party art, symbols or branding.
final GameDefinition lineTraceDefinition = GameDefinition(
  id: 'line_trace',
  title: 'Region Trace',
  tagline: 'Trace a path that separates the colors',
  icon: Icons.route_rounded,
  tint: const GameTint(Color(0xFF38BDF8), Color(0xFF0369A1)),
  mode: GameMode.levels,
  levelCount: 15,
  builder: (context, ctx) => LineTraceScreen(ctx: ctx),
);

/// Colors used for the constraint squares. Kept distinct from the
/// success/danger flash colors used for feedback.
const List<Color> _squareColors = [
  Color(0xFF60A5FA), // blue
  Color(0xFFFB923C), // orange
  Color(0xFFC084FC), // purple (introduced on later, 3-color levels)
];

/// One hand-authored puzzle: a dot grid, fixed start/end dots, a map of
/// cell -> constraint color index, and a verified solution path (the exact
/// sequence of dots that solves the panel). The solution is never shown to
/// the player; it exists purely so every level is guaranteed solvable and
/// so the star rating has a reference to compare against.
class _LevelData {
  const _LevelData({
    required this.dotsX,
    required this.dotsY,
    required this.start,
    required this.end,
    required this.cellColors,
    required this.solution,
  });

  final int dotsX;
  final int dotsY;
  final Point<int> start;
  final Point<int> end;

  /// Cell coordinate (cx, cy) -> color index into [_squareColors].
  final Map<Point<int>, int> cellColors;

  /// A verified sequence of dots from [start] to [end] that solves the
  /// panel. Hand-traced and checked against the region algorithm below
  /// while authoring these levels.
  final List<Point<int>> solution;
}

/// Levels 1-6: a 3x3-cell panel (4x4 dots) split by a single diagonal
/// staircase path from the top-left dot to the bottom-right dot. That
/// staircase always separates the panel into exactly two regions: cells
/// with (cy >= cx) end up on one side, cells with (cy < cx) on the other.
/// Verified by hand-tracing the wall segments the path creates.
const List<Point<int>> _staircase3 = [
  Point(0, 0),
  Point(1, 0),
  Point(1, 1),
  Point(2, 1),
  Point(2, 2),
  Point(3, 2),
  Point(3, 3),
];

/// Levels 7-9: same diagonal-staircase idea on a 4x4-cell panel (5x5 dots).
const List<Point<int>> _staircase4 = [
  Point(0, 0),
  Point(1, 0),
  Point(1, 1),
  Point(2, 1),
  Point(2, 2),
  Point(3, 2),
  Point(3, 3),
  Point(4, 3),
  Point(4, 4),
];

/// Levels 10-12: a 4x4-cell panel (5x5 dots). The path opens with a small
/// loop that seals off the top-left cell into its own single-cell region,
/// then continues as a staircase to the bottom-right corner. Hand-traced
/// wall segments confirm three regions: {(0,0)}, {(0,2),(0,3),(1,3)}, and
/// the remaining 12 cells.
const List<Point<int>> _pocket4 = [
  Point(0, 0),
  Point(1, 0),
  Point(1, 1),
  Point(0, 1),
  Point(0, 2),
  Point(1, 2),
  Point(1, 3),
  Point(2, 3),
  Point(2, 4),
  Point(3, 4),
  Point(4, 4),
];

/// Levels 13-15: a 5x5-cell panel (6x6 dots) using the same opening pocket
/// followed by a longer staircase. Hand-traced wall segments confirm three
/// regions: {(0,0)}, {(0,2),(0,3),(0,4),(1,3),(1,4),(2,4)}, and the
/// remaining 18 cells.
const List<Point<int>> _pocket5 = [
  Point(0, 0),
  Point(1, 0),
  Point(1, 1),
  Point(0, 1),
  Point(0, 2),
  Point(1, 2),
  Point(1, 3),
  Point(2, 3),
  Point(2, 4),
  Point(3, 4),
  Point(3, 5),
  Point(4, 5),
  Point(5, 5),
];

final List<_LevelData> _levels = [
  // --- Levels 1-6: 3x3 cells, 2 colors, diagonal split -------------------
  _LevelData(
    dotsX: 4,
    dotsY: 4,
    start: const Point(0, 0),
    end: const Point(3, 3),
    cellColors: {
      Point(0, 1): 0,
      Point(1, 1): 0,
      Point(1, 0): 1,
      Point(2, 0): 1,
    },
    solution: _staircase3,
  ),
  _LevelData(
    dotsX: 4,
    dotsY: 4,
    start: const Point(0, 0),
    end: const Point(3, 3),
    cellColors: {
      Point(0, 0): 0,
      Point(1, 1): 0,
      Point(2, 0): 1,
      Point(2, 1): 1,
    },
    solution: _staircase3,
  ),
  _LevelData(
    dotsX: 4,
    dotsY: 4,
    start: const Point(0, 0),
    end: const Point(3, 3),
    cellColors: {
      Point(0, 2): 0,
      Point(1, 2): 0,
      Point(2, 2): 0,
      Point(1, 0): 1,
      Point(2, 0): 1,
    },
    solution: _staircase3,
  ),
  _LevelData(
    dotsX: 4,
    dotsY: 4,
    start: const Point(0, 0),
    end: const Point(3, 3),
    cellColors: {
      Point(0, 0): 0,
      Point(0, 1): 0,
      Point(1, 1): 0,
      Point(1, 0): 1,
      Point(2, 0): 1,
      Point(2, 1): 1,
    },
    solution: _staircase3,
  ),
  _LevelData(
    dotsX: 4,
    dotsY: 4,
    start: const Point(0, 0),
    end: const Point(3, 3),
    cellColors: {
      Point(0, 0): 0,
      Point(0, 2): 0,
      Point(1, 1): 0,
      Point(1, 2): 0,
      Point(1, 0): 1,
      Point(2, 0): 1,
      Point(2, 1): 1,
    },
    solution: _staircase3,
  ),
  _LevelData(
    dotsX: 4,
    dotsY: 4,
    start: const Point(0, 0),
    end: const Point(3, 3),
    cellColors: {
      Point(0, 0): 0,
      Point(0, 1): 0,
      Point(0, 2): 0,
      Point(2, 2): 0,
      Point(1, 0): 1,
      Point(2, 0): 1,
      Point(2, 1): 1,
    },
    solution: _staircase3,
  ),

  // --- Levels 7-9: 4x4 cells, 2 colors, diagonal split -------------------
  _LevelData(
    dotsX: 5,
    dotsY: 5,
    start: const Point(0, 0),
    end: const Point(4, 4),
    cellColors: {
      Point(0, 0): 0,
      Point(1, 1): 0,
      Point(2, 2): 0,
      Point(1, 0): 1,
      Point(2, 0): 1,
      Point(3, 0): 1,
    },
    solution: _staircase4,
  ),
  _LevelData(
    dotsX: 5,
    dotsY: 5,
    start: const Point(0, 0),
    end: const Point(4, 4),
    cellColors: {
      Point(0, 1): 0,
      Point(0, 3): 0,
      Point(1, 3): 0,
      Point(3, 3): 0,
      Point(2, 1): 1,
      Point(3, 1): 1,
      Point(3, 2): 1,
    },
    solution: _staircase4,
  ),
  _LevelData(
    dotsX: 5,
    dotsY: 5,
    start: const Point(0, 0),
    end: const Point(4, 4),
    cellColors: {
      Point(0, 0): 0,
      Point(0, 2): 0,
      Point(1, 1): 0,
      Point(1, 3): 0,
      Point(2, 3): 0,
      Point(1, 0): 1,
      Point(2, 0): 1,
      Point(2, 1): 1,
      Point(3, 2): 1,
    },
    solution: _staircase4,
  ),

  // --- Levels 10-12: 4x4 cells, 3 colors, pocket split -------------------
  _LevelData(
    dotsX: 5,
    dotsY: 5,
    start: const Point(0, 0),
    end: const Point(4, 4),
    cellColors: {
      Point(0, 0): 2,
      Point(0, 2): 0,
      Point(0, 3): 0,
      Point(1, 0): 1,
      Point(3, 3): 1,
    },
    solution: _pocket4,
  ),
  _LevelData(
    dotsX: 5,
    dotsY: 5,
    start: const Point(0, 0),
    end: const Point(4, 4),
    cellColors: {
      Point(0, 0): 2,
      Point(0, 2): 0,
      Point(1, 3): 0,
      Point(2, 1): 1,
      Point(3, 2): 1,
    },
    solution: _pocket4,
  ),
  _LevelData(
    dotsX: 5,
    dotsY: 5,
    start: const Point(0, 0),
    end: const Point(4, 4),
    cellColors: {
      Point(0, 0): 2,
      Point(0, 3): 0,
      Point(1, 3): 0,
      Point(1, 0): 1,
      Point(2, 0): 1,
      Point(3, 3): 1,
    },
    solution: _pocket4,
  ),

  // --- Levels 13-15: 5x5 cells, 3 colors, pocket split -------------------
  _LevelData(
    dotsX: 6,
    dotsY: 6,
    start: const Point(0, 0),
    end: const Point(5, 5),
    cellColors: {
      Point(0, 0): 2,
      Point(0, 3): 0,
      Point(1, 4): 0,
      Point(2, 1): 1,
      Point(4, 3): 1,
    },
    solution: _pocket5,
  ),
  _LevelData(
    dotsX: 6,
    dotsY: 6,
    start: const Point(0, 0),
    end: const Point(5, 5),
    cellColors: {
      Point(0, 0): 2,
      Point(0, 2): 0,
      Point(0, 4): 0,
      Point(1, 3): 0,
      Point(3, 0): 1,
      Point(4, 1): 1,
      Point(4, 4): 1,
    },
    solution: _pocket5,
  ),
  _LevelData(
    dotsX: 6,
    dotsY: 6,
    start: const Point(0, 0),
    end: const Point(5, 5),
    cellColors: {
      Point(0, 0): 2,
      Point(0, 3): 0,
      Point(1, 3): 0,
      Point(2, 4): 0,
      Point(1, 0): 1,
      Point(2, 0): 1,
      Point(3, 3): 1,
      Point(4, 2): 1,
    },
    solution: _pocket5,
  ),
];

class LineTraceScreen extends StatefulWidget {
  const LineTraceScreen({super.key, required this.ctx});

  final GameLevelContext ctx;

  @override
  State<LineTraceScreen> createState() => _LineTraceScreenState();
}

class _LineTraceScreenState extends State<LineTraceScreen> {
  late _LevelData _data;
  late List<Point<int>> _path;
  Set<Point<int>> _flashCells = {};
  Color? _flashColor;
  int _failedAttempts = 0;
  bool _locked = false;

  @override
  void initState() {
    super.initState();
    final index = (widget.ctx.level - 1).clamp(0, _levels.length - 1);
    _data = _levels[index];
    _path = [_data.start];
  }

  bool get _isComplete => _path.length > 1 && _path.last == _data.end;

  int _starsForAttempts() {
    if (_failedAttempts <= 0) return 3;
    if (_failedAttempts <= 2) return 2;
    return 1;
  }

  void _handleTouch(Offset local, double cellSize) {
    if (_locked) return;
    final gx = (local.dx / cellSize).round().clamp(0, _data.dotsX - 1);
    final gy = (local.dy / cellSize).round().clamp(0, _data.dotsY - 1);
    final dot = Point(gx, gy);
    if (dot == _path.last) return;

    // Drag-back undo: returning to the second-to-last dot pops the last
    // segment, giving a forgiving undo-by-dragback feel.
    if (_path.length >= 2 && dot == _path[_path.length - 2]) {
      setState(() => _path.removeLast());
      return;
    }

    final last = _path.last;
    final isAdjacent = (dot.x - last.x).abs() + (dot.y - last.y).abs() == 1;
    if (!isAdjacent || _path.contains(dot)) return;

    setState(() => _path.add(dot));
    if (_isComplete) _checkSolution();
  }

  void _clear() {
    if (_locked) return;
    setState(() {
      if (_path.length > 1) _failedAttempts++;
      _path = [_data.start];
      _flashCells = {};
      _flashColor = null;
    });
  }

  /// Flood-fills the panel's cells, treating drawn path segments as walls
  /// between adjacent cells, and returns the resulting connected regions.
  List<Set<Point<int>>> _computeRegions() {
    final gw = _data.dotsX - 1;
    final gh = _data.dotsY - 1;
    final vWalls = <Point<int>>{}; // (x, y) => vertical segment (x,y)-(x,y+1)
    final hWalls = <Point<int>>{}; // (x, y) => horizontal segment (x,y)-(x+1,y)
    for (var i = 0; i < _path.length - 1; i++) {
      final a = _path[i];
      final b = _path[i + 1];
      if (a.x == b.x) {
        vWalls.add(Point(a.x, min(a.y, b.y)));
      } else {
        hWalls.add(Point(min(a.x, b.x), a.y));
      }
    }

    bool blockedRight(int cx, int cy) => vWalls.contains(Point(cx + 1, cy));
    bool blockedDown(int cx, int cy) => hWalls.contains(Point(cx, cy + 1));

    final visited = <Point<int>>{};
    final regions = <Set<Point<int>>>[];
    for (var cy = 0; cy < gh; cy++) {
      for (var cx = 0; cx < gw; cx++) {
        final start = Point(cx, cy);
        if (visited.contains(start)) continue;
        final region = <Point<int>>{};
        final queue = <Point<int>>[start];
        visited.add(start);
        while (queue.isNotEmpty) {
          final cell = queue.removeLast();
          region.add(cell);
          final x = cell.x;
          final y = cell.y;
          final neighbors = <Point<int>>[
            if (x + 1 < gw && !blockedRight(x, y)) Point(x + 1, y),
            if (x - 1 >= 0 && !blockedRight(x - 1, y)) Point(x - 1, y),
            if (y + 1 < gh && !blockedDown(x, y)) Point(x, y + 1),
            if (y - 1 >= 0 && !blockedDown(x, y - 1)) Point(x, y - 1),
          ];
          for (final n in neighbors) {
            if (visited.add(n)) queue.add(n);
          }
        }
        regions.add(region);
      }
    }
    return regions;
  }

  void _checkSolution() {
    final regions = _computeRegions();
    Set<Point<int>>? offending;
    for (final region in regions) {
      final colorsInRegion = <int>{};
      for (final cell in region) {
        final c = _data.cellColors[cell];
        if (c != null) colorsInRegion.add(c);
      }
      if (colorsInRegion.length > 1) {
        offending = region;
        break;
      }
    }

    if (offending == null) {
      setState(() {
        _locked = true;
        _flashCells = _data.cellColors.keys.toSet();
        _flashColor = AppTheme.success;
      });
      Future.delayed(const Duration(milliseconds: 600), () {
        if (!mounted) return;
        widget.ctx.onComplete(stars: _starsForAttempts());
      });
    } else {
      setState(() {
        _locked = true;
        _flashCells = offending!;
        _flashColor = AppTheme.danger;
        _failedAttempts++;
      });
      Future.delayed(const Duration(milliseconds: 600), () {
        if (!mounted) return;
        setState(() {
          _path = [_data.start];
          _flashCells = {};
          _flashColor = null;
          _locked = false;
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Level ${widget.ctx.level}'),
        actions: [
          TextButton(
            onPressed: widget.ctx.onExit,
            child: const Text('Give up'),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Text(
              'Attempts: $_failedAttempts',
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
                      final size = constraints.maxWidth;
                      final cellSize = size / (_data.dotsX - 1);
                      return GestureDetector(
                        onPanStart: (d) => _handleTouch(d.localPosition, cellSize),
                        onPanUpdate: (d) => _handleTouch(d.localPosition, cellSize),
                        child: CustomPaint(
                          size: Size(size, size),
                          painter: _LineTracePainter(
                            data: _data,
                            path: _path,
                            flashCells: _flashCells,
                            flashColor: _flashColor,
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
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
            child: ElevatedButton(
              onPressed: _clear,
              child: const Text('Clear'),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              'Drag from start to end. Every region your path carves out must '
              'contain only one color of square.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

class _LineTracePainter extends CustomPainter {
  _LineTracePainter({
    required this.data,
    required this.path,
    required this.flashCells,
    required this.flashColor,
  });

  final _LevelData data;
  final List<Point<int>> path;
  final Set<Point<int>> flashCells;
  final Color? flashColor;

  @override
  void paint(Canvas canvas, Size size) {
    final gw = data.dotsX - 1;
    final gh = data.dotsY - 1;
    final cellSize = size.width / gw;

    final boardRect = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawRRect(
      RRect.fromRectAndRadius(boardRect, const Radius.circular(16)),
      Paint()..color = AppTheme.surfaceHigh,
    );

    // Faint grid lines to show cell boundaries.
    final gridPaint = Paint()
      ..color = AppTheme.accentSoft.withValues(alpha: 0.25)
      ..strokeWidth = 1;
    for (var i = 0; i <= gw; i++) {
      final x = i * cellSize;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (var j = 0; j <= gh; j++) {
      final y = j * cellSize;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Flash overlay for the regions being highlighted (success/error).
    if (flashColor != null) {
      final flashPaint = Paint()..color = flashColor!.withValues(alpha: 0.35);
      for (final cell in flashCells) {
        final rect = Rect.fromLTWH(
          cell.x * cellSize,
          cell.y * cellSize,
          cellSize,
          cellSize,
        );
        canvas.drawRect(rect, flashPaint);
      }
    }

    // Colored constraint squares.
    for (final entry in data.cellColors.entries) {
      final cell = entry.key;
      final color = _squareColors[entry.value % _squareColors.length];
      final margin = cellSize * 0.28;
      final rect = Rect.fromLTWH(
        cell.x * cellSize + margin,
        cell.y * cellSize + margin,
        cellSize - margin * 2,
        cellSize - margin * 2,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(6)),
        Paint()..color = color,
      );
    }

    // Dots.
    final dotPaint = Paint()..color = AppTheme.textSecondary;
    for (var y = 0; y < data.dotsY; y++) {
      for (var x = 0; x < data.dotsX; x++) {
        canvas.drawCircle(Offset(x * cellSize, y * cellSize), 4, dotPaint);
      }
    }

    // Start/end markers.
    canvas.drawCircle(
      Offset(data.start.x * cellSize, data.start.y * cellSize),
      9,
      Paint()..color = AppTheme.accent,
    );
    canvas.drawCircle(
      Offset(data.end.x * cellSize, data.end.y * cellSize),
      9,
      Paint()..color = AppTheme.warning,
    );

    // The traced path.
    if (path.length > 1) {
      final pathPaint = Paint()
        ..color = AppTheme.accent
        ..strokeWidth = 8
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;
      final uiPath = Path()
        ..moveTo(path.first.x * cellSize, path.first.y * cellSize);
      for (final dot in path.skip(1)) {
        uiPath.lineTo(dot.x * cellSize, dot.y * cellSize);
      }
      canvas.drawPath(uiPath, pathPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _LineTracePainter oldDelegate) {
    return oldDelegate.path != path ||
        oldDelegate.flashCells != flashCells ||
        oldDelegate.flashColor != flashColor;
  }
}
