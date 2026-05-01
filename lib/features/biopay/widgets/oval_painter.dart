import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:mobi_app/core/theme/app_colors.dart';
import 'package:mobi_app/features/biopay/models/biopay_models.dart';

class OvalPainter extends CustomPainter {
  OvalPainter({
    required this.state,
    this.progress = 1.0,
    this.enrollmentProgress = 0.0,
    this.sampleCount = 0,
    this.totalSamples = 5,
    this.pulse = 0.0,
  });

  final ScannerState state;
  final double progress;
  final double enrollmentProgress;
  final int sampleCount;
  final int totalSamples;
  final double pulse;

  @override
  void paint(Canvas canvas, Size size) {
    final ovalWidth = size.width * 0.68;
    final ovalHeight = size.height * 0.56;
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
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withValues(alpha: 0.62),
            Colors.black.withValues(alpha: 0.78),
          ],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
        ..style = PaintingStyle.fill,
    );

    final pulseValue = Curves.easeInOut.transform(
      pulse.clamp(0.0, 1.0).toDouble(),
    );
    final guidedProgress = progress.clamp(0.0, 1.0).toDouble();
    final emptyPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.white.withValues(alpha: 0.12),
          Colors.white.withValues(alpha: 0.04),
        ],
      ).createShader(ovalRect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    final completedPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          AppColors.bioPayGreen.withValues(alpha: 0.98),
          AppColors.primary.withValues(alpha: 0.92),
        ],
      ).createShader(ovalRect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.5
      ..strokeCap = StrokeCap.round;

    final currentPaint = Paint()
      ..shader = LinearGradient(
        colors: _stateStrokeGradient
            .map((color) {
              final extraAlpha =
                  state == ScannerState.locked || state == ScannerState.captured
                  ? 0.6 + (guidedProgress * 0.18) + (pulseValue * 0.22)
                  : 0.54 + (guidedProgress * 0.24);
              return color.withValues(alpha: extraAlpha);
            })
            .toList(growable: false),
      ).createShader(ovalRect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.5
      ..strokeCap = StrokeCap.round;

    final total = totalSamples <= 0 ? 1 : totalSamples;
    const gapSweep = 0.18;
    final availableSweep = (math.pi * 2) - (gapSweep * total);
    final segmentSweep = availableSweep / total;
    final filledSegments =
        (enrollmentProgress.clamp(0.0, 1.0).toDouble() * total)
            .clamp(0.0, total.toDouble())
            .toDouble();

    for (var index = 0; index < total; index++) {
      final startAngle = (-math.pi / 2) + (index * (segmentSweep + gapSweep));
      canvas.drawArc(ovalRect, startAngle, segmentSweep, false, emptyPaint);

      final fillFraction = (filledSegments - index).clamp(0.0, 1.0);
      if (fillFraction <= 0) continue;

      final fillPaint = index < sampleCount ? completedPaint : currentPaint;
      canvas.drawArc(
        ovalRect,
        startAngle,
        segmentSweep * fillFraction,
        false,
        fillPaint,
      );
    }

    final guidePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawOval(ovalRect, guidePaint);

    if (state == ScannerState.locked || state == ScannerState.captured) {
      final glowPaint = Paint()
        ..shader = RadialGradient(
          colors: [
            _glowColor.withValues(
              alpha: 0.06 + (guidedProgress * 0.08) + (pulseValue * 0.14),
            ),
            _glowColor.withValues(alpha: 0.02),
            Colors.transparent,
          ],
        ).createShader(ovalRect.inflate(28))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 18
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14);
      canvas.drawOval(ovalRect.inflate(8), glowPaint);
    }

    _drawMarkers(canvas, ovalRect);
  }

  List<Color> get _stateStrokeGradient => switch (state) {
    ScannerState.searching => [AppColors.secondaryFixed, AppColors.warning],
    ScannerState.locked => [AppColors.warning, AppColors.primary],
    ScannerState.captured => [AppColors.bioPayGreen, AppColors.primary],
    ScannerState.error ||
    ScannerState.noMatch => [AppColors.error, AppColors.redAccent],
  };

  Color get _glowColor => switch (state) {
    ScannerState.searching => AppColors.secondaryFixed,
    ScannerState.locked => AppColors.warning,
    ScannerState.captured => AppColors.bioPayGreen,
    ScannerState.error || ScannerState.noMatch => AppColors.error,
  };

  void _drawMarkers(Canvas canvas, Rect ovalRect) {
    final markerPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.58)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    const markerLength = 18.0;
    const markerInset = 6.0;

    canvas
      ..drawLine(
        Offset(ovalRect.center.dx, ovalRect.top - markerInset),
        Offset(ovalRect.center.dx, ovalRect.top + markerLength - markerInset),
        markerPaint,
      )
      ..drawLine(
        Offset(
          ovalRect.center.dx,
          ovalRect.bottom - markerLength + markerInset,
        ),
        Offset(ovalRect.center.dx, ovalRect.bottom + markerInset),
        markerPaint,
      )
      ..drawLine(
        Offset(ovalRect.left - markerInset, ovalRect.center.dy),
        Offset(ovalRect.left + markerLength - markerInset, ovalRect.center.dy),
        markerPaint,
      )
      ..drawLine(
        Offset(ovalRect.right - markerLength + markerInset, ovalRect.center.dy),
        Offset(ovalRect.right + markerInset, ovalRect.center.dy),
        markerPaint,
      );
  }

  @override
  bool shouldRepaint(OvalPainter oldDelegate) {
    return oldDelegate.state != state ||
        oldDelegate.progress != progress ||
        oldDelegate.enrollmentProgress != enrollmentProgress ||
        oldDelegate.sampleCount != sampleCount ||
        oldDelegate.totalSamples != totalSamples ||
        oldDelegate.pulse != pulse;
  }
}
