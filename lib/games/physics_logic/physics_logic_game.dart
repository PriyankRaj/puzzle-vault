import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../app/theme.dart';
import '../../core/game_definition.dart';
import '../../core/game_level_context.dart';
import '../../core/settings_store.dart';
import '../../core/widgets/game_actions.dart';

/// Original physics sandbox: a ball falls under gravity toward a goal zone.
/// The player draws freehand strokes (within a limited total-length "ink
/// budget") that become static obstacles the ball can bounce/slide off of,
/// guiding it into the goal so it comes to rest there. Loosely inspired by
/// "draw a shape with your finger that becomes a physical object to guide a
/// ball into a goal" as a generic mechanic only — every level, name and
/// pixel of rendering here is original.
final GameDefinition physicsLogicDefinition = GameDefinition(
  id: 'physics_logic',
  title: 'Draw Physics',
  tagline: 'Draw shapes to guide the ball home',
  icon: Icons.gesture_rounded,
  tint: const GameTint(Color(0xFF2DD4BF), Color(0xFF115E59)),
  mode: GameMode.levels,
  levelCount: 15,
  helpText:
      'Draw freehand strokes on the canvas to build ramps and walls, then '
      'tap Launch to drop the ball under gravity. Guide it into the '
      'pulsing green goal and let it come to rest there. You have a '
      'limited ink budget, so use it wisely — using less earns more stars.',
  builder: (context, ctx) => PhysicsLogicScreen(ctx: ctx),
);

/// One hand-authored level in a fixed 400x600 logical coordinate space.
/// [obstacles] are static solid rectangles the ball collides with; the
/// floor/walls of the canvas itself are always solid. [inkBudget] is the
/// maximum total length (in the same logical pixels) of freehand strokes
/// the player may draw before further drawing is clipped.
class _LevelSpec {
  _LevelSpec({
    required this.ballStart,
    required this.goalCenter,
    required this.goalRadius,
    required this.obstacles,
    required this.inkBudget,
  });

  final Offset ballStart;
  final Offset goalCenter;
  final double goalRadius;
  final List<Rect> obstacles;
  final double inkBudget;
}

