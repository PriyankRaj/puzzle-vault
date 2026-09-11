import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../app/theme.dart';
import '../../core/game_definition.dart';
import '../../core/game_level_context.dart';
import '../../core/settings_store.dart';

/// Original physics puzzle: a "parcel" (a plain colored orb) hangs from 1-3
/// rope segments. Ropes act as simple max-distance constraints (a taut rope
/// clamps the parcel back onto its radius and cancels the outward velocity
/// component, giving a believable pendulum swing without a full constraint
/// solver). Tapping a rope severs it permanently for the attempt. The player
/// must cut ropes in the right order/timing so the parcel swings and drops
/// into a target zone, while avoiding static obstacles and an optional
/// oscillating hazard. Loosely inspired by "cut ropes to drop an object into
/// a target" as a generic mechanic only — every level, name, and pixel of
/// rendering here is original; no assets or IP from any commercial game.
final GameDefinition snipLogicDefinition = GameDefinition(
  id: 'snip_logic',
  title: 'Rope Cut',
  tagline: 'Cut ropes at the right moment to land the parcel',
  icon: Icons.content_cut_rounded,
  tint: const GameTint(Color(0xFFFB923C), Color(0xFF9A3412)),
  mode: GameMode.levels,
  levelCount: 15,
  builder: (context, ctx) => SnipLogicScreen(ctx: ctx),
);

/// An oscillating rectangular hazard whose center moves along a sine wave
/// driven by elapsed simulation time: `base + amplitude * sin(2*pi*t/period)`.
class _HazardSpec {
  const _HazardSpec({
    required this.base,
    required this.amplitude,
    required this.period,
    required this.size,
  });

  final Offset base;
  final Offset amplitude;
  final double period;
  final Size size;

  Rect rectAt(double t) {
    final phase = sin(2 * pi * t / period);
    final center = base + Offset(amplitude.dx * phase, amplitude.dy * phase);
    return Rect.fromCenter(center: center, width: size.width, height: size.height);
  }
}

/// One hand-authored level in a fixed 400x600 logical coordinate space.
/// Each entry in [anchors] is a fixed rope anchor point; its rest length is
/// computed at runtime as the initial distance from the anchor to
/// [parcelStart], so every rope starts perfectly taut.
class _LevelSpec {
  const _LevelSpec({
    required this.parcelStart,
    required this.anchors,
    this.obstacles = const [],
    this.hazard,
    required this.targetCenter,
    required this.targetRadius,
  });

  final Offset parcelStart;
  final List<Offset> anchors;
  final List<Rect> obstacles;
  final _HazardSpec? hazard;
  final Offset targetCenter;
  final double targetRadius;
}

