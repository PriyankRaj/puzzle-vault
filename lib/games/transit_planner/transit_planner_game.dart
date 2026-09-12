import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/game_definition.dart';
import '../../core/game_level_context.dart';

/// Reference implementation: an original network-design strategy game,
/// loosely (mechanically) inspired by the generic idea of "connect matching
/// stations on a map using a limited number of lines" as an abstract
/// puzzle genre. Original layouts, original name, original code, no
/// third-party art, branding or level data.
///
/// The player is handed a fixed, small set of "transit lines" (2-4,
/// depending on the level). Each line is an ordered chain of straight
/// segments between stations, built by dragging from station to station.
/// The goal: touch every station with some line, and make sure every pair
/// of stations that share a shape/type can reach each other by walking
/// along drawn segments (switching lines at any station they share).
final GameDefinition transitPlannerDefinition = GameDefinition(
  id: 'transit_planner',
  title: 'Route Planner',
  tagline: 'Connect every station with limited lines',
  icon: Icons.alt_route_rounded,
  tint: const GameTint(Color(0xFF818CF8), Color(0xFF4338CA)),
  mode: GameMode.levels,
  levelCount: 15,
  helpText:
      'Pick a line above, then drag from station to station to extend it. '
      'Every station must be touched by some line, and any stations that '
      'share the same shape must be reachable from one another by walking '
      'along your drawn lines. Solve it using as few lines as possible for '
      'more stars.',
  builder: (context, ctx) => TransitPlannerScreen(ctx: ctx),
);

/// Fill colors for the three station shape types (circle, triangle,
/// square). Deliberately distinct from [_lineColors] so a station's type
/// is never confused with which line is currently passing through it.
const List<Color> _stationColors = [
  Color(0xFFFB7185), // circle
  Color(0xFF60A5FA), // triangle
  Color(0xFF34D399), // square
];

/// Colors for up to 4 line slots, pulled straight from the shared theme.
List<Color> get _lineColors => [
  AppTheme.accent,
  AppTheme.success,
  AppTheme.warning,
  AppTheme.danger,
];

/// One station: a fixed position in normalized (0.0-1.0) canvas space plus
/// a shape/type index (0 = circle, 1 = triangle, 2 = square).
class _Station {
  const _Station(this.pos, this.shapeType);
  final Offset pos;
  final int shapeType;
}

/// One hand-authored level: a fixed station layout and the number of line
/// slots the player is given to solve it.
///
/// Solvability proof used for every level below: the stations in each
/// level are listed in walking order around a loop (station i is
/// geometrically adjacent to station i+1). A single line drawn as
/// 0 -> 1 -> 2 -> ... -> (n-1) touches every station and puts every
/// station in one connected component, so it trivially satisfies both win
/// conditions (full coverage, and every same-type pair mutually
/// reachable) while using only 1 of the available line slots. That is
/// verified per-level in the comment above each entry, together with the
/// station-type breakdown that makes the connectivity requirement real
/// (any type that appears 2+ times must all end up in one component).
class _LevelData {
  const _LevelData({required this.stations, required this.maxLines});
  final List<_Station> stations;
  final int maxLines;
}

// Station layouts: n stations placed evenly around a circle, in walking
// order, so that the "spine" solution (0->1->...->n-1) referenced above is
// always a single connected sweep around the ring.

const List<Offset> _ring5 = [
  Offset(0.85, 0.50),
  Offset(0.61, 0.83),
  Offset(0.22, 0.71),
  Offset(0.22, 0.29),
  Offset(0.61, 0.17),
];

const List<Offset> _ring6 = [
  Offset(0.85, 0.50),
  Offset(0.68, 0.80),
  Offset(0.33, 0.80),
  Offset(0.15, 0.50),
  Offset(0.33, 0.20),
  Offset(0.68, 0.20),
];

const List<Offset> _ring7 = [
  Offset(0.85, 0.50),
  Offset(0.72, 0.77),
  Offset(0.42, 0.84),
  Offset(0.18, 0.65),
  Offset(0.18, 0.35),
  Offset(0.42, 0.16),
  Offset(0.72, 0.23),
];

const List<Offset> _ring8 = [
  Offset(0.85, 0.50),
  Offset(0.75, 0.75),
  Offset(0.50, 0.85),
  Offset(0.25, 0.75),
  Offset(0.15, 0.50),
  Offset(0.25, 0.25),
  Offset(0.50, 0.15),
  Offset(0.75, 0.25),
];

const List<Offset> _ring9 = [
  Offset(0.85, 0.50),
  Offset(0.77, 0.73),
  Offset(0.56, 0.84),
  Offset(0.33, 0.80),
  Offset(0.17, 0.62),
  Offset(0.17, 0.38),
  Offset(0.33, 0.20),
  Offset(0.56, 0.16),
  Offset(0.77, 0.27),
];