/// 15 hand-designed levels on a 400 (wide) x 600 (tall) logical canvas.
/// Difficulty grows via more obstacles, narrower gaps/goal pockets and
/// tighter ink budgets. Every level's goal sits either directly in an open
/// floor corridor between full-height obstacle columns, or in a small pocket
/// resting on a floating platform — in both cases reachable because a short,
/// steep drawn ramp imparts lasting sideways velocity to the falling ball
/// (only gravity and a small global damping act on it afterwards, so the
/// velocity persists rather than needing a rail spanning the whole drop).
/// No goal is ever fully enclosed by solid obstacles.
final List<_LevelSpec> _levels = [
  // Level 1 — straight drop, no obstacles, no drawing needed. Warm-up.
  _LevelSpec(
    ballStart: const Offset(200, 40),
    goalCenter: const Offset(200, 560),
    goalRadius: 30,
    obstacles: [],
    inkBudget: 60,
  ),
  // Level 2 — open canvas; a single diagonal ramp deflects the ball right.
  _LevelSpec(
    ballStart: const Offset(90, 40),
    goalCenter: const Offset(310, 560),
    goalRadius: 26,
    obstacles: [],
    inkBudget: 200,
  ),
  // Level 3 — mirror of level 2, deflect left.
  _LevelSpec(
    ballStart: const Offset(310, 40),
    goalCenter: const Offset(90, 560),
    goalRadius: 26,
    obstacles: [],
    inkBudget: 200,
  ),
  // Level 4 — one center column (x150-260) blocks the straight fall; the
  // left corridor (x0-150) is open all the way to the floor, where the
  // goal sits. A ramp drawn above the column's top (y<280) nudges the
  // ball left before it would land on top of the column.
  _LevelSpec(
    ballStart: const Offset(200, 40),
    goalCenter: const Offset(70, 560),
    goalRadius: 24,
    obstacles: [Rect.fromLTWH(150, 280, 110, 320)],
    inkBudget: 190,
  ),
  // Level 5 — mirror of level 4, deflect right into the x260-400 corridor.
  _LevelSpec(
    ballStart: const Offset(200, 40),
    goalCenter: const Offset(330, 560),
    goalRadius: 24,
    obstacles: [Rect.fromLTWH(150, 280, 110, 320)],
    inkBudget: 190,
  ),
  // Level 6 — start already left of the column, but the goal is on the far
  // right corridor (x250-400), so the ramp must carry the ball all the way
  // across the top of the column before it descends past y280.
  _LevelSpec(
    ballStart: const Offset(60, 40),
    goalCenter: const Offset(330, 560),
    goalRadius: 22,
    obstacles: [Rect.fromLTWH(130, 280, 120, 320)],
    inkBudget: 230,
  ),
  // Level 7 — two columns leave a single 100-wide center corridor
  // (x150-250); the goal sits in it. Start is left of the corridor, so a
  // modest rightward ramp is enough before y280.
  _LevelSpec(
    ballStart: const Offset(80, 40),
    goalCenter: const Offset(200, 560),
    goalRadius: 20,
    obstacles: [
      Rect.fromLTWH(0, 280, 150, 320),
      Rect.fromLTWH(250, 280, 150, 320),
    ],
    inkBudget: 170,
  ),
  // Level 8 — same shape as level 7 but wider corridor (x130-250) and the
  // ball starts on the far right, needing a longer leftward deflection.
  _LevelSpec(
    ballStart: const Offset(340, 40),
    goalCenter: const Offset(190, 560),
    goalRadius: 20,
    obstacles: [
      Rect.fromLTWH(0, 280, 130, 320),
      Rect.fromLTWH(250, 280, 150, 320),
    ],
    inkBudget: 220,
  ),
  // Level 9 — three columns leave two 40-wide gaps (x120-160, x240-280).
  // The goal is in the far (second) gap. Start is far left; 280px of open
  // vertical space above the columns gives ample room for a shallow ramp
  // (or two short ones) to drift the ball rightward before it descends.
  _LevelSpec(
    ballStart: const Offset(40, 40),
    goalCenter: const Offset(260, 560),
    goalRadius: 20,
    obstacles: [
      Rect.fromLTWH(0, 280, 120, 320),
      Rect.fromLTWH(160, 280, 80, 320),
      Rect.fromLTWH(280, 280, 120, 320),
    ],
    inkBudget: 260,
  ),
  // Level 10 — same two-gap threading challenge as level 9, but with a
  // reduced ink budget, rewarding a straighter, more efficient ramp.
  _LevelSpec(
    ballStart: const Offset(60, 40),
    goalCenter: const Offset(270, 560),
    goalRadius: 18,
    obstacles: [
      Rect.fromLTWH(0, 280, 150, 320),
      Rect.fromLTWH(190, 280, 60, 320),
      Rect.fromLTWH(290, 280, 110, 320),
    ],
    inkBudget: 230,
  ),
  // Level 11 — first "pocket" level: no column blocks the initial fall, but
  // the goal rests atop a narrow floating shelf (x240-400, y420-440) instead
  // of on the floor. A ramp angled down-right gives the ball a rightward
  // velocity component that is still present when it reaches shelf height,
  // so it slides onto the shelf and settles there; if it misses, it simply
  // falls to the open floor below (y440-600) and can be retried.
  _LevelSpec(
    ballStart: const Offset(80, 40),
    goalCenter: const Offset(320, 405),
    goalRadius: 20,
    obstacles: [Rect.fromLTWH(240, 420, 160, 20)],
    inkBudget: 220,
  ),
  // Level 12 — two columns of different heights leave a full-height open
  // corridor (x140-220) with the goal on the floor inside it. Start sits
  // above the shorter column (top at y360), giving 320px of open vertical
  // space to draw a gentle leftward ramp before that column's top.
  _LevelSpec(
    ballStart: const Offset(300, 40),
    goalCenter: const Offset(180, 560),
    goalRadius: 18,
    obstacles: [
      Rect.fromLTWH(0, 220, 140, 380),
      Rect.fromLTWH(220, 360, 180, 240),
    ],
    inkBudget: 260,
  ),
  // Level 13 — harder pocket level: a column (x0-180) blocks the left
  // side, and the goal rests on a narrow shelf (x260-400, y440-460) on the
  // right. A tighter ink budget than level 11 demands a shorter, more
  // direct ramp past the column's top and onto the shelf.
  _LevelSpec(
    ballStart: const Offset(60, 40),
    goalCenter: const Offset(330, 425),
    goalRadius: 18,
    obstacles: [
      Rect.fromLTWH(0, 300, 180, 300),
      Rect.fromLTWH(260, 440, 140, 20),
    ],
    inkBudget: 200,
  ),
  // Level 14 — three columns leave a narrow 30px gap (x120-150, just wide
  // enough for the ball) and a wider unused 80px gap (x240-320). The goal
  // sits in the narrow gap and the ball starts on the far right, requiring
  // a long, carefully angled ramp threaded precisely through it.
  _LevelSpec(
    ballStart: const Offset(360, 40),
    goalCenter: const Offset(135, 560),
    goalRadius: 15,
    obstacles: [
      Rect.fromLTWH(30, 280, 90, 320),
      Rect.fromLTWH(150, 280, 90, 320),
      Rect.fromLTWH(320, 280, 80, 320),
    ],
    inkBudget: 210,
  ),
  // Level 15 — hardest: two columns leave only a 40px gap (x140-180) with
  // the smallest goal radius of the set and the tightest budget. Start is
  // on the far right; a short, precise ramp must impart enough persistent
  // leftward velocity to thread the ball through the narrow gap.
  _LevelSpec(
    ballStart: const Offset(340, 40),
    goalCenter: const Offset(160, 560),
    goalRadius: 16,
    obstacles: [
      Rect.fromLTWH(0, 240, 140, 360),
      Rect.fromLTWH(180, 240, 220, 360),
    ],
    inkBudget: 190,
  ),
];

