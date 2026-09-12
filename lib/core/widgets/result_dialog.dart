import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../settings_store.dart';
import '../sound.dart';

/// Non-modal "you won" celebration shown *above* the still-visible solved
/// board: a brief confetti burst plus a compact bottom action bar.
/// Deliberately not a centered dialog — the point is to not hide the board
/// the player just solved. `GameHost` shows/hides this via a `Stack`, not a
/// dialog route, so its callbacks must never call `Navigator.pop` for
/// "hide" — only `onMenu` actually leaves the screen.
class LevelCompleteOverlay extends StatefulWidget {
  const LevelCompleteOverlay({
    super.key,
    required this.stars,
    required this.hasNextLevel,
    required this.onNext,
    required this.onRetry,
    required this.onMenu,
  });

  final int stars;
  final bool hasNextLevel;
  final VoidCallback onNext;
  final VoidCallback onRetry;
  final VoidCallback onMenu;

  @override
  State<LevelCompleteOverlay> createState() => _LevelCompleteOverlayState();
}

class _LevelCompleteOverlayState extends State<LevelCompleteOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<_Confetto> _confetti;
  late final bool _animate;

  @override
  void initState() {
    super.initState();
    Sfx.success();
    _animate = AppSettingsStore.instance.animationsEnabled.value;
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: _animate ? 1100 : 1),
    )..forward();
    final rng = math.Random();
    _confetti = _animate
        ? List.generate(28, (_) => _Confetto.random(rng))
        : const [];
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        if (_confetti.isNotEmpty)
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) => CustomPaint(
                  painter: _ConfettiPainter(_confetti, _controller.value),
                ),
              ),
            ),
          ),
        Align(
          alignment: Alignment.bottomCenter,
          child: SafeArea(
            child: Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: AppTheme.surfaceHigh,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(3, (i) {
                      final filled = i < widget.stars;
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: Icon(
                          filled
                              ? Icons.star_rounded
                              : Icons.star_outline_rounded,
                          color: filled
                              ? AppTheme.warning
                              : AppTheme.textSecondary,
                          size: 28,
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: widget.onMenu,
                          child: const Text('Menu'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextButton(
                          onPressed: widget.onRetry,
                          child: const Text('Retry'),
                        ),
                      ),
                      if (widget.hasNextLevel) ...[
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed: widget.onNext,
                            child: const Text('Next'),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Confetto {
  const _Confetto(this.x, this.color, this.size, this.delay, this.wobble);

  /// Horizontal spawn position, 0..1 fraction of the overlay width.
  final double x;
  final Color color;
  final double size;

  /// Fraction (0..~0.3) of the animation the piece waits before falling.
  final double delay;
  final double wobble;

  static _Confetto random(math.Random rng) {
    const colors = [
      Color(0xFFF5A623),
      Color(0xFF5B6EF5),
      Color(0xFF22B573),
      Color(0xFFE0433B),
      Color(0xFFFB7185),
      Color(0xFF60A5FA),
    ];
    return _Confetto(
      rng.nextDouble(),
      colors[rng.nextInt(colors.length)],
      6 + rng.nextDouble() * 6,
      rng.nextDouble() * 0.25,
      rng.nextDouble() * 2 * math.pi,
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.confetti, this.t);

  final List<_Confetto> confetti;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    for (final c in confetti) {
      final span = 1 - c.delay;
      if (span <= 0) continue;
      final local = ((t - c.delay) / span).clamp(0.0, 1.0);
      if (local <= 0) continue;
      final dy = local * (size.height * 0.6);
      final dx = c.x * size.width + math.sin(local * 6 + c.wobble) * 14;
      final opacity = (1 - local).clamp(0.0, 1.0);
      final paint = Paint()..color = c.color.withValues(alpha: opacity);
      canvas.save();
      canvas.translate(dx, dy);
      canvas.rotate(local * 6 + c.wobble);
      canvas.drawRect(
        Rect.fromCenter(center: Offset.zero, width: c.size, height: c.size),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) =>
      oldDelegate.t != t;
}

/// Shared "try again" dialog for a failed attempt. Unlike the win case,
/// there's no solved board worth keeping visible here, so a modal dialog is
/// still the right call.
Future<void> showLevelFailedDialog(
  BuildContext context, {
  String message = "That didn't quite work out.",
  required VoidCallback onRetry,
  required VoidCallback onMenu,
}) {
  Sfx.error();
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      return AlertDialog(
        title: const Text('Try again'),
        content: Text(message),
        actionsAlignment: MainAxisAlignment.spaceBetween,
        actions: [
          TextButton(onPressed: onMenu, child: const Text('Menu')),
          ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      );
    },
  );
}
