import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'watch_design.dart' show WatchCaptureFamily, WatchPalette;

/// Whistle capture mark.
///
/// Implementation derivative reconstructed from the approved Live board.
/// It is not a frozen source SVG and it is not evidence of a save.
class WatchCaptureGlyph extends StatelessWidget {
  const WatchCaptureGlyph({super.key});

  @override
  Widget build(BuildContext context) {
    return const CustomPaint(
      key: Key('watch-capture-glyph'),
      painter: _WhistlePainter(),
      child: SizedBox.expand(),
    );
  }
}

class _WhistlePainter extends CustomPainter {
  const _WhistlePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = WatchPalette.ink
      ..style = PaintingStyle.fill;
    final w = size.width;
    final h = size.height;
    final head = Rect.fromCenter(
      center: Offset(w * 0.46, h * 0.34),
      width: w * 0.34,
      height: h * 0.34,
    );
    canvas.drawOval(head, paint);
    final shoulders = Path()
      ..moveTo(w * 0.22, h * 0.92)
      ..lineTo(w * 0.32, h * 0.52)
      ..lineTo(w * 0.68, h * 0.52)
      ..lineTo(w * 0.84, h * 0.92)
      ..close();
    canvas.drawPath(shoulders, paint);
    final whistle = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.58, h * 0.30, w * 0.30, h * 0.12),
      Radius.circular(h * 0.06),
    );
    canvas.drawRRect(whistle, paint);
    canvas.drawCircle(Offset(w * 0.86, h * 0.36), h * 0.045, paint);
  }

  @override
  bool shouldRepaint(covariant _WhistlePainter oldDelegate) => false;
}

/// Four event-family marks.
///
/// Implementation derivatives. The hexagon and the picture distinguish the
/// family together with the factual label. Color is not the only difference.
class WatchFamilyMark extends StatelessWidget {
  const WatchFamilyMark({
    super.key,
    required this.family,
    this.blocked = false,
  });

  final WatchCaptureFamily family;
  final bool blocked;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      key: Key('watch-family-glyph-${family.name}'),
      painter: _FamilyPainter(family: family, blocked: blocked),
      child: const SizedBox.expand(),
    );
  }
}

class _FamilyPainter extends CustomPainter {
  const _FamilyPainter({required this.family, required this.blocked});

  final WatchCaptureFamily family;
  final bool blocked;

  @override
  void paint(Canvas canvas, Size size) {
    final color = blocked ? WatchPalette.steel : WatchPalette.ink;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    switch (family) {
      case WatchCaptureFamily.yellow:
        _card(canvas, size, WatchPalette.yellow, paint);
      case WatchCaptureFamily.red:
        _card(canvas, size, WatchPalette.red, paint);
      case WatchCaptureFamily.goal:
        _goal(canvas, size, paint);
      case WatchCaptureFamily.substitution:
        _sub(canvas, size, paint);
    }
  }

  void _card(Canvas canvas, Size size, Color card, Paint hand) {
    final cardPaint = Paint()
      ..color = blocked ? WatchPalette.steel : card
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          size.width * 0.52,
          size.height * 0.08,
          size.width * 0.34,
          size.height * 0.48,
        ),
        Radius.circular(size.shortestSide * 0.06),
      ),
      cardPaint,
    );
    final palm = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        size.width * 0.16,
        size.height * 0.42,
        size.width * 0.28,
        size.height * 0.40,
      ),
      Radius.circular(size.shortestSide * 0.08),
    );
    canvas.drawRRect(palm, hand);
    canvas.drawCircle(
      Offset(size.width * 0.22, size.height * 0.38),
      size.shortestSide * 0.07,
      hand,
    );
  }

  void _goal(Canvas canvas, Size size, Paint paint) {
    final stroke = Paint()
      ..color = paint.color
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.2, size.shortestSide * 0.06)
      ..strokeCap = StrokeCap.round;
    final left = size.width * 0.18;
    final right = size.width * 0.78;
    final top = size.height * 0.22;
    final bottom = size.height * 0.72;
    canvas.drawLine(Offset(left, bottom), Offset(left, top), stroke);
    canvas.drawLine(Offset(left, top), Offset(right, top), stroke);
    canvas.drawLine(Offset(right, top), Offset(right, bottom), stroke);
    canvas.drawCircle(
      Offset(size.width * 0.48, size.height * 0.55),
      size.shortestSide * 0.12,
      paint,
    );
  }

  void _sub(Canvas canvas, Size size, Paint paint) {
    canvas.drawCircle(
      Offset(size.width * 0.32, size.height * 0.30),
      size.shortestSide * 0.10,
      paint,
    );
    canvas.drawCircle(
      Offset(size.width * 0.68, size.height * 0.62),
      size.shortestSide * 0.10,
      paint,
    );
    final stroke = Paint()
      ..color = blocked ? WatchPalette.steel : WatchPalette.turquoise
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.2, size.shortestSide * 0.07)
      ..strokeCap = StrokeCap.round;
    final forward = Path()
      ..moveTo(size.width * 0.42, size.height * 0.28)
      ..lineTo(size.width * 0.78, size.height * 0.28)
      ..lineTo(size.width * 0.68, size.height * 0.16);
    canvas.drawPath(forward, stroke);
    final back = Path()
      ..moveTo(size.width * 0.58, size.height * 0.72)
      ..lineTo(size.width * 0.22, size.height * 0.72)
      ..lineTo(size.width * 0.32, size.height * 0.84);
    canvas.drawPath(back, stroke);
  }

  @override
  bool shouldRepaint(covariant _FamilyPainter oldDelegate) {
    return oldDelegate.family != family || oldDelegate.blocked != blocked;
  }
}

