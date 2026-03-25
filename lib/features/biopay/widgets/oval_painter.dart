import 'package:flutter/material.dart';
import 'package:mobi_app/core/theme/app_colors.dart';

class OvalPainter extends CustomPainter {
  OvalPainter({required this.state, this.progress = 1.0});

  final ScannerState state;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final ovalWidth = size.width * 0.65;
    final ovalHeight = size.height * 0.55;
    final ovalRect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height * 0.42),
      width: ovalWidth,
      height: ovalHeight,
    );

    final overlayPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addOval(ovalRect)
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(
      overlayPath,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.72)
        ..style = PaintingStyle.fill,
    );

    final borderColor = switch (state) {
      ScannerState.searching => AppColors.secondary,
      ScannerState.locked => AppColors.primary,
      ScannerState.captured => AppColors.primary,
      ScannerState.error => AppColors.error,
      ScannerState.noMatch => AppColors.error,
    };

    final borderPaint = Paint()
      ..color = borderColor.withValues(alpha: 0.9 * progress)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    canvas.drawOval(ovalRect, borderPaint);

    if (state == ScannerState.locked || state == ScannerState.captured) {
      final glowPaint = Paint()
        ..color = borderColor.withValues(alpha: 0.18 * progress)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      canvas.drawOval(ovalRect, glowPaint);
    }
  }

  @override
  bool shouldRepaint(OvalPainter oldDelegate) {
    return oldDelegate.state != state || oldDelegate.progress != progress;
  }
}

enum ScannerState { searching, locked, captured, error, noMatch }