const List<Offset> _ring10 = [
  Offset(0.85, 0.50),
  Offset(0.78, 0.71),
  Offset(0.61, 0.83),
  Offset(0.39, 0.83),
  Offset(0.22, 0.71),
  Offset(0.15, 0.50),
  Offset(0.22, 0.29),
  Offset(0.39, 0.17),
  Offset(0.61, 0.17),
  Offset(0.78, 0.29),
];

const List<Offset> _ring11 = [
  Offset(0.85, 0.50),
  Offset(0.79, 0.69),
  Offset(0.65, 0.82),
  Offset(0.45, 0.85),
  Offset(0.27, 0.76),
  Offset(0.16, 0.60),
  Offset(0.16, 0.40),
  Offset(0.27, 0.24),
  Offset(0.45, 0.15),
  Offset(0.65, 0.18),
  Offset(0.79, 0.31),
];

const List<Offset> _ring12 = [
  Offset(0.85, 0.50),
  Offset(0.80, 0.68),
  Offset(0.68, 0.80),
  Offset(0.50, 0.85),
  Offset(0.32, 0.80),
  Offset(0.20, 0.68),
  Offset(0.15, 0.50),
  Offset(0.20, 0.32),
  Offset(0.32, 0.20),
  Offset(0.50, 0.15),
  Offset(0.68, 0.20),
  Offset(0.80, 0.32),
];

/// Builds a level's station list by cycling shape types `0,1,2,0,1,2,...`
/// starting at [phase], zipped with a ring layout. Grouping the type
/// assignment this way guarantees every type that can repeat (any level
/// with 2+ stations of a type) does repeat, which is what makes the
/// "same-type stations must be mutually reachable" rule meaningful.
List<_Station> _ring(List<Offset> positions, int phase) => [
  for (var i = 0; i < positions.length; i++)
    _Station(positions[i], (i + phase) % 3),
];

final List<_LevelData> _levels = [
  // Level 1: 5 stations - circles {0,3}, triangles {1,4}, square {2}.
  // Spine 0-1-2-3-4 touches all 5 and connects both repeated types using
  // just 1 of 2 available lines.
  _LevelData(stations: _ring(_ring5, 0), maxLines: 2),

  // Level 2: 5 stations - triangles {0,3}, squares {1,4}, circle {2}.
  // Spine 0-1-2-3-4 solves it with 1 of 2 lines.
  _LevelData(stations: _ring(_ring5, 1), maxLines: 2),

  // Level 3: 6 stations - circles {0,3}, triangles {1,4}, squares {2,5}.
  // Spine 0-1-2-3-4-5 solves it with 1 of 2 lines.
  _LevelData(stations: _ring(_ring6, 0), maxLines: 2),

  // Level 4: 6 stations - triangles {0,3}, squares {1,4}, circles {2,5}.
  // Spine 0-1-2-3-4-5 solves it with 1 of 3 lines.
  _LevelData(stations: _ring(_ring6, 1), maxLines: 3),

  // Level 5: 7 stations - circles {0,3,6}, triangles {1,4}, squares {2,5}.
  // Spine 0..6 solves it with 1 of 3 lines.
  _LevelData(stations: _ring(_ring7, 0), maxLines: 3),

  // Level 6: 7 stations - triangles {0,3,6}, squares {1,4}, circles {2,5}.
  // Spine 0..6 solves it with 1 of 3 lines.
  _LevelData(stations: _ring(_ring7, 1), maxLines: 3),

  // Level 7: 8 stations - circles {0,3,6}, triangles {1,4,7}, squares {2,5}.
  // Spine 0..7 solves it with 1 of 3 lines.
  _LevelData(stations: _ring(_ring8, 0), maxLines: 3),

  // Level 8: 8 stations - triangles {0,3,6}, squares {1,4,7}, circles {2,5}.
  // Spine 0..7 solves it with 1 of 4 lines.
  _LevelData(stations: _ring(_ring8, 1), maxLines: 4),

  // Level 9: 9 stations - circles {0,3,6}, triangles {1,4,7}, squares {2,5,8}.
  // Spine 0..8 solves it with 1 of 4 lines.
  _LevelData(stations: _ring(_ring9, 0), maxLines: 4),

  // Level 10: 9 stations - triangles {0,3,6}, squares {1,4,7}, circles {2,5,8}.
  // Spine 0..8 solves it with 1 of 4 lines.
  _LevelData(stations: _ring(_ring9, 1), maxLines: 4),

  // Level 11: 10 stations - circles {0,3,6,9}, triangles {1,4,7}, squares {2,5,8}.
  // Spine 0..9 solves it with 1 of 4 lines.
  _LevelData(stations: _ring(_ring10, 0), maxLines: 4),

  // Level 12: 10 stations - triangles {0,3,6,9}, squares {1,4,7}, circles {2,5,8}.
  // Spine 0..9 solves it with 1 of 4 lines.
  _LevelData(stations: _ring(_ring10, 1), maxLines: 4),

  // Level 13: 11 stations - circles {0,3,6,9}, triangles {1,4,7,10}, squares {2,5,8}.
  // Spine 0..10 solves it with 1 of 4 lines.
  _LevelData(stations: _ring(_ring11, 0), maxLines: 4),

  // Level 14: 11 stations - triangles {0,3,6,9}, squares {1,4,7,10}, circles {2,5,8}.
  // Spine 0..10 solves it with 1 of 4 lines.
  _LevelData(stations: _ring(_ring11, 1), maxLines: 4),

  // Level 15: 12 stations - circles {0,3,6,9}, triangles {1,4,7,10}, squares {2,5,8,11}.
  // Spine 0..11 solves it with 1 of 4 lines.
  _LevelData(stations: _ring(_ring12, 0), maxLines: 4),
];

