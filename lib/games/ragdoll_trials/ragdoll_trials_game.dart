import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../app/theme.dart';
import '../../core/game_definition.dart';
import '../../core/game_level_context.dart';
import '../../core/settings_store.dart';

/// Original physics toy: a single rounded "blob" body tumbles across a
/// side-view obstacle course under gravity while the player holds
/// left/right push buttons to steer it toward a goal zone. Loosely
/// inspired by "a floppy physical character you tilt/push across an
/// obstacle course" as a generic mechanic only — this is a deliberately
/// simplified single-body simulation (a circle for physics, rendered as an
/// elongated rounded capsule that visually rotates with horizontal
/// velocity for cosmetic "tumble" flavor). No jointed skeleton, no names,
/// art or levels from any existing commercial game.
final GameDefinition ragdollTrialsDefinition = GameDefinition(
  id: 'ragdoll_trials',
  title: 'Tumble Course',
  tagline: 'Push and tumble the blob to the goal',
  icon: Icons.circle_rounded,
  tint: const GameTint(Color(0xFFC084FC), Color(0xFF6B21A8)),
  mode: GameMode.levels,
  levelCount: 15,
  helpText:
      'Hold the left or right button to push the blob and tumble it across '
      'the course. Gravity pulls it down, so build up speed on the runways '
      'before each gap and steer clear of spinning hazards. Holding a '
      'button too long overshoots — ease off, or tap the opposite button '
      'briefly, so the blob slows down and settles inside the glowing goal '
      'zone rather than rolling straight through it. Fewer falls earns '
      'more stars.',
  builder: (context, ctx) => RagdollTrialsScreen(ctx: ctx),
);

/// A single spinning-segment hazard, pivoting around a fixed point.
/// Touching the swept segment fails the level. Collision is treated as a
/// thick line segment vs. circle test, mirroring the segment-collision
/// approach used elsewhere in this app's physics sandbox.
class _Hazard {
  const _Hazard({
    required this.pivot,
    required this.length,
    required this.thickness,
    required this.angularSpeed,
  });

  final Offset pivot;
  final double length;
  final double thickness;
  final double angularSpeed; // radians / second

  /// All hazards start at angle 0; only [angularSpeed] varies per level.
  static const double baseAngle = 0;
}

/// One hand-authored level on a fixed 400x600 logical canvas.
/// [platforms] are static solid rects the blob rests/collides on;
/// [goal] is the target zone the blob's center must settle inside; the
/// left/right canvas edges are solid walls, the bottom of the canvas is an
/// open pit (falling below it is an instant fail).
class _LevelSpec {
  const _LevelSpec({
    required this.start,
    required this.platforms,
    required this.goal,
    this.hazard,
  });

  final Offset start;
  final List<Rect> platforms;
  final Rect goal;
  final _Hazard? hazard;
}