class PhysicsLogicScreen extends StatefulWidget {
  const PhysicsLogicScreen({super.key, required this.ctx});

  final GameLevelContext ctx;

  @override
  State<PhysicsLogicScreen> createState() => _PhysicsLogicScreenState();
}

class _PhysicsLogicScreenState extends State<PhysicsLogicScreen>
    with TickerProviderStateMixin {
  static const double _canvasW = 400;
  static const double _canvasH = 600;
  static const double _ballRadius = 10;
  static const double _gravity = 1400; // logical px/s^2
  static const double _wallRestitution = 0.42;
  static const double _obstacleRestitution = 0.42;
  static const double _strokeThickness = 8;
  static const double _globalDamping = 0.999; // per substep
  static const int _substeps = 6;
  static const double _settleSpeed = 40;
  static const int _settleTicksNeeded = 30;

  late _LevelSpec _spec;
  late Offset _ballPos;
  Offset _ballVel = Offset.zero;

  final List<List<Offset>> _strokes = [];
  List<Offset>? _currentStroke;
  double _inkUsed = 0;

  bool _running = false;
  bool _completed = false;
  int _settleCounter = 0;

  Ticker? _ticker;
  Duration _lastElapsed = Duration.zero;
  late AnimationController _pulseController;

  int get _level => widget.ctx.level;

  @override
  void initState() {
    super.initState();
    _spec = _levels[(_level - 1).clamp(0, _levels.length - 1)];
    _ballPos = _spec.ballStart;
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    if (AppSettingsStore.instance.animationsEnabled.value) {
      _pulseController.repeat(reverse: true);
    } else {
      _pulseController.value = 1;
    }
  }

  @override
  void dispose() {
    _ticker?.stop();
    _ticker?.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  // --- Simulation control -------------------------------------------------

  void _launch() {
    if (_running || _completed) return;
    setState(() {
      _running = true;
      _currentStroke = null;
    });
    _lastElapsed = Duration.zero;
    _ticker?.dispose();
    _ticker = createTicker(_onTick)..start();
  }

  void _resetBall() {
    if (_completed) return;
    _ticker?.stop();
    setState(() {
      _ballPos = _spec.ballStart;
      _ballVel = Offset.zero;
      _running = false;
      _settleCounter = 0;
    });
  }

  void _clearDrawing() {
    if (_running || _completed) return;
    setState(() {
      _strokes.clear();
      _currentStroke = null;
      _inkUsed = 0;
    });
  }

  void _onTick(Duration elapsed) {
    if (!mounted) return;
    // Once the level is won, the result dialog opens as an overlay on top
    // of this still-mounted screen (see GameHost) — without this guard the
    // ticker keeps stepping physics and calling setState every frame for as
    // long as that dialog stays open, matching the pattern already guarded
    // against in ragdoll_trials_game.dart / snip_logic_game.dart.
    if (_completed) return;
    var dt = (elapsed - _lastElapsed).inMicroseconds / 1e6;
    _lastElapsed = elapsed;
    if (dt <= 0) return;
    if (dt > 1 / 30) dt = 1 / 30;

    final subDt = dt / _substeps;
    for (var i = 0; i < _substeps; i++) {
      _stepPhysics(subDt);
    }
    _checkSettle();

    if (!mounted) return;
    setState(() {});
  }

  void _stepPhysics(double dt) {
    _ballVel += Offset(0, _gravity * dt);
    _ballPos += _ballVel * dt;
    _ballVel = _ballVel * _globalDamping;

    _resolveWalls();
    for (final rect in _spec.obstacles) {
      _resolveRect(rect, _obstacleRestitution);
    }
    for (final stroke in _strokes) {
      for (var i = 0; i < stroke.length - 1; i++) {
        _resolveSegment(stroke[i], stroke[i + 1], _wallRestitution);
      }
    }
  }

  void _resolveWalls() {
    if (_ballPos.dx - _ballRadius < 0) {
      _ballPos = Offset(_ballRadius, _ballPos.dy);
      if (_ballVel.dx < 0) {
        _ballVel = Offset(-_ballVel.dx * _wallRestitution, _ballVel.dy);
      }
    } else if (_ballPos.dx + _ballRadius > _canvasW) {
      _ballPos = Offset(_canvasW - _ballRadius, _ballPos.dy);
      if (_ballVel.dx > 0) {
        _ballVel = Offset(-_ballVel.dx * _wallRestitution, _ballVel.dy);
      }
    }
    if (_ballPos.dy - _ballRadius < 0) {
      _ballPos = Offset(_ballPos.dx, _ballRadius);
      if (_ballVel.dy < 0) {
        _ballVel = Offset(_ballVel.dx, -_ballVel.dy * _wallRestitution);
      }
    } else if (_ballPos.dy + _ballRadius > _canvasH) {
      _ballPos = Offset(_ballPos.dx, _canvasH - _ballRadius);
      if (_ballVel.dy > 0) {
        _ballVel = Offset(_ballVel.dx, -_ballVel.dy * _wallRestitution);
      }
    }
  }

  void _reflect(Offset normal, double restitution) {
    final vn = _ballVel.dx * normal.dx + _ballVel.dy * normal.dy;
    if (vn < 0) {
      _ballVel -= normal * (vn * (1 + restitution));
    }
  }

  void _resolveRect(Rect rect, double restitution) {
    final closestX = _ballPos.dx.clamp(rect.left, rect.right);
    final closestY = _ballPos.dy.clamp(rect.top, rect.bottom);
    final diff = _ballPos - Offset(closestX, closestY);
    final dist = diff.distance;

    if (dist > 0.0001) {
      if (dist >= _ballRadius) return;
      final normal = diff / dist;
      final penetration = _ballRadius - dist;
      _ballPos += normal * penetration;
      _reflect(normal, restitution);
    } else {
      // Ball center is exactly inside the rect: push out along the
      // shallowest overlap axis.
      final overlapLeft = _ballPos.dx - rect.left;
      final overlapRight = rect.right - _ballPos.dx;
      final overlapTop = _ballPos.dy - rect.top;
      final overlapBottom = rect.bottom - _ballPos.dy;
      final minOverlap = [
        overlapLeft,
        overlapRight,
        overlapTop,
        overlapBottom,
      ].reduce(min);
      Offset normal;
      if (minOverlap == overlapLeft) {
        normal = const Offset(-1, 0);
      } else if (minOverlap == overlapRight) {
        normal = const Offset(1, 0);
      } else if (minOverlap == overlapTop) {
        normal = const Offset(0, -1);
      } else {
        normal = const Offset(0, 1);
      }
      _ballPos += normal * (minOverlap + _ballRadius);
      _reflect(normal, restitution);
    }
  }

  void _resolveSegment(Offset p1, Offset p2, double restitution) {
    final seg = p2 - p1;
    final len2 = seg.dx * seg.dx + seg.dy * seg.dy;
    var t = 0.0;
    if (len2 > 1e-6) {
      final toP = _ballPos - p1;
      t = (toP.dx * seg.dx + toP.dy * seg.dy) / len2;
      t = t.clamp(0.0, 1.0);
    }
    final closest = p1 + seg * t;
    final diff = _ballPos - closest;
    final dist = diff.distance;
    final minDist = _ballRadius + _strokeThickness / 2;

    if (dist > 0.0001) {
      if (dist >= minDist) return;
      final normal = diff / dist;
      final penetration = minDist - dist;
      _ballPos += normal * penetration;
      _reflect(normal, restitution);
    } else if (len2 > 1e-6) {
      final dir = seg / sqrt(len2);
      final normal = Offset(-dir.dy, dir.dx);
      _ballPos += normal * minDist;
      _reflect(normal, restitution);
    }
  }

  void _checkSettle() {
    if (_completed) return;
    final distToGoal = (_ballPos - _spec.goalCenter).distance;
    final speed = _ballVel.distance;
    if (distToGoal < _spec.goalRadius && speed < _settleSpeed) {
      _settleCounter++;
    } else {
      _settleCounter = 0;
    }
    if (_settleCounter >= _settleTicksNeeded) {
      _completed = true;
      _ticker?.stop();
      final usedFraction = _spec.inkBudget > 0
          ? (_inkUsed / _spec.inkBudget)
          : 0.0;
      final stars = usedFraction <= 0.5 ? 3 : 2;
      Future.microtask(() {
        if (!mounted) return;
        widget.ctx.onComplete(stars: stars);
      });
    }
  }

  // --- Drawing input --------------------------------------------------

  Offset _toLogical(Offset local, double scale, Offset origin) {
    final adjusted = local - origin;
    return Offset(
      (adjusted.dx / scale).clamp(0, _canvasW),
      (adjusted.dy / scale).clamp(0, _canvasH),
    );
  }

  void _handlePanStart(Offset local, double scale, Offset origin) {
    if (_running || _completed) return;
    setState(() {
      _currentStroke = [_toLogical(local, scale, origin)];
    });
  }

  void _handlePanUpdate(Offset local, double scale, Offset origin) {
    if (_running || _completed) return;
    final stroke = _currentStroke;
    if (stroke == null) return;
    final p = _toLogical(local, scale, origin);
    final last = stroke.last;
    final dist = (p - last).distance;
    if (dist < 1) return;
    final remaining = _spec.inkBudget - _inkUsed;
    if (remaining <= 0) return;
    setState(() {
      if (dist <= remaining) {
        stroke.add(p);
        _inkUsed += dist;
      } else {
        final t = remaining / dist;
        stroke.add(last + (p - last) * t);
        _inkUsed = _spec.inkBudget;
      }
    });
  }

  void _handlePanEnd() {
    if (_running || _completed) return;
    setState(() {
      final stroke = _currentStroke;
      if (stroke != null && stroke.length >= 2) {
        _strokes.add(stroke);
      }
      _currentStroke = null;
    });
  }

  /// There's no stored solution path for this game — a drawn ramp shape
  /// has no single canonical answer. This is a simple directional nudge
  /// based on the goal's position relative to the ball, not a physics
  /// solver.
  void _showHint() {
    final delta = _spec.goalCenter - _ballPos;
    final vertical = delta.dy > 20 ? 'down' : (delta.dy < -20 ? 'up' : null);
    final horizontal = delta.dx > 20
        ? 'right'
        : (delta.dx < -20 ? 'left' : null);
    String direction;
    if (vertical != null && horizontal != null) {
      direction = '$vertical and to the $horizontal';
    } else if (vertical != null) {
      direction = vertical;
    } else if (horizontal != null) {
      direction = 'to the $horizontal';
    } else {
      direction = 'right below the ball';
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'The goal is $direction — try drawing a ramp on that side to '
          'deflect the ball toward it.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canDraw = !_running && !_completed;
    final remaining = (_spec.inkBudget - _inkUsed).clamp(0, _spec.inkBudget);

    return Scaffold(
      appBar: AppBar(
        title: Text('Physics Logic · Level $_level'),
        actions: [
          ...gameActions(
            context: context,
            def: physicsLogicDefinition,
            ctx: widget.ctx,
            onHint: _completed ? null : _showHint,
          ),
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
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Ink left: ${remaining.toStringAsFixed(0)} / ${_spec.inkBudget.toStringAsFixed(0)}',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  _completed
                      ? 'Settled!'
                      : (_running ? 'Simulating…' : 'Draw, then launch'),
                  style: TextStyle(
                    color: _completed
                        ? AppTheme.success
                        : AppTheme.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: _spec.inkBudget > 0
                    ? (_inkUsed / _spec.inkBudget).clamp(0.0, 1.0)
                    : 0,
                minHeight: 6,
                backgroundColor: AppTheme.surfaceHigh,
                color: _inkUsed >= _spec.inkBudget
                    ? AppTheme.danger
                    : AppTheme.warning,
              ),
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                const padding = 12.0;
                final innerW = constraints.maxWidth - padding * 2;
                final innerH = constraints.maxHeight - padding * 2;
                final scale = min(innerW / _canvasW, innerH / _canvasH);
                final paintedW = _canvasW * scale;
                final paintedH = _canvasH * scale;
                final origin = Offset(
                  padding + (innerW - paintedW) / 2,
                  padding + (innerH - paintedH) / 2,
                );
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onPanStart: canDraw
                      ? (d) => _handlePanStart(d.localPosition, scale, origin)
                      : null,
                  onPanUpdate: canDraw
                      ? (d) => _handlePanUpdate(d.localPosition, scale, origin)
                      : null,
                  onPanEnd: canDraw ? (_) => _handlePanEnd() : null,
                  child: Padding(
                    padding: const EdgeInsets.all(padding),
                    child: Center(
                      child: SizedBox(
                        width: paintedW,
                        height: paintedH,
                        child: AnimatedBuilder(
                          animation: _pulseController,
                          builder: (context, _) {
                            return CustomPaint(
                              size: Size(paintedW, paintedH),
                              painter: _PhysicsLogicPainter(
                                scale: scale,
                                spec: _spec,
                                ballPos: _ballPos,
                                strokes: _strokes,
                                currentStroke: _currentStroke,
                                pulse: _pulseController.value,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: (!_running && !_completed) ? _launch : null,
                    child: const Text('Launch'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    onPressed: !_completed ? _resetBall : null,
                    child: const Text('Reset ball'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    onPressed: (!_running && !_completed)
                        ? _clearDrawing
                        : null,
                    child: const Text('Clear drawing'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PhysicsLogicPainter extends CustomPainter {
  _PhysicsLogicPainter({
    required this.scale,
    required this.spec,
    required this.ballPos,
    required this.strokes,
    required this.currentStroke,
    required this.pulse,
  });

  final double scale;
  final _LevelSpec spec;
  final Offset ballPos;
  final List<List<Offset>> strokes;
  final List<Offset>? currentStroke;
  final double pulse;

  static const double _ballRadius = 10;

  void _drawStroke(Canvas canvas, List<Offset> points, Paint paint) {
    if (points.length < 2) return;
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final p in points.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(path, paint);
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(scale);

    // Backdrop.
    final backdrop = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, 400, 600),
      const Radius.circular(16),
    );
    canvas.drawRRect(backdrop, Paint()..color = AppTheme.surface);

    // Obstacles.
    for (final rect in spec.obstacles) {
      final rr = RRect.fromRectAndRadius(rect, const Radius.circular(8));
      canvas.drawRRect(rr, Paint()..color = AppTheme.surfaceHigh);
      canvas.drawRRect(
        rr,
        Paint()
          ..color = Colors.black.withValues(alpha: 0.25)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }

    // Goal zone (pulsing).
    final pulseAlpha = 0.30 + 0.25 * pulse;
    canvas.drawCircle(
      spec.goalCenter,
      spec.goalRadius,
      Paint()..color = AppTheme.success.withValues(alpha: pulseAlpha),
    );
    canvas.drawCircle(
      spec.goalCenter,
      spec.goalRadius,
      Paint()
        ..color = AppTheme.success
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );

    // Player strokes.
    final strokePaint = Paint()
      ..color = AppTheme.warning
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    for (final stroke in strokes) {
      _drawStroke(canvas, stroke, strokePaint);
    }
    final activeStroke = currentStroke;
    if (activeStroke != null) {
      _drawStroke(
        canvas,
        activeStroke,
        Paint()
          ..color = AppTheme.warning.withValues(alpha: 0.65)
          ..strokeWidth = 8
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..style = PaintingStyle.stroke,
      );
    }

    // Ball.
    canvas.drawCircle(
      ballPos,
      _ballRadius,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    canvas.drawCircle(ballPos, _ballRadius, Paint()..color = AppTheme.accent);
    canvas.drawCircle(
      ballPos,
      _ballRadius,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _PhysicsLogicPainter oldDelegate) => true;
}