class TransitPlannerScreen extends StatefulWidget {
  const TransitPlannerScreen({super.key, required this.ctx});

  final GameLevelContext ctx;

  @override
  State<TransitPlannerScreen> createState() => _TransitPlannerScreenState();
}

class _TransitPlannerScreenState extends State<TransitPlannerScreen> {
  late _LevelData _data;
  late List<List<int>> _lines;
  int _activeLine = 0;
  int? _dragCursor;
  bool _completed = false;
  bool _flashSuccess = false;

  @override
  void initState() {
    super.initState();
    final index = (widget.ctx.level - 1).clamp(0, _levels.length - 1);
    _data = _levels[index];
    _lines = List.generate(_data.maxLines, (_) => <int>[]);
  }

  int? _stationAt(Offset local, double size) {
    const hitRadius = 0.07;
    int? best;
    var bestDist = double.infinity;
    for (var i = 0; i < _data.stations.length; i++) {
      final p = _data.stations[i].pos;
      final dx = p.dx - local.dx / size;
      final dy = p.dy - local.dy / size;
      final dist = dx * dx + dy * dy;
      if (dist < hitRadius * hitRadius && dist < bestDist) {
        bestDist = dist;
        best = i;
      }
    }
    return best;
  }

  void _onPanStart(Offset local, double size) {
    if (_completed) return;
    final idx = _stationAt(local, size);
    if (idx == null) {
      _dragCursor = null;
      return;
    }
    final line = _lines[_activeLine];
    if (line.isNotEmpty && idx != line.last) {
      // Not touching this line's current end: ignore the gesture so the
      // player must deliberately continue from where the line left off.
      _dragCursor = null;
      return;
    }
    _dragCursor = idx;
    if (line.isEmpty) {
      setState(() => line.add(idx));
      _afterEdit();
    }
  }

  void _onPanUpdate(Offset local, double size) {
    if (_completed || _dragCursor == null) return;
    final idx = _stationAt(local, size);
    if (idx == null || idx == _dragCursor) return;
    final line = _lines[_activeLine];
    if (line.length >= 2 && idx == line[line.length - 2]) {
      // Drag-back undo: returning to the previous station pops the
      // last-added segment.
      setState(() => line.removeLast());
      _dragCursor = idx;
      _afterEdit();
      return;
    }
    if (line.isEmpty || idx != line.last) {
      setState(() => line.add(idx));
      _dragCursor = idx;
      _afterEdit();
    }
  }

  void _clearLine(int i) {
    if (_completed) return;
    setState(() => _lines[i].clear());
    if (_dragCursor != null && i == _activeLine) _dragCursor = null;
  }

  /// Builds the combined graph from every line's consecutive station
  /// pairs, then checks: (1) every station touched, (2) for every shape
  /// type with 2+ stations, all stations of that type share one connected
  /// component (Union-Find over the drawn segments).
  bool _isSolved() {
    final n = _data.stations.length;
    final touched = <int>{};
    final parent = List.generate(n, (i) => i);
    int find(int x) {
      while (parent[x] != x) {
        x = parent[x];
      }
      return x;
    }

    void union(int a, int b) {
      final ra = find(a);
      final rb = find(b);
      if (ra != rb) parent[ra] = rb;
    }

    for (final line in _lines) {
      for (var i = 0; i < line.length; i++) {
        touched.add(line[i]);
        if (i > 0) union(line[i - 1], line[i]);
      }
    }
    if (touched.length != n) return false;

    final byType = <int, List<int>>{};
    for (var i = 0; i < n; i++) {
      byType.putIfAbsent(_data.stations[i].shapeType, () => []).add(i);
    }
    for (final group in byType.values) {
      if (group.length < 2) continue;
      final root = find(group.first);
      for (final s in group.skip(1)) {
        if (find(s) != root) return false;
      }
    }
    return true;
  }