/// Quiet list mark beside CAUTIONS. It does not encode a caution count.
class WatchListGlyph extends StatelessWidget {
  const WatchListGlyph({super.key});

  @override
  Widget build(BuildContext context) {
    return const CustomPaint(
      key: Key('watch-cautions-glyph'),
      painter: _ListPainter(),
      child: SizedBox(width: 16, height: 14),
    );
  }
}

class _ListPainter extends CustomPainter {
  const _ListPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = WatchPalette.steel
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    for (var row = 0; row < 3; row++) {
      final y = size.height * (0.2 + row * 0.3);
      canvas.drawCircle(Offset(size.width * 0.12, y), 1.2,
          Paint()..color = WatchPalette.steel);
      canvas.drawLine(
        Offset(size.width * 0.32, y),
        Offset(size.width * 0.92, y),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ListPainter oldDelegate) => false;
}

/// Profile referee with a whistle. Round Live A1 only.
///
/// Implementation derivative of the approved centered-round board.
/// It is not a frozen source SVG and it is not a save.
class WatchRefereeMark extends StatelessWidget {
  const WatchRefereeMark({super.key});

  @override
  Widget build(BuildContext context) {
    return const CustomPaint(
      key: Key('watch-capture-glyph'),
      painter: _RefereePainter(),
      child: SizedBox.expand(),
    );
  }
}

class _RefereePainter extends CustomPainter {
  const _RefereePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = WatchPalette.ink;
    final w = size.width;
    final h = size.height;
    final bust = Path()
      ..moveTo(w * 0.08, h * 0.98)
      ..quadraticBezierTo(w * 0.16, h * 0.64, w * 0.36, h * 0.58)
      ..lineTo(w * 0.40, h * 0.50)
      ..lineTo(w * 0.72, h * 0.64)
      ..quadraticBezierTo(w * 0.86, h * 0.72, w * 0.94, h * 0.98)
      ..close();
    canvas.drawPath(bust, paint);
    canvas.drawCircle(
      Offset(w * 0.38, h * 0.32),
      math.min(w, h) * 0.20,
      paint,
    );
    final nose = Path()
      ..moveTo(w * 0.50, h * 0.28)
      ..lineTo(w * 0.64, h * 0.34)
      ..lineTo(w * 0.50, h * 0.40)
      ..close();
    canvas.drawPath(nose, paint);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.58, h * 0.36, w * 0.26, h * 0.10),
        Radius.circular(h * 0.05),
      ),
      paint,
    );
    canvas.drawCircle(Offset(w * 0.88, h * 0.41), h * 0.045, paint);
  }

  @override
  bool shouldRepaint(covariant _RefereePainter oldDelegate) => false;
}

/// Pointy-top family picture used inside the round capture hexagons.
///
/// Implementation derivative. The picture and the label name the family.
/// Color is not the only difference. Not a frozen source SVG.
class WatchRoundFamilyMark extends StatelessWidget {
  const WatchRoundFamilyMark({
    super.key,
    required this.family,
    this.blocked = false,
  });

  final WatchCaptureFamily family;
  final bool blocked;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      key: Key('watch-family-glyph-${family.name}'),
      painter: _RoundFamilyPainter(family: family, blocked: blocked),
      child: const SizedBox.expand(),
    );
  }
}

class _RoundFamilyPainter extends CustomPainter {
  const _RoundFamilyPainter({required this.family, required this.blocked});

  final WatchCaptureFamily family;
  final bool blocked;

  @override
  void paint(Canvas canvas, Size size) {
    final ink = blocked ? WatchPalette.steel : WatchPalette.ink;
    switch (family) {
      case WatchCaptureFamily.yellow:
        _cardHand(canvas, size, WatchPalette.yellow, ink);
      case WatchCaptureFamily.red:
        _cardHand(canvas, size, WatchPalette.red, ink);
      case WatchCaptureFamily.goal:
        _goal(canvas, size, ink);
      case WatchCaptureFamily.substitution:
        _exchange(canvas, size, ink);
    }
  }