/// 15 hand-designed levels. Difficulty grows via longer courses, narrower
/// platforms, more gaps, extra vertical tiers and (from level 6 on) a
/// single spinning hazard to time around. Every gap is sized well below
/// the width of the runway platform preceding it, so a blob that has built
/// up horizontal speed while pushed along that runway carries enough
/// momentum past the ledge to still be within the next platform's x-range
/// by the time it sinks back down to that platform's top surface — the
/// same "runway then momentum carry" shape used for every gap below.
/// Multi-tier levels always drop onto a generously wide lower platform, so
/// horizontal drift only needs to be roughly right, not pixel-perfect.
final List<_LevelSpec> _levels = [
  // Level 1 — full-width floor, no obstacles. Warm-up: fall, push right.
  const _LevelSpec(
    start: Offset(60, 60),
    platforms: [Rect.fromLTWH(0, 560, 400, 40)],
    goal: Rect.fromLTWH(300, 515, 70, 45),
  ),
  // Level 2 — mirror of level 1: push left instead.
  const _LevelSpec(
    start: Offset(340, 60),
    platforms: [Rect.fromLTWH(0, 560, 400, 40)],
    goal: Rect.fromLTWH(30, 515, 70, 45),
  ),
  // Level 3 — one 50px gap (x175-225) in the floor. The 175px-wide runway
  // (platform A) is ample room to build rightward speed before the ledge.
  const _LevelSpec(
    start: Offset(50, 60),
    platforms: [
      Rect.fromLTWH(0, 560, 175, 40),
      Rect.fromLTWH(225, 560, 175, 40),
    ],
    goal: Rect.fromLTWH(300, 515, 70, 45),
  ),
  // Level 4 — two 40px gaps, three platforms (130 / 130 / 60 wide). Each
  // runway is still wide enough to accelerate before its gap.
  const _LevelSpec(
    start: Offset(40, 60),
    platforms: [
      Rect.fromLTWH(0, 560, 130, 40),
      Rect.fromLTWH(170, 560, 130, 40),
      Rect.fromLTWH(340, 560, 60, 40),
    ],
    goal: Rect.fromLTWH(345, 515, 50, 45),
  ),
  // Level 5 — first vertical drop: a mid-height ledge (x0-160) over a
  // full-width floor safety net. Whatever speed the blob carries off the
  // ledge, the full floor below guarantees a landing, so this level is
  // purely about getting comfortable with falling and steering.
  const _LevelSpec(
    start: Offset(70, 340),
    platforms: [Rect.fromLTWH(0, 380, 160, 24), Rect.fromLTWH(0, 560, 400, 40)],
    goal: Rect.fromLTWH(300, 515, 70, 45),
  ),
  // Level 6 — two floor gaps (40px, 30px) plus the first hazard: a spinning
  // 60-long arm pivoting near the second gap at path height, forcing a
  // timed pass rather than a blind run.
  const _LevelSpec(
    start: Offset(40, 60),
    platforms: [
      Rect.fromLTWH(0, 560, 140, 40),
      Rect.fromLTWH(180, 560, 140, 40),
      Rect.fromLTWH(350, 560, 50, 40),
    ],
    goal: Rect.fromLTWH(355, 515, 40, 45),
    hazard: _Hazard(
      pivot: Offset(330, 530),
      length: 60,
      thickness: 8,
      angularSpeed: 2.5,
    ),
  ),
  // Level 7 — three narrower 35px gaps, four platforms (90/70/70/65 wide).
  // No hazard: pure precision level, each runway still comfortably wider
  // than the gap that follows it.
  const _LevelSpec(
    start: Offset(40, 60),
    platforms: [
      Rect.fromLTWH(0, 560, 90, 40),
      Rect.fromLTWH(125, 560, 70, 40),
      Rect.fromLTWH(230, 560, 70, 40),
      Rect.fromLTWH(335, 560, 65, 40),
    ],
    goal: Rect.fromLTWH(345, 515, 45, 45),
  ),
  // Level 8 — two-tier level: a mid tier with one 50px gap (140 / 150 wide
  // runways), dropping onto a full-width floor safety net. A hazard swings
  // in the air pocket between the tiers, so the fall itself must be timed.
  const _LevelSpec(
    start: Offset(50, 340),
    platforms: [
      Rect.fromLTWH(0, 380, 140, 24),
      Rect.fromLTWH(190, 380, 150, 24),
      Rect.fromLTWH(0, 560, 400, 40),
    ],
    goal: Rect.fromLTWH(300, 515, 70, 45),
    hazard: _Hazard(
      pivot: Offset(270, 470),
      length: 60,
      thickness: 8,
      angularSpeed: 2.2,
    ),
  ),
  // Level 9 — same three-gap floor shape as level 7, with a hazard added
  // over the middle gap for a timing gate mid-course.
  const _LevelSpec(
    start: Offset(40, 60),
    platforms: [
      Rect.fromLTWH(0, 560, 90, 40),
      Rect.fromLTWH(125, 560, 70, 40),
      Rect.fromLTWH(230, 560, 70, 40),
      Rect.fromLTWH(335, 560, 65, 40),
    ],
    goal: Rect.fromLTWH(345, 515, 45, 45),
    hazard: _Hazard(
      pivot: Offset(210, 530),
      length: 55,
      thickness: 8,
      angularSpeed: 2.6,
    ),
  ),
  // Level 10 — two-tier: mid tier has two 40px gaps (110/110/100 wide
  // runways), dropping onto a full-width floor. Hazard patrols the gap
  // between tiers near the first mid-tier gap.
  const _LevelSpec(
    start: Offset(40, 340),
    platforms: [
      Rect.fromLTWH(0, 380, 110, 24),
      Rect.fromLTWH(150, 380, 110, 24),
      Rect.fromLTWH(300, 380, 100, 24),
      Rect.fromLTWH(0, 560, 400, 40),
    ],
    goal: Rect.fromLTWH(300, 515, 70, 45),
    hazard: _Hazard(
      pivot: Offset(205, 470),
      length: 60,
      thickness: 8,
      angularSpeed: 2.3,
    ),
  ),
  // Level 11 — four tight 35px gaps, five ~50-60px platforms. No hazard:
  // the tightest pure-precision floor course. Each runway is still ~15-25px
  // wider than the gap it precedes.
  const _LevelSpec(
    start: Offset(25, 60),
    platforms: [
      Rect.fromLTWH(0, 560, 50, 40),
      Rect.fromLTWH(85, 560, 50, 40),
      Rect.fromLTWH(170, 560, 50, 40),
      Rect.fromLTWH(255, 560, 50, 40),
      Rect.fromLTWH(340, 560, 60, 40),
    ],
    goal: Rect.fromLTWH(345, 515, 45, 45),
  ),
  // Level 12 — same three-gap course as level 7/9, with a hazard gating the
  // very last approach onto the goal platform.
  const _LevelSpec(
    start: Offset(40, 60),
    platforms: [
      Rect.fromLTWH(0, 560, 90, 40),
      Rect.fromLTWH(125, 560, 70, 40),
      Rect.fromLTWH(230, 560, 70, 40),
      Rect.fromLTWH(335, 560, 65, 40),
    ],
    goal: Rect.fromLTWH(345, 515, 45, 45),
    hazard: _Hazard(
      pivot: Offset(365, 530),
      length: 50,
      thickness: 8,
      angularSpeed: 3.0,
    ),
  ),
  // Level 13 — two-tier with three gaps total: two 40px gaps on the mid
  // tier (120/120/80 wide runways) then a wide floor. Falling from the
  // mid tier's last platform (x320-400) lands directly on the wide floor
  // platform E (x190-400), so the floor's own 40px gap (x150-190) never
  // needs to be crossed on the intended path — it is just extra fail risk
  // if the player drifts too far left. Hazard patrols between the tiers.
  const _LevelSpec(
    start: Offset(40, 340),
    platforms: [
      Rect.fromLTWH(0, 380, 120, 24),
      Rect.fromLTWH(160, 380, 120, 24),
      Rect.fromLTWH(320, 380, 80, 24),
      Rect.fromLTWH(0, 560, 150, 40),
      Rect.fromLTWH(190, 560, 210, 40),
    ],
    goal: Rect.fromLTWH(320, 515, 70, 45),
    hazard: _Hazard(
      pivot: Offset(240, 470),
      length: 60,
      thickness: 8,
      angularSpeed: 2.4,
    ),
  ),
  // Level 14 — the level-11 four-gap floor course, with a hazard added
  // over the second gap.
  const _LevelSpec(
    start: Offset(25, 60),
    platforms: [
      Rect.fromLTWH(0, 560, 50, 40),
      Rect.fromLTWH(85, 560, 50, 40),
      Rect.fromLTWH(170, 560, 50, 40),
      Rect.fromLTWH(255, 560, 50, 40),
      Rect.fromLTWH(340, 560, 60, 40),
    ],
    goal: Rect.fromLTWH(345, 515, 45, 45),
    hazard: _Hazard(
      pivot: Offset(150, 530),
      length: 55,
      thickness: 8,
      angularSpeed: 2.8,
    ),
  ),
  // Level 15 — hardest: three tiers. Upper tier has two 35px gaps (110/100
  // wide runways) over a wide mid tier (160-400, a safety catch), which has
  // one 40px gap over a floor with a 45px gap (195-400 goal platform is
  // wide, another safety catch). The hazard guards the final approach
  // between the mid tier and the goal.
  const _LevelSpec(
    start: Offset(30, 180),
    platforms: [
      Rect.fromLTWH(0, 220, 110, 24),
      Rect.fromLTWH(145, 220, 100, 24),
      Rect.fromLTWH(280, 220, 120, 24),
      Rect.fromLTWH(0, 390, 120, 24),
      Rect.fromLTWH(160, 390, 240, 24),
      Rect.fromLTWH(0, 560, 150, 40),
      Rect.fromLTWH(195, 560, 205, 40),
    ],
    goal: Rect.fromLTWH(320, 515, 60, 45),
    hazard: _Hazard(
      pivot: Offset(250, 500),
      length: 60,
      thickness: 8,
      angularSpeed: 3.2,
    ),
  ),
];