/// 15 hand-designed levels on a 400 (wide) x 600 (tall) logical canvas.
/// Every target circle is placed with its bottom edge touching the floor
/// (targetCenter.y == 600 - targetRadius), so a parcel that settles on the
/// floor anywhere near the target's x position is physically able to come
/// to rest inside it. Difficulty increases via more ropes requiring
/// sequenced cuts, added hazards/obstacles, and tighter target radii.
final List<_LevelSpec> _levels = [
  // Level 1 — single rope hangs straight below its anchor (zero horizontal
  // offset), so it's stationary at rest. Cutting it is a plain vertical
  // drop under gravity into a wide floor target. Warm-up.
  _LevelSpec(
    parcelStart: Offset(200, 170),
    anchors: [Offset(200, 70)],
    targetCenter: Offset(200, 555),
    targetRadius: 45,
  ),
  // Level 2 — anchor offset left of the start, so the parcel hangs as a
  // pendulum and swings through the point directly below the anchor.
  // Cutting mid-swing (moving right, rising) releases it with rightward +
  // upward velocity that carries it in an arc onto a target further right.
  _LevelSpec(
    parcelStart: Offset(260, 210),
    anchors: [Offset(140, 70)],
    targetCenter: Offset(330, 558),
    targetRadius: 42,
  ),
  // Level 3 — mirror of level 2: anchor to the right, target to the left.
  _LevelSpec(
    parcelStart: Offset(140, 210),
    anchors: [Offset(260, 70)],
    targetCenter: Offset(70, 558),
    targetRadius: 42,
  ),
  // Level 4 — two ropes hang the parcel motionless between two anchors
  // (each independently taut). Cutting the left rope first turns it into a
  // single-rope pendulum pivoting on the right anchor; cutting the second
  // rope near the bottom of that swing drops it into a target beneath the
  // remaining anchor.
  _LevelSpec(
    parcelStart: Offset(200, 220),
    anchors: [Offset(120, 70), Offset(280, 70)],
    targetCenter: Offset(280, 560),
    targetRadius: 40,
  ),
  // Level 5 — same two-rope setup, but a low obstacle sits under the start
  // point. Cutting the left rope swings the parcel around the right anchor,
  // and cutting the second rope during the rightward part of that swing
  // clears the obstacle (its right edge is well left of the target) before
  // dropping into a target on the far side.
  _LevelSpec(
    parcelStart: Offset(200, 220),
    anchors: [Offset(150, 70), Offset(250, 70)],
    obstacles: [Rect.fromLTWH(160, 330, 80, 40)],
    targetCenter: Offset(330, 562),
    targetRadius: 38,
  ),
  // Level 6 — single offset-anchor pendulum, plus a horizontally oscillating
  // hazard confined to the middle-left of the canvas (max reach well short
  // of the target region). The player swings right and cuts near the peak
  // of the rightward swing, landing on the target on the far right, clear
  // of the hazard's travel range.
  _LevelSpec(
    parcelStart: Offset(300, 200),
    anchors: [Offset(150, 70)],
    hazard: _HazardSpec(
      base: Offset(190, 400),
      amplitude: Offset(70, 0),
      period: 2.4,
      size: Size(60, 24),
    ),
    targetCenter: Offset(330, 564),
    targetRadius: 36,
  ),
  // Level 7 — introduces a third rope. The center anchor sits directly
  // above the start point, so with all three ropes taut the parcel is
  // already motionless — cutting the two side ropes (in either order) does
  // nothing on its own. Only cutting the final, center rope releases a
  // plain vertical drop into a floor target directly below. Teaches that
  // cut *order* matters independent of timing.
  _LevelSpec(
    parcelStart: Offset(200, 200),
    anchors: [Offset(100, 70), Offset(200, 70), Offset(300, 70)],
    targetCenter: Offset(200, 562),
    targetRadius: 38,
  ),
  // Level 8 — two asymmetric ropes plus a vertically bobbing hazard parked
  // under the start position. Cutting the left rope swings the parcel
  // right around the remaining anchor; cutting the second rope during the
  // downward-right part of the swing carries it past the hazard (which
  // stays centered well left of the target) into the target.
  _LevelSpec(
    parcelStart: Offset(180, 210),
    anchors: [Offset(120, 70), Offset(260, 80)],
    hazard: _HazardSpec(
      base: Offset(180, 420),
      amplitude: Offset(0, 40),
      period: 2.0,
      size: Size(70, 24),
    ),
    targetCenter: Offset(320, 566),
    targetRadius: 34,
  ),
  // Level 9 — two ropes, a small central obstacle, and a hazard bobbing on
  // the right side. Cutting the right rope first pivots the parcel left
  // around the left anchor (whose swing stays left of the central
  // obstacle); cutting the second rope near the bottom of that leftward
  // swing drops it into a target on the far left, away from both the
  // obstacle and the hazard.
  _LevelSpec(
    parcelStart: Offset(200, 210),
    anchors: [Offset(130, 70), Offset(270, 70)],
    obstacles: [Rect.fromLTWH(170, 330, 60, 30)],
    hazard: _HazardSpec(
      base: Offset(310, 460),
      amplitude: Offset(0, 50),
      period: 2.6,
      size: Size(50, 22),
    ),
    targetCenter: Offset(90, 568),
    targetRadius: 32,
  ),
  // Level 10 — three ropes with a near-vertical center rope (little effect
  // when cut alone) and an obstacle blocking the straight-down path.
  // Cutting the center then the left rope leaves only the right anchor;
  // its swing carries the parcel past the obstacle's right edge into a
  // target further right.
  _LevelSpec(
    parcelStart: Offset(200, 210),
    anchors: [Offset(110, 70), Offset(200, 60), Offset(290, 70)],
    obstacles: [Rect.fromLTWH(150, 380, 100, 36)],
    targetCenter: Offset(330, 568),
    targetRadius: 32,
  ),
  // Level 11 — three ropes plus a horizontally oscillating hazard confined
  // to the middle of the canvas, well short of the target. Sequenced cuts
  // (side ropes, then center) followed by timing the final drop past the
  // hazard's travel range lands the parcel on the right.
  _LevelSpec(
    parcelStart: Offset(200, 210),
    anchors: [Offset(110, 80), Offset(300, 60), Offset(200, 70)],
    hazard: _HazardSpec(
      base: Offset(170, 400),
      amplitude: Offset(70, 0),
      period: 2.2,
      size: Size(60, 22),
    ),
    targetCenter: Offset(340, 570),
    targetRadius: 30,
  ),
  // Level 12 — two ropes and two separated low obstacles leave a clear
  // corridor on the far right for the target. Cut the left rope, swing
  // right around the remaining anchor, and cut the second rope once clear
  // of both obstacles.
  _LevelSpec(
    parcelStart: Offset(200, 220),
    anchors: [Offset(120, 70), Offset(280, 70)],
    obstacles: [
      Rect.fromLTWH(60, 340, 80, 30),
      Rect.fromLTWH(200, 420, 70, 30),
    ],
    targetCenter: Offset(340, 572),
    targetRadius: 28,
  ),
  // Level 13 — three ropes, a hazard bobbing on the right, and a low
  // obstacle in the middle. Sequenced cuts leave the left anchor as pivot;
  // its swing stays left of the central obstacle and far from the
  // right-side hazard, dropping into a tight target on the far left.
  _LevelSpec(
    parcelStart: Offset(200, 210),
    anchors: [Offset(110, 70), Offset(290, 70), Offset(200, 60)],
    obstacles: [Rect.fromLTWH(160, 470, 80, 28)],
    hazard: _HazardSpec(
      base: Offset(300, 380),
      amplitude: Offset(0, 45),
      period: 2.3,
      size: Size(55, 20),
    ),
    targetCenter: Offset(90, 574),
    targetRadius: 26,
  ),
  // Level 14 — three ropes plus a faster horizontally oscillating hazard
  // kept centered (max reach short of the tight right-side target) and a
  // low obstacle on the far left (irrelevant to the rightward escape path).
  _LevelSpec(
    parcelStart: Offset(200, 210),
    anchors: [Offset(120, 70), Offset(280, 70), Offset(200, 60)],
    obstacles: [Rect.fromLTWH(80, 500, 70, 26)],
    hazard: _HazardSpec(
      base: Offset(200, 380),
      amplitude: Offset(60, 0),
      period: 1.8,
      size: Size(55, 20),
    ),
    targetCenter: Offset(340, 575),
    targetRadius: 25,
  ),
  // Level 15 — hardest: three ropes, a fast central hazard, and two low
  // obstacles bracketing the canvas, leaving only a narrow clear lane on
  // the right for the smallest target of the set.
  _LevelSpec(
    parcelStart: Offset(200, 210),
    anchors: [Offset(110, 70), Offset(290, 70), Offset(200, 55)],
    obstacles: [
      Rect.fromLTWH(60, 480, 70, 26),
      Rect.fromLTWH(250, 500, 60, 26),
    ],
    hazard: _HazardSpec(
      base: Offset(200, 380),
      amplitude: Offset(70, 0),
      period: 1.6,
      size: Size(55, 20),
    ),
    targetCenter: Offset(340, 578),
    targetRadius: 22,
  ),
];

