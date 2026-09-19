import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../character_store.dart';

/// Draws the user's customizable "brain buddy" mascot: the same brain
/// silhouette language as the app icon (a cluster of overlapping lobes,
/// wrinkle grooves, two-tone shading), with a chosen face and accessory on
/// top. Pure paint, no state — [CharacterBadge] below wraps this with the
/// live [CharacterStore] values and an idle bob animation.
class CharacterAvatar extends StatelessWidget {
  const CharacterAvatar({
    super.key,
    required this.size,
    required this.color,
    required this.expression,
    required this.accessory,
  });

  final double size;
  final CharacterColorOption color;
  final CharacterExpression expression;
  final CharacterAccessory accessory;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _CharacterPainter(
          color: color,
          expression: expression,
          accessory: accessory,
        ),
      ),
    );
  }
}

/// The home screen's live avatar: wraps [CharacterAvatar] with the current
/// [CharacterStore] values, so it repaints whenever the user changes their
/// buddy's look. Deliberately static (no idle animation) — a
/// perpetually-repeating animation would keep `pumpAndSettle` from ever
/// settling in every widget test that opens the home screen.
class CharacterBadge extends StatelessWidget {
  const CharacterBadge({super.key, required this.size, this.onTap});

  final double size;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final store = CharacterStore.instance;
    final avatar = ValueListenableBuilder<int>(
      valueListenable: store.colorIndex,
      builder: (context, colorIndex, _) {
        return ValueListenableBuilder<CharacterExpression>(
          valueListenable: store.expression,
          builder: (context, expression, _) {
            return ValueListenableBuilder<CharacterAccessory>(
              valueListenable: store.accessory,
              builder: (context, accessory, _) {
                return CharacterAvatar(
                  size: size,
                  color: characterColors[colorIndex],
                  expression: expression,
                  accessory: accessory,
                );
              },
            );
          },
        );
      },
    );

    return Semantics(
      button: onTap != null,
      label: 'Customize your buddy',
      child: GestureDetector(onTap: onTap, child: avatar),
    );
  }
}

class _CharacterPainter extends CustomPainter {
  _CharacterPainter({
    required this.color,
    required this.expression,
    required this.accessory,
  });

  final CharacterColorOption color;
  final CharacterExpression expression;
  final CharacterAccessory accessory;

  // Same union-of-circles silhouette as the app icon's brain mask, in a
  // normalized 0..1 space so it scales to any paint size.
  static const List<List<double>> _lobes = [
    [0.38, 0.39, 0.171],
    [0.62, 0.39, 0.171],
    [0.337, 0.322, 0.103],
    [0.663, 0.322, 0.103],
    [0.303, 0.459, 0.098],
    [0.697, 0.459, 0.098],
    [0.352, 0.586, 0.112],
    [0.648, 0.586, 0.112],
    [0.5, 0.625, 0.127],
    [0.5, 0.293, 0.137],
  ];

  Path _brainPath(Size size) {
    final s = size.shortestSide;
    final ox = (size.width - s) / 2;
    final oy = (size.height - s) / 2;
    Offset pt(double nx, double ny) => Offset(ox + nx * s, oy + ny * s);

    var path = Path();
    for (final lobe in _lobes) {
      final center = pt(lobe[0], lobe[1]);
      path = Path.combine(
        PathOperation.union,
        path,
        Path()..addOval(Rect.fromCircle(center: center, radius: lobe[2] * s)),
      );
    }
    final stem = RRect.fromRectAndRadius(
      Rect.fromLTRB(
        pt(0.461, 0.674).dx,
        pt(0.461, 0.674).dy,
        pt(0.539, 0.781).dx,
        pt(0.539, 0.781).dy,
      ),
      Radius.circular(0.03 * s),
    );
    path = Path.combine(
      PathOperation.union,
      path,
      Path()..addRRect(stem),
    );
    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final center = Offset(size.width / 2, size.height / 2);
    final brain = _brainPath(size);
    final bounds = brain.getBounds();

    canvas.save();
    canvas.clipPath(brain);

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [color.light, color.dark],
      ).createShader(bounds);
    canvas.drawRect(bounds, fillPaint);

