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
