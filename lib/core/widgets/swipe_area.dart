import 'package:flutter/material.dart';

/// One of the four cardinal directions reported by [SwipeArea].
enum SwipeDirection { up, down, left, right }

/// Full-area swipe detector for swipe-driven games (merge2048, rule_breaker,
/// and the d-pad games that also accept a swipe). Fixes two separate causes
/// of a cramped-feeling swipe: wrap this around the *whole* body/`Expanded`
/// (not just the board widget) and it uses `HitTestBehavior.opaque`, so the
/// live area is the whole wrapped region rather than just the board's
/// painted rect; and it resolves on total drag *distance*, not velocity, so
/// a slow, deliberate swipe still registers as long as it travels far
/// enough — only a genuinely small/ambiguous drag is ignored.
class SwipeArea extends StatefulWidget {
  const SwipeArea({
    super.key,
    required this.onSwipe,
    required this.child,
    this.minDistance = 48,
  });

  final ValueChanged<SwipeDirection> onSwipe;
  final Widget child;

  /// Minimum total drag distance (logical pixels) before a swipe registers,
  /// regardless of how slowly it was drawn.
  final double minDistance;

  @override
  State<SwipeArea> createState() => _SwipeAreaState();
}

class _SwipeAreaState extends State<SwipeArea> {
  Offset _start = Offset.zero;
  Offset _current = Offset.zero;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanStart: (details) {
        _start = details.globalPosition;
        _current = details.globalPosition;
      },
      onPanUpdate: (details) {
        _current = details.globalPosition;
      },
      onPanEnd: (_) => _resolve(),
      onPanCancel: () => _current = _start,
      child: widget.child,
    );
  }

  void _resolve() {
    final delta = _current - _start;
    if (delta.distance < widget.minDistance) return;
    if (delta.dx.abs() > delta.dy.abs()) {
      widget.onSwipe(delta.dx > 0 ? SwipeDirection.right : SwipeDirection.left);
    } else {
      widget.onSwipe(delta.dy > 0 ? SwipeDirection.down : SwipeDirection.up);
    }
  }
}