class SnipLogicScreen extends StatefulWidget {
  const SnipLogicScreen({super.key, required this.ctx});

  final GameLevelContext ctx;

  @override
  State<SnipLogicScreen> createState() => _SnipLogicScreenState();
}

class _SnipLogicScreenState extends State<SnipLogicScreen>
    with TickerProviderStateMixin {
  static const double _canvasW = 400;
  static const double _canvasH = 600;
  static const double _parcelRadius = 14;
  static const double _gravity = 1500;
  static const double _damping = 0.999;
  static const double _wallRestitution = 0.4;
  static const double _obstacleRestitution = 0.4;
  static const int _substeps = 6;
  static const double _settleSpeed = 40;
  static const int _settleTicksNeeded = 20;
  static const double _cutThreshold = 18;

  late _LevelSpec _spec;
  late List<double> _ropeLengths;
  late List<bool> _ropeCut;

  late Offset _parcelPos;
  Offset _parcelVel = Offset.zero;

  double _simTime = 0;
  int _settleCounter = 0;
  bool _completed = false;
  bool _failed = false;

  /// Persists across local resets within this attempt (only cleared when
  /// the whole widget is torn down), used to grade stars on success.
  int _retryCount = 0;

  Ticker? _ticker;
  Duration _lastTickerElapsed = Duration.zero;
  late AnimationController _pulseController;

  int get _level => widget.ctx.level;

  @override
  void initState() {
    super.initState();
    _spec = _levels[(_level - 1).clamp(0, _levels.length - 1)];
    _resetSimulation();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    if (AppSettingsStore.instance.animationsEnabled.value) {
      _pulseController.repeat(reverse: true);
    } else {
      _pulseController.value = 1;
    }
    _ticker = createTicker(_onTick)..start();
  }

  @override
  void dispose() {
    _ticker?.stop();
    _ticker?.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _resetSimulation() {
    _parcelPos = _spec.parcelStart;
    _parcelVel = Offset.zero;
    _ropeLengths = [
      for (final anchor in _spec.anchors) (_spec.parcelStart - anchor).distance,
    ];
    _ropeCut = List.filled(_spec.anchors.length, false);
    _simTime = 0;
    _settleCounter = 0;
    _completed = false;
    _failed = false;
  }

  // --- Simulation ----------------------------------------------------

  void _onTick(Duration elapsed) {
    if (!mounted) return;
    var dt = (elapsed - _lastTickerElapsed).inMicroseconds / 1e6;
    _lastTickerElapsed = elapsed;
    if (dt <= 0) return;
    if (dt > 1 / 30) dt = 1 / 30;

    if (_completed || _failed) return;

    final subDt = dt / _substeps;
    for (var i = 0; i < _substeps; i++) {
      _stepPhysics(subDt);
    }
    _simTime += dt;

    _checkHazard();
    if (!_failed) _checkSettle();

    if (!mounted) return;
    setState(() {});
  }

  void _stepPhysics(double dt) {
    _parcelVel += Offset(0, _gravity * dt);
    _parcelPos += _parcelVel * dt;
    _parcelVel = _parcelVel * _damping;

    _resolveWalls();
    for (final rect in _spec.obstacles) {
      _resolveRect(rect, _obstacleRestitution);
    }
    for (var i = 0; i < _spec.anchors.length; i++) {
      if (_ropeCut[i]) continue;
      _resolveRope(_spec.anchors[i], _ropeLengths[i]);
    }
  }

  void _resolveWalls() {
    if (_parcelPos.dx - _parcelRadius < 0) {
      _parcelPos = Offset(_parcelRadius, _parcelPos.dy);
      if (_parcelVel.dx < 0) {
        _parcelVel = Offset(-_parcelVel.dx * _wallRestitution, _parcelVel.dy);
      }
    } else if (_parcelPos.dx + _parcelRadius > _canvasW) {
      _parcelPos = Offset(_canvasW - _parcelRadius, _parcelPos.dy);
      if (_parcelVel.dx > 0) {
        _parcelVel = Offset(-_parcelVel.dx * _wallRestitution, _parcelVel.dy);
      }
    }
    if (_parcelPos.dy - _parcelRadius < 0) {
      _parcelPos = Offset(_parcelPos.dx, _parcelRadius);
      if (_parcelVel.dy < 0) {
        _parcelVel = Offset(_parcelVel.dx, -_parcelVel.dy * _wallRestitution);
      }
    } else if (_parcelPos.dy + _parcelRadius > _canvasH) {
      _parcelPos = Offset(_parcelPos.dx, _canvasH - _parcelRadius);
      if (_parcelVel.dy > 0) {
        _parcelVel = Offset(_parcelVel.dx, -_parcelVel.dy * _wallRestitution);
      }
    }
  }

  void _reflect(Offset normal, double restitution) {
    final vn = _parcelVel.dx * normal.dx + _parcelVel.dy * normal.dy;
    if (vn < 0) {
      _parcelVel -= normal * (vn * (1 + restitution));
    }
  }

  void _resolveRect(Rect rect, double restitution) {
    final closestX = _parcelPos.dx.clamp(rect.left, rect.right);
    final closestY = _parcelPos.dy.clamp(rect.top, rect.bottom);
    final diff = _parcelPos - Offset(closestX, closestY);
    final dist = diff.distance;

    if (dist > 0.0001) {
      if (dist >= _parcelRadius) return;
      final normal = diff / dist;
      final penetration = _parcelRadius - dist;
      _parcelPos += normal * penetration;
      _reflect(normal, restitution);
    } else {
      final overlapLeft = _parcelPos.dx - rect.left;
      final overlapRight = rect.right - _parcelPos.dx;
      final overlapTop = _parcelPos.dy - rect.top;
      final overlapBottom = rect.bottom - _parcelPos.dy;
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
      _parcelPos += normal * (minOverlap + _parcelRadius);
      _reflect(normal, restitution);
    }
  }

  /// Simplified rope constraint: if the parcel has drifted further than
  /// [restLength] from [anchor], clamp it back onto that radius and cancel
  /// the velocity component pulling it further outward, leaving only the
  /// tangential (swinging) component — a lightweight pendulum approximation.
  void _resolveRope(Offset anchor, double restLength) {
    final diff = _parcelPos - anchor;
    final dist = diff.distance;
    if (dist <= restLength || dist < 1e-6) return;
    final n = diff / dist;
    _parcelPos = anchor + n * restLength;
    final vDotN = _parcelVel.dx * n.dx + _parcelVel.dy * n.dy;
    if (vDotN > 0) {
      _parcelVel -= n * vDotN;
    }
  }

  bool _circleHitsRect(Offset center, double radius, Rect rect) {
    final closestX = center.dx.clamp(rect.left, rect.right);
    final closestY = center.dy.clamp(rect.top, rect.bottom);
    return (center - Offset(closestX, closestY)).distance < radius;
  }

  void _checkHazard() {
    final hazard = _spec.hazard;
    if (hazard == null) return;
    if (_failed || _completed) return;
    // Only a threat once the player has started cutting — a fully
    // suspended, stationary parcel can't be blamed for touching it.
    if (!_ropeCut.contains(true)) return;
    final rect = hazard.rectAt(_simTime);
    if (_circleHitsRect(_parcelPos, _parcelRadius, rect)) {
      _failed = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _showFailedDialog('The parcel touched the hazard.');
      });
    }
  }

  void _checkSettle() {
    if (_completed) return;
    final distToTarget = (_parcelPos - _spec.targetCenter).distance;
    final speed = _parcelVel.distance;
    if (distToTarget < _spec.targetRadius && speed < _settleSpeed) {
      _settleCounter++;
    } else {
      _settleCounter = 0;
    }
    if (_settleCounter >= _settleTicksNeeded) {
      _completed = true;
      final stars = _retryCount == 0 ? 3 : (_retryCount <= 2 ? 2 : 1);
      Future.microtask(() {
        if (!mounted) return;
        widget.ctx.onComplete(stars: stars);
      });
    }
  }

  void _showFailedDialog(String reason) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Parcel lost'),
          content: Text('$reason Try again with a different plan.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                widget.ctx.onExit();
              },
              child: const Text('Menu'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                setState(() {
                  _retryCount++;
                  _resetSimulation();
                });
              },
              child: const Text('Retry'),
            ),
          ],
        );
      },
    );
  }

  // --- Input -----------------------------------------------------------

  double _pointSegmentDistance(Offset p, Offset a, Offset b) {
    final seg = b - a;
    final len2 = seg.dx * seg.dx + seg.dy * seg.dy;
    var t = 0.0;
    if (len2 > 1e-6) {
      final toP = p - a;
      t = (toP.dx * seg.dx + toP.dy * seg.dy) / len2;
      t = t.clamp(0.0, 1.0);
    }
    final closest = a + seg * t;
    return (p - closest).distance;
  }

  Offset _toLogical(Offset local, double scale) {
    return Offset(
      (local.dx / scale).clamp(0, _canvasW),
      (local.dy / scale).clamp(0, _canvasH),
    );
  }

  void _handleTap(Offset local, double scale) {
    if (_completed || _failed) return;
    final point = _toLogical(local, scale);
    var bestDist = double.infinity;
    var bestIndex = -1;
    for (var i = 0; i < _spec.anchors.length; i++) {
      if (_ropeCut[i]) continue;
      final d = _pointSegmentDistance(point, _spec.anchors[i], _parcelPos);
      if (d < bestDist) {
        bestDist = d;
        bestIndex = i;
      }
    }
    if (bestIndex >= 0 && bestDist <= _cutThreshold) {
      setState(() {
        _ropeCut[bestIndex] = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ropesLeft = _ropeCut.where((c) => !c).length;
    final statusText = _completed
        ? 'Delivered!'
        : _failed
            ? 'Lost…'
            : ropesLeft > 0
                ? 'Tap a rope to cut it ($ropesLeft left)'
                : 'Falling…';

    return Scaffold(
      appBar: AppBar(
        title: Text('Snip Logic · Level $_level'),
        actions: [
          TextButton(onPressed: widget.ctx.onExit, child: const Text('Menu')),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Retries: $_retryCount',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  statusText,
                  style: TextStyle(
                    color: _completed
                        ? AppTheme.success
                        : _failed
                            ? AppTheme.danger
                            : AppTheme.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Center(
              child: AspectRatio(
                aspectRatio: _canvasW / _canvasH,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final scale = constraints.maxWidth / _canvasW;
                      return GestureDetector(
                        onTapUp: (d) => _handleTap(d.localPosition, scale),
                        child: AnimatedBuilder(
                          animation: _pulseController,
                          builder: (context, _) {
                            return CustomPaint(
                              size: Size(constraints.maxWidth, constraints.maxHeight),
                              painter: _SnipLogicPainter(
                                scale: scale,
                                spec: _spec,
                                parcelPos: _parcelPos,
                                ropeCut: _ropeCut,
                                simTime: _simTime,
                                pulse: _pulseController.value,
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SnipLogicPainter extends CustomPainter {
  _SnipLogicPainter({
    required this.scale,
    required this.spec,
    required this.parcelPos,
    required this.ropeCut,
    required this.simTime,
    required this.pulse,
  });

  final double scale;
  final _LevelSpec spec;
  final Offset parcelPos;
  final List<bool> ropeCut;
  final double simTime;
  final double pulse;

  static const double _parcelRadius = 14;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(scale);

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

    // Hazard.
    final hazard = spec.hazard;
    if (hazard != null) {
      final rect = hazard.rectAt(simTime);
      final rr = RRect.fromRectAndRadius(rect, const Radius.circular(6));
      canvas.drawRRect(rr, Paint()..color = AppTheme.danger.withValues(alpha: 0.85));
      canvas.drawRRect(
        rr,
        Paint()
          ..color = Colors.black.withValues(alpha: 0.3)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }

    // Target zone (pulsing).
    final pulseAlpha = 0.30 + 0.25 * pulse;
    canvas.drawCircle(
      spec.targetCenter,
      spec.targetRadius,
      Paint()..color = AppTheme.success.withValues(alpha: pulseAlpha),
    );
    canvas.drawCircle(
      spec.targetCenter,
      spec.targetRadius,
      Paint()
        ..color = AppTheme.success
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );

    // Ropes + anchors.
    final ropePaint = Paint()
      ..color = AppTheme.textSecondary
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    final anchorPaint = Paint()..color = AppTheme.textPrimary;
    for (var i = 0; i < spec.anchors.length; i++) {
      final anchor = spec.anchors[i];
      canvas.drawCircle(anchor, 5, anchorPaint);
      if (!ropeCut[i]) {
        canvas.drawLine(anchor, parcelPos, ropePaint);
      }
    }

    // Parcel.
    canvas.drawCircle(
      parcelPos,
      _parcelRadius,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    canvas.drawCircle(parcelPos, _parcelRadius, Paint()..color = AppTheme.accent);
    canvas.drawCircle(
      parcelPos,
      _parcelRadius,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _SnipLogicPainter oldDelegate) => true;
}
