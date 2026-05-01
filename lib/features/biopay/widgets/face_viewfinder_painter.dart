import 'package:flutter/material.dart';

class FaceViewfinderPainter extends CustomPainter {
  final double viewfinderFraction;
  final Color overlayColor;
  final Color borderColor;
  final double borderWidth;
  final double cornerLength;
  final double borderRadius;

  FaceViewfinderPainter({
    required this.viewfinderFraction,
    required this.overlayColor,
    required this.borderColor,
    required this.borderWidth,
    required this.cornerLength,
    required this.borderRadius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final viewfinderWidth = size.width * viewfinderFraction;
    final viewfinderHeight = size.height * 0.65;
    final left = (size.width - viewfinderWidth) / 2;
    final top = (size.height - viewfinderHeight) / 2;
    final rect = Rect.fromLTWH(left, top, viewfinderWidth, viewfinderHeight);
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(borderRadius));

    // Semi-transparent overlay with hole
    final overlayPaint = Paint()..color = overlayColor;
    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(rrect)
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(path, overlayPaint);

    // Corner brackets
    final cornerPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth
      ..strokeCap = StrokeCap.round;

    final right = left + viewfinderWidth;
    final bottom = top + viewfinderHeight;
    final r = borderRadius;
    final cl = cornerLength;

    canvas
      // Top-left
      ..drawLine(Offset(left, top + cl), Offset(left, top + r), cornerPaint)
      ..drawArc(
        Rect.fromLTWH(left, top, r * 2, r * 2),
        3.14159,
        1.5708,
        false,
        cornerPaint,
      )
      ..drawLine(Offset(left + r, top), Offset(left + cl, top), cornerPaint)
      // Top-right
      ..drawLine(Offset(right - cl, top), Offset(right - r, top), cornerPaint)
      ..drawArc(
        Rect.fromLTWH(right - r * 2, top, r * 2, r * 2),
        -1.5708,
        1.5708,
        false,
        cornerPaint,
      )
      ..drawLine(Offset(right, top + r), Offset(right, top + cl), cornerPaint)
      // Bottom-left
      ..drawLine(
        Offset(left, bottom - cl),
        Offset(left, bottom - r),
        cornerPaint,
      )
      ..drawArc(
        Rect.fromLTWH(left, bottom - r * 2, r * 2, r * 2),
        1.5708,
        1.5708,
        false,
        cornerPaint,
      )
      ..drawLine(
        Offset(left + r, bottom),
        Offset(left + cl, bottom),
        cornerPaint,
      )
      // Bottom-right
      ..drawLine(
        Offset(right - cl, bottom),
        Offset(right - r, bottom),
        cornerPaint,
      )
      ..drawArc(
        Rect.fromLTWH(right - r * 2, bottom - r * 2, r * 2, r * 2),
        0,
        1.5708,
        false,
        cornerPaint,
      )
      ..drawLine(
        Offset(right, bottom - r),
        Offset(right, bottom - cl),
        cornerPaint,
      );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