  void _cardHand(Canvas canvas, Size size, Color card, Color ink) {
    final w = size.width;
    final h = size.height;
    final s = size.shortestSide;
    final cardPaint = Paint()..color = blocked ? WatchPalette.steel : card;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.38, h * 0.0, w * 0.44, h * 0.74),
        Radius.circular(math.max(1, s * 0.05)),
      ),
      cardPaint,
    );
    final hand = Paint()..color = ink;
    canvas.drawOval(
      Rect.fromLTWH(w * 0.04, h * 0.64, w * 0.46, h * 0.32),
      hand,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.24, h * 0.46, w * 0.18, h * 0.38),
        Radius.circular(s * 0.08),
      ),
      hand,
    );
    for (var i = 0; i < 3; i++) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(w * (0.46 + i * 0.11), h * 0.52, w * 0.08, h * 0.30),
          Radius.circular(s * 0.05),
        ),
        hand,
      );
    }
  }

  void _goal(Canvas canvas, Size size, Color ink) {
    final stroke = Paint()
      ..color = ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.1, size.shortestSide * 0.045)
      ..strokeJoin = StrokeJoin.miter;
    final frame = Rect.fromLTWH(
      size.width * 0.08,
      size.height * 0.08,
      size.width * 0.84,
      size.height * 0.62,
    );
    canvas.drawRect(frame, stroke);
    for (var i = 1; i <= 3; i++) {
      final x = frame.left + frame.width * i / 4;
      canvas.drawLine(Offset(x, frame.top), Offset(x, frame.bottom), stroke);
    }
    for (var i = 1; i <= 2; i++) {
      final y = frame.top + frame.height * i / 3;
      canvas.drawLine(Offset(frame.left, y), Offset(frame.right, y), stroke);
    }
    final ball = Offset(size.width * 0.40, size.height * 0.46);
    final ballRadius = size.shortestSide * 0.14;
    canvas.drawCircle(ball, ballRadius, Paint()..color = ink);
    canvas.drawArc(
      Rect.fromCircle(center: ball, radius: ballRadius * 0.62),
      -0.6,
      2.2,
      false,
      Paint()
        ..color = WatchPalette.deepNavy
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1, size.shortestSide * 0.035),
    );
    canvas.drawLine(
      Offset(size.width * 0.08, size.height * 0.86),
      Offset(size.width * 0.28, size.height * 0.86),
      stroke,
    );
    canvas.drawLine(
      Offset(size.width * 0.08, size.height * 0.96),
      Offset(size.width * 0.22, size.height * 0.96),
      stroke,
    );
  }

  void _exchange(Canvas canvas, Size size, Color ink) {
    final body = Paint()..color = ink;
    _person(canvas, Offset(size.width * 0.28, size.height * 0.46), size, body);
    _person(canvas, Offset(size.width * 0.72, size.height * 0.46), size, body);
    final arrow = Paint()
      ..color = blocked ? WatchPalette.steel : WatchPalette.turquoise
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.2, size.shortestSide * 0.055)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final forward = Path()
      ..moveTo(size.width * 0.28, size.height * 0.16)
      ..quadraticBezierTo(
        size.width * 0.50,
        size.height * 0.00,
        size.width * 0.74,
        size.height * 0.16,
      );
    canvas.drawPath(forward, arrow);
    canvas.drawLine(
      Offset(size.width * 0.62, size.height * 0.08),
      Offset(size.width * 0.74, size.height * 0.16),
      arrow,
    );
    canvas.drawLine(
      Offset(size.width * 0.64, size.height * 0.22),
      Offset(size.width * 0.74, size.height * 0.16),
      arrow,
    );
    final back = Path()
      ..moveTo(size.width * 0.72, size.height * 0.84)
      ..quadraticBezierTo(
        size.width * 0.50,
        size.height * 1.0,
        size.width * 0.26,
        size.height * 0.84,
      );
    canvas.drawPath(back, arrow);
    canvas.drawLine(
      Offset(size.width * 0.36, size.height * 0.78),
      Offset(size.width * 0.26, size.height * 0.84),
      arrow,
    );
    canvas.drawLine(
      Offset(size.width * 0.38, size.height * 0.92),
      Offset(size.width * 0.26, size.height * 0.84),
      arrow,
    );
  }

  void _person(Canvas canvas, Offset origin, Size size, Paint paint) {
    final r = size.shortestSide * 0.16;
    canvas.drawCircle(origin.translate(0, -r * 1.15), r * 0.72, paint);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: origin.translate(0, r * 0.85),
          width: r * 1.7,
          height: r * 1.9,
        ),
        Radius.circular(r * 0.7),
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _RoundFamilyPainter oldDelegate) {
    return oldDelegate.family != family || oldDelegate.blocked != blocked;
  }
}

Path watchHexagon(Size size) {
  final center = Offset(size.width / 2, size.height / 2);
  final radius = math.min(size.width, size.height) / 2;
  final path = Path();
  for (var i = 0; i < 6; i++) {
    final angle = -math.pi / 2 + i * math.pi / 3;
    final point = Offset(
      center.dx + radius * math.cos(angle),
      center.dy + radius * math.sin(angle),
    );
    if (i == 0) {
      path.moveTo(point.dx, point.dy);
    } else {
      path.lineTo(point.dx, point.dy);
    }
  }
  return path..close();
}