class RagdollTrialsScreen extends StatefulWidget {
  const RagdollTrialsScreen({super.key, required this.ctx});

  final GameLevelContext ctx;

  @override
  State<RagdollTrialsScreen> createState() => _RagdollTrialsScreenState();
}

class _RagdollTrialsScreenState extends State<RagdollTrialsScreen>
    with TickerProviderStateMixin {
  static const double _canvasW = 400;
  static const double _canvasH = 600;
  static const double _blobRadius = 14;
  static const double _gravity = 1500; // logical px/s^2
  static const double _pushAccel = 950; // logical px/s^2 while held
  static const double _maxHorizSpeed = 240;
  static const double _damping = 0.999; // per substep
  static const int _substeps = 6;
  static const double _settleSpeed = 45;
  static const int _settleTicksNeeded = 20;
  static const double _rotationFactor = 0.012;

  late _LevelSpec _spec;
  late Offset _pos;
  Offset _vel = Offset.zero;
  double _visualRotation = 0;
  double _elapsedSeconds = 0;

  bool _pushLeftHeld = false;
  bool _pushRightHeld = false;

  bool _failed = false;
  bool _completed = false;
  int _failCount = 0;
  int _settleCounter = 0;

  Ticker? _ticker;
  Duration _lastElapsed = Duration.zero;
  late AnimationController _pulseController;

  int get _level => widget.ctx.level;

  @override
  void initState() {
    super.initState();
    _spec = _levels[(_level - 1).clamp(0, _levels.length - 1)];
    _pos = _spec.start;
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    if (AppSettingsStore.instance.animationsEnabled.value) {
      _pulseController.repeat(reverse: true);
    } else {
      _pulseController.value = 1;
    }
    _lastElapsed = Duration.zero;
    _ticker = createTicker(_onTick)..start();
  }

  @override
  void dispose() {
    _ticker?.stop();
    _ticker?.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  // --- Simulation ----------------------------------------------------

  void _onTick(Duration elapsed) {
    if (!mounted) return;
    if (_failed || _completed) return;
    var dt = (elapsed - _lastElapsed).inMicroseconds / 1e6;
    _lastElapsed = elapsed;
    if (dt <= 0) return;
    if (dt > 1 / 30) dt = 1 / 30;

    final subDt = dt / _substeps;
    for (var i = 0; i < _substeps; i++) {
      _stepPhysics(subDt);
      if (_failed) break;
    }
    if (!_failed) {
      _checkSettle();
    }

    if (!mounted) return;
    setState(() {});
  }

  void _stepPhysics(double dt) {
    _elapsedSeconds += dt;

    var vx = _vel.dx;
    if (_pushLeftHeld) vx -= _pushAccel * dt;
    if (_pushRightHeld) vx += _pushAccel * dt;
    vx = vx.clamp(-_maxHorizSpeed, _maxHorizSpeed);
    final vy = _vel.dy + _gravity * dt;
    _vel = Offset(vx, vy);

    _pos += _vel * dt;
    _vel = _vel * _damping;

    _visualRotation += _vel.dx * dt * _rotationFactor;

    _resolveWalls();
    for (final rect in _spec.platforms) {
      _resolveRect(rect);
    }

    final hazard = _spec.hazard;
    if (hazard != null && _hitsHazard(hazard)) {
      _triggerFail();
      return;
    }

    if (_pos.dy - _blobRadius > _canvasH) {
      _triggerFail();
    }
  }

  void _resolveWalls() {
    if (_pos.dx - _blobRadius < 0) {
      _pos = Offset(_blobRadius, _pos.dy);
      if (_vel.dx < 0) _vel = Offset(0, _vel.dy);
    } else if (_pos.dx + _blobRadius > _canvasW) {
      _pos = Offset(_canvasW - _blobRadius, _pos.dy);
      if (_vel.dx > 0) _vel = Offset(0, _vel.dy);
    }
  }

  void _resolveRect(Rect rect) {
    final closestX = _pos.dx.clamp(rect.left, rect.right);
    final closestY = _pos.dy.clamp(rect.top, rect.bottom);
    final diff = _pos - Offset(closestX, closestY);
    final dist = diff.distance;

    if (dist > 0.0001) {
      if (dist >= _blobRadius) return;
      final normal = diff / dist;
      final penetration = _blobRadius - dist;
      _pos += normal * penetration;
      _zeroAlongNormal(normal);
    } else {
      // Center is exactly inside the rect: push out along the shallowest
      // overlap axis, matching "top -> zero vertical", "side -> zero
      // horizontal" behavior for the degenerate case.
      final overlapLeft = _pos.dx - rect.left;
      final overlapRight = rect.right - _pos.dx;
      final overlapTop = _pos.dy - rect.top;
      final overlapBottom = rect.bottom - _pos.dy;
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
      _pos += normal * (minOverlap + _blobRadius);
      _zeroAlongNormal(normal);
    }
  }

  /// Zeroes the velocity component along the collision normal: landing on
  /// top of a platform (normal pointing up) zeroes vertical velocity and
  /// lets the blob rest; hitting a side wall (horizontal normal) zeroes
  /// horizontal velocity. No bounce (this is a resting collision, not a
  /// reflective one).
  void _zeroAlongNormal(Offset normal) {
    final vn = _vel.dx * normal.dx + _vel.dy * normal.dy;
    if (vn < 0) {
      _vel -= normal * vn;
    }
  }

  bool _hitsHazard(_Hazard hazard) {
    final angle = _Hazard.baseAngle + hazard.angularSpeed * _elapsedSeconds;
    final dir = Offset(cos(angle), sin(angle));
    final half = dir * (hazard.length / 2);
    final p1 = hazard.pivot + half;
    final p2 = hazard.pivot - half;

    final seg = p2 - p1;
    final len2 = seg.dx * seg.dx + seg.dy * seg.dy;
    var t = 0.0;
    if (len2 > 1e-6) {
      final toP = _pos - p1;
      t = ((toP.dx * seg.dx + toP.dy * seg.dy) / len2).clamp(0.0, 1.0);
    }
    final closest = p1 + seg * t;
    final dist = (_pos - closest).distance;
    return dist < _blobRadius + hazard.thickness / 2;
  }

  void _triggerFail() {
    if (_failed || _completed) return;
    _failed = true;
    _failCount++;
    _ticker?.stop();
  }

  void _checkSettle() {
    if (_completed) return;
    final speed = _vel.distance;
    final inGoal = _spec.goal.contains(_pos);
    if (inGoal && speed < _settleSpeed) {
      _settleCounter++;
    } else {
      _settleCounter = 0;
    }
    if (_settleCounter >= _settleTicksNeeded) {
      _completed = true;
      _ticker?.stop();
      final stars = _failCount == 0 ? 3 : (_failCount <= 2 ? 2 : 1);
      Future.microtask(() {
        if (!mounted) return;
        widget.ctx.onComplete(stars: stars);
      });
    }
  }

  void _retry() {
    if (!mounted) return;
    setState(() {
      _pos = _spec.start;
      _vel = Offset.zero;
      _visualRotation = 0;
      _settleCounter = 0;
      _failed = false;
      _pushLeftHeld = false;
      _pushRightHeld = false;
    });
    _lastElapsed = Duration.zero;
    _ticker?.stop();
    _ticker?.dispose();
    _ticker = createTicker(_onTick)..start();
  }

  void _setPushLeft(bool held) {
    if (!mounted) return;
    setState(() => _pushLeftHeld = held);
  }

  void _setPushRight(bool held) {
    if (!mounted) return;
    setState(() => _pushRightHeld = held);
  }

  // --- UI --------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Ragdoll Trials · Level $_level'),
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
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Falls this attempt: $_failCount',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  _completed
                      ? 'Settled!'
                      : (_failed ? 'Failed' : 'Push toward the goal'),
                  style: TextStyle(
                    color: _completed
                        ? AppTheme.success
                        : (_failed ? AppTheme.danger : AppTheme.textSecondary),
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
                  child: Stack(
                    children: [
                      LayoutBuilder(
                        builder: (context, constraints) {
                          return AnimatedBuilder(
                            animation: _pulseController,
                            builder: (context, _) {
                              return CustomPaint(
                                size: Size(
                                  constraints.maxWidth,
                                  constraints.maxHeight,
                                ),
                                painter: _RagdollTrialsPainter(
                                  scale: constraints.maxWidth / _canvasW,
                                  spec: _spec,
                                  pos: _pos,
                                  visualRotation: _visualRotation,
                                  elapsedSeconds: _elapsedSeconds,
                                  pulse: _pulseController.value,
                                ),
                              );
                            },
                          );
                        },
                      ),
                      if (_failed || _completed)
                        Positioned.fill(
                          child: Container(
                            color: Colors.black.withValues(alpha: 0.55),
                            alignment: Alignment.center,
                            child: _failed ? _buildFailBanner() : null,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          _buildControls(),
        ],
      ),
    );
  }

  Widget _buildFailBanner() {
    return Container(
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: AppTheme.surfaceHigh,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.close_rounded, color: AppTheme.danger, size: 36),
          const SizedBox(height: 8),
          Text(
            'The blob fell!',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              OutlinedButton(
                onPressed: widget.ctx.onExit,
                child: const Text('Menu'),
              ),
              const SizedBox(width: 10),
              ElevatedButton(onPressed: _retry, child: const Text('Retry')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildControls() {
    final canPlay = !_failed && !_completed;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Row(
        children: [
          Expanded(
            child: _buildHoldButton(
              Icons.chevron_left_rounded,
              canPlay,
              _setPushLeft,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _buildHoldButton(
              Icons.chevron_right_rounded,
              canPlay,
              _setPushRight,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHoldButton(
    IconData icon,
    bool enabled,
    void Function(bool) setHeld,
  ) {
    return GestureDetector(
      onTapDown: enabled ? (_) => setHeld(true) : null,
      onTapUp: enabled ? (_) => setHeld(false) : null,
      onTapCancel: enabled ? () => setHeld(false) : null,
      child: Container(
        height: 64,
        decoration: BoxDecoration(
          color: AppTheme.surfaceHigh,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Icon(icon, color: AppTheme.accent, size: 36),
      ),
    );
  }
}

class _RagdollTrialsPainter extends CustomPainter {
  _RagdollTrialsPainter({
    required this.scale,
    required this.spec,
    required this.pos,
    required this.visualRotation,
    required this.elapsedSeconds,
    required this.pulse,
  });

  final double scale;
  final _LevelSpec spec;
  final Offset pos;
  final double visualRotation;
  final double elapsedSeconds;
  final double pulse;

  static const double _blobRadius = 14;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(scale);

    final backdrop = RRect.fromRectAndRadius(
      const Rect.fromLTWH(0, 0, 400, 600),
      const Radius.circular(16),
    );
    canvas.drawRRect(backdrop, Paint()..color = AppTheme.surface);

    for (final rect in spec.platforms) {
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
    final goalRR = RRect.fromRectAndRadius(
      spec.goal,
      const Radius.circular(10),
    );
    final pulseAlpha = 0.28 + 0.24 * pulse;
    canvas.drawRRect(
      goalRR,
      Paint()..color = AppTheme.success.withValues(alpha: pulseAlpha),
    );
    canvas.drawRRect(
      goalRR,
      Paint()
        ..color = AppTheme.success
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );

    // Hazard.
    final hazard = spec.hazard;
    if (hazard != null) {
      final angle = _Hazard.baseAngle + hazard.angularSpeed * elapsedSeconds;
      final dir = Offset(cos(angle), sin(angle));
      final half = dir * (hazard.length / 2);
      final p1 = hazard.pivot + half;
      final p2 = hazard.pivot - half;
      canvas.drawLine(
        p1,
        p2,
        Paint()
          ..color = AppTheme.danger
          ..strokeWidth = hazard.thickness
          ..strokeCap = StrokeCap.round,
      );
      canvas.drawCircle(hazard.pivot, 4, Paint()..color = AppTheme.danger);
    }

    // Blob: an elongated rounded-rect capsule that visually rotates with
    // horizontal velocity. Physics uses a circle of the same radius; this
    // rotation is purely cosmetic.
    canvas.save();
    canvas.translate(pos.dx, pos.dy);
    canvas.rotate(visualRotation);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset.zero,
          width: _blobRadius * 2.4,
          height: _blobRadius * 1.5,
        ),
        Radius.circular(_blobRadius * 0.75),
      ),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    final capsule = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset.zero,
        width: _blobRadius * 2.2,
        height: _blobRadius * 1.3,
      ),
      Radius.circular(_blobRadius * 0.65),
    );
    canvas.drawRRect(capsule, Paint()..color = AppTheme.accent);
    canvas.drawRRect(
      capsule,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    canvas.restore();

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _RagdollTrialsPainter oldDelegate) => true;
}