  void _afterEdit() {
    if (_completed) return;
    if (!_isSolved()) return;
    final usedLines = _lines.where((l) => l.length >= 2).length;
    final stars = usedLines <= _data.maxLines / 2 ? 3 : 2;
    setState(() {
      _completed = true;
      _flashSuccess = true;
    });
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      widget.ctx.onComplete(stars: stars);
    });
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
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (var i = 0; i < _data.maxLines; i++) _buildLineSlot(i),
              ],
            ),
          ),
          Expanded(
            child: Center(
              child: AspectRatio(
                aspectRatio: 1,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final size = constraints.maxWidth;
                      return GestureDetector(
                        onPanStart: (d) => _onPanStart(d.localPosition, size),
                        onPanUpdate: (d) => _onPanUpdate(d.localPosition, size),
                        onPanEnd: (_) => _dragCursor = null,
                        child: CustomPaint(
                          size: Size(size, size),
                          painter: _TransitPainter(
                            data: _data,
                            lines: _lines,
                            flashSuccess: _flashSuccess,
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
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
            child: Text(
              'Pick a line above, then drag between stations to extend it. '
              'Every station needs a line, and every matching shape must be '
              'reachable by walking the drawn lines.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLineSlot(int i) {
    final color = _lineColors[i % _lineColors.length];
    final selected = i == _activeLine;
    final drawn = _lines[i].length >= 2;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => setState(() => _activeLine = i),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.28) : AppTheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? color : AppTheme.surfaceHigh,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Text(
              'Line ${i + 1}',
              style: TextStyle(color: AppTheme.textPrimary),
            ),
            if (drawn) ...[
              const SizedBox(width: 4),
              InkWell(
                onTap: () => _clearLine(i),
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: Icon(
                    Icons.close_rounded,
                    size: 16,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TransitPainter extends CustomPainter {
  _TransitPainter({
    required this.data,
    required this.lines,
    required this.flashSuccess,
  });

  final _LevelData data;
  final List<List<int>> lines;
  final bool flashSuccess;

  @override
  void paint(Canvas canvas, Size size) {
    final boardRect = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawRRect(
      RRect.fromRectAndRadius(boardRect, const Radius.circular(16)),
      Paint()..color = AppTheme.surfaceHigh,
    );

    Offset px(Offset normalized) =>
        Offset(normalized.dx * size.width, normalized.dy * size.height);

    // Drawn lines, underneath the station shapes.
    for (var i = 0; i < lines.length; i++) {
      final stationsInLine = lines[i];
      if (stationsInLine.length < 2) continue;
      final paint = Paint()
        ..color = _lineColors[i % _lineColors.length]
        ..strokeWidth = 7
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;
      final path = Path()
        ..moveTo(
          px(data.stations[stationsInLine.first].pos).dx,
          px(data.stations[stationsInLine.first].pos).dy,
        );
      for (final idx in stationsInLine.skip(1)) {
        final p = px(data.stations[idx].pos);
        path.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(path, paint);
    }

    // Stations, colored + shaped by type.
    const radius = 15.0;
    for (var i = 0; i < data.stations.length; i++) {
      final station = data.stations[i];
      final center = px(station.pos);
      final color = _stationColors[station.shapeType % _stationColors.length];
      final paint = Paint()..color = color;
      if (flashSuccess) {
        paint.color = color.withValues(alpha: 0.9);
      }
      switch (station.shapeType) {
        case 0: // circle
          canvas.drawCircle(center, radius, paint);
          break;
        case 1: // triangle
          final path = Path()
            ..moveTo(center.dx, center.dy - radius)
            ..lineTo(center.dx - radius, center.dy + radius * 0.8)
            ..lineTo(center.dx + radius, center.dy + radius * 0.8)
            ..close();
          canvas.drawPath(path, paint);
          break;
        default: // square
          final rect = Rect.fromCenter(
            center: center,
            width: radius * 1.7,
            height: radius * 1.7,
          );
          canvas.drawRRect(
            RRect.fromRectAndRadius(rect, const Radius.circular(4)),
            paint,
          );
      }
      canvas.drawCircle(
        center,
        radius + 2,
        Paint()
          ..color = flashSuccess
              ? AppTheme.success
              : Colors.black.withValues(alpha: 0.25)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _TransitPainter oldDelegate) {
    return oldDelegate.lines != lines ||
        oldDelegate.flashSuccess != flashSuccess;
  }
}