    _drawGrooves(canvas, size, s);
    _drawFace(canvas, size, s);

    canvas.restore();

    _drawAccessory(canvas, size, s, center);
  }

  void _drawGrooves(Canvas canvas, Size size, double s) {
    final paint = Paint()
      ..color = color.groove
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = s * 0.018;

    final top = Offset(size.width / 2, size.height * 0.32);
    final bottom = Offset(size.width / 2, size.height * 0.62);
    canvas.drawLine(top, bottom, paint);

    for (final side in [-1.0, 1.0]) {
      final cx = size.width / 2 + side * s * 0.135;
      for (final cy in [0.42, 0.5]) {
        final rect = Rect.fromCenter(
          center: Offset(cx, size.height * cy),
          width: s * 0.22,
          height: s * 0.16,
        );
        canvas.drawArc(rect, math.pi * 0.15, math.pi * 0.7, false, paint);
      }
    }
  }

  void _drawFace(Canvas canvas, Size size, double s) {
    final eyeY = size.height * 0.5;
    final eyeDx = s * 0.11;
    final leftEye = Offset(size.width / 2 - eyeDx, eyeY);
    final rightEye = Offset(size.width / 2 + eyeDx, eyeY);
    final mouthCenter = Offset(size.width / 2, size.height * 0.6);

    final ink = Paint()..color = const Color(0xFF2A1E00);
    final stroke = Paint()
      ..color = const Color(0xFF2A1E00)
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.022
      ..strokeCap = StrokeCap.round;

    switch (expression) {
      case CharacterExpression.happy:
        canvas.drawCircle(leftEye, s * 0.028, ink);
        canvas.drawCircle(rightEye, s * 0.028, ink);
        final path = Path()
          ..moveTo(mouthCenter.dx - s * 0.07, mouthCenter.dy)
          ..quadraticBezierTo(
            mouthCenter.dx,
            mouthCenter.dy + s * 0.055,
            mouthCenter.dx + s * 0.07,
            mouthCenter.dy,
          );
        canvas.drawPath(path, stroke);
      case CharacterExpression.cool:
        for (final e in [leftEye, rightEye]) {
          canvas.drawLine(
            Offset(e.dx - s * 0.03, e.dy),
            Offset(e.dx + s * 0.03, e.dy),
            stroke,
          );
        }
        final path = Path()
          ..moveTo(mouthCenter.dx - s * 0.06, mouthCenter.dy)
          ..quadraticBezierTo(
            mouthCenter.dx + s * 0.02,
            mouthCenter.dy + s * 0.035,
            mouthCenter.dx + s * 0.07,
            mouthCenter.dy - s * 0.01,
          );
        canvas.drawPath(path, stroke);
      case CharacterExpression.sleepy:
        for (final e in [leftEye, rightEye]) {
          final rect = Rect.fromCenter(
            center: e,
            width: s * 0.07,
            height: s * 0.05,
          );
          canvas.drawArc(rect, math.pi, math.pi, false, stroke);
        }
        canvas.drawCircle(mouthCenter, s * 0.02, ink);
      case CharacterExpression.surprised:
        canvas.drawCircle(leftEye, s * 0.032, ink);
        canvas.drawCircle(rightEye, s * 0.032, ink);
        canvas.drawCircle(mouthCenter, s * 0.035, stroke);
      case CharacterExpression.wink:
        canvas.drawCircle(leftEye, s * 0.028, ink);
        canvas.drawLine(
          Offset(rightEye.dx - s * 0.03, rightEye.dy),
          Offset(rightEye.dx + s * 0.03, rightEye.dy),
          stroke,
        );
        final path = Path()
          ..moveTo(mouthCenter.dx - s * 0.07, mouthCenter.dy - s * 0.01)
          ..quadraticBezierTo(
            mouthCenter.dx,
            mouthCenter.dy + s * 0.06,
            mouthCenter.dx + s * 0.07,
            mouthCenter.dy - s * 0.02,
          );
        canvas.drawPath(path, stroke);
    }
  }

  void _drawAccessory(Canvas canvas, Size size, double s, Offset center) {
    switch (accessory) {
      case CharacterAccessory.none:
        return;
      case CharacterAccessory.cap:
        _drawCap(canvas, size, s);
      case CharacterAccessory.glasses:
        _drawGlasses(canvas, size, s);
      case CharacterAccessory.bowtie:
        _drawBowtie(canvas, size, s);
      case CharacterAccessory.headphones:
        _drawHeadphones(canvas, size, s);
    }
  }

  void _drawCap(Canvas canvas, Size size, double s) {
    final top = Offset(size.width / 2, size.height * 0.24);
    final board = Paint()..color = const Color(0xFF2B2B3A);
    final boardRect = Rect.fromCenter(
      center: top,
      width: s * 0.42,
      height: s * 0.1,
    );
    canvas.save();
    canvas.translate(boardRect.center.dx, boardRect.center.dy);
    canvas.rotate(-0.08);
    canvas.translate(-boardRect.center.dx, -boardRect.center.dy);
    canvas.drawRect(boardRect, board);
    canvas.restore();

    final button = Paint()..color = const Color(0xFFFFD34D);
    canvas.drawCircle(top, s * 0.02, button);
    final tassel = Paint()
      ..color = const Color(0xFFFFD34D)
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.015;
    canvas.drawLine(top, Offset(top.dx + s * 0.05, top.dy + s * 0.09), tassel);
  }

  void _drawGlasses(Canvas canvas, Size size, double s) {
    final y = size.height * 0.5;
    final dx = s * 0.11;
    final frame = Paint()
      ..color = const Color(0xFF2A1E00)
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.02;
    final leftRect = Rect.fromCenter(
      center: Offset(size.width / 2 - dx, y),
      width: s * 0.16,
      height: s * 0.13,
    );
    final rightRect = Rect.fromCenter(
      center: Offset(size.width / 2 + dx, y),
      width: s * 0.16,
      height: s * 0.13,
    );
    canvas.drawOval(leftRect, frame);
    canvas.drawOval(rightRect, frame);
    canvas.drawLine(
      Offset(leftRect.right, y),
      Offset(rightRect.left, y),
      frame,
    );
  }

  void _drawBowtie(Canvas canvas, Size size, double s) {
    final center = Offset(size.width / 2, size.height * 0.74);
    final paint = Paint()..color = color.groove;
    final left = Path()
      ..moveTo(center.dx - s * 0.02, center.dy)
      ..lineTo(center.dx - s * 0.1, center.dy - s * 0.05)
      ..lineTo(center.dx - s * 0.1, center.dy + s * 0.05)
      ..close();
    final right = Path()
      ..moveTo(center.dx + s * 0.02, center.dy)
      ..lineTo(center.dx + s * 0.1, center.dy - s * 0.05)
      ..lineTo(center.dx + s * 0.1, center.dy + s * 0.05)
      ..close();
    canvas.drawPath(left, paint);
    canvas.drawPath(right, paint);
    canvas.drawCircle(center, s * 0.02, paint);
  }

  void _drawHeadphones(Canvas canvas, Size size, double s) {
    final paint = Paint()
      ..color = const Color(0xFF2B2B3A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.03
      ..strokeCap = StrokeCap.round;
    final band = Rect.fromCenter(
      center: Offset(size.width / 2, size.height * 0.42),
      width: s * 0.62,
      height: s * 0.5,
    );
    canvas.drawArc(band, math.pi * 1.05, math.pi * 0.9, false, paint);

    final cupFill = Paint()..color = const Color(0xFF2B2B3A);
    canvas.drawCircle(
      Offset(size.width * 0.19, size.height * 0.46),
      s * 0.07,
      cupFill,
    );
    canvas.drawCircle(
      Offset(size.width * 0.81, size.height * 0.46),
      s * 0.07,
      cupFill,
    );
  }

  @override
  bool shouldRepaint(covariant _CharacterPainter oldDelegate) {
    return color != oldDelegate.color ||
        expression != oldDelegate.expression ||
        accessory != oldDelegate.accessory;
  }
}
