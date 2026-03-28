import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:mobi_app/core/theme/app_colors.dart';
import 'package:mobi_app/core/theme/app_typography.dart';
import 'package:mobi_app/core/theme/mobi_theme_extension.dart';
import 'package:mobi_app/features/biopay/services/face_detection_service.dart';
import 'package:mobi_app/features/biopay/widgets/oval_painter.dart';

class FaceEnrollmentCapture extends StatelessWidget {
  const FaceEnrollmentCapture({
    super.key,
    required this.controller,
    required this.state,
    required this.statusMessage,
    required this.sampleCount,
    required this.totalSamples,
    required this.stabilityProgress,
    required this.showCapturePulse,
    required this.ringPulse,
    this.qualityIssue,
    this.qualityMessage,
  });

  final CameraController controller;
  final ScannerState state;
  final String statusMessage;
  final int sampleCount;
  final int totalSamples;
  final double stabilityProgress;
  final bool showCapturePulse;
  final Animation<double> ringPulse;
  final FaceQualityIssue? qualityIssue;
  final String? qualityMessage;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<MobiThemeExtension>()!;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final previewHeight = _previewHeightFor(
          maxWidth: width,
          maxHeight: constraints.maxHeight,
        );
        final borderRadius = BorderRadius.circular(width >= 700 ? 34 : 28);
        final safeStability = stabilityProgress.clamp(0.0, 1.0).toDouble();
        final enrollmentProgress =
            ((sampleCount + safeStability) / totalSamples)
                .clamp(0.0, 1.0)
                .toDouble();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              decoration: BoxDecoration(
                borderRadius: borderRadius,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withValues(alpha: 0.08),
                    ext.surfaceContainerLow.withValues(alpha: 0.22),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.32),
                    blurRadius: 28,
                    offset: const Offset(0, 18),
                  ),
                  if (showCapturePulse)
                    BoxShadow(
                      color: AppColors.bioPayGreen.withValues(alpha: 0.34),
                      blurRadius: 24,
                      spreadRadius: 2,
                    ),
                ],
              ),
              child: ClipRRect(
                borderRadius: borderRadius,
                child: SizedBox(
                  height: previewHeight,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _ResponsiveCameraPreview(controller: controller),
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.black.withValues(alpha: 0.14),
                                Colors.transparent,
                                Colors.black.withValues(alpha: 0.26),
                              ],
                              stops: const [0, 0.45, 1],
                            ),
                          ),
                        ),
                      ),
                      AnimatedBuilder(
                        animation: ringPulse,
                        builder: (context, _) {
                          return CustomPaint(
                            painter: OvalPainter(
                              state: state,
                              progress: safeStability == 0
                                  ? 0.22
                                  : safeStability,
                              enrollmentProgress: enrollmentProgress,
                              sampleCount: sampleCount,
                              totalSamples: totalSamples,
                              pulse: ringPulse.value,
                            ),
                          );
                        },
                      ),
                      Positioned(
                        top: 18,
                        left: 18,
                        right: 18,
                        child: Align(
                          alignment: Alignment.topCenter,
                          child: _StatusChip(
                            state: state,
                            statusMessage: statusMessage,
                            sampleCount: sampleCount,
                            totalSamples: totalSamples,
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 20,
                        left: 20,
                        right: 20,
                        child: IgnorePointer(
                          ignoring: qualityMessage == null,
                          child: AnimatedSlide(
                            duration: const Duration(milliseconds: 240),
                            curve: Curves.easeOutCubic,
                            offset: qualityMessage == null
                                ? const Offset(0, 1.2)
                                : Offset.zero,
                            child: AnimatedOpacity(
                              duration: const Duration(milliseconds: 180),
                              opacity: qualityMessage == null ? 0 : 1,
                              child: _QualityToast(
                                message: qualityMessage,
                                issue: qualityIssue,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
            _SampleDots(
              sampleCount: sampleCount,
              totalSamples: totalSamples,
              stabilityProgress: safeStability,
            ),
            const SizedBox(height: 12),
            Text(
              _captionText,
              textAlign: TextAlign.center,
              style: AppTypography.bodyMd.copyWith(
                color: cs.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Automatic capture starts as soon as your face is centered and stable.',
              textAlign: TextAlign.center,
              style: AppTypography.bodySm.copyWith(
                color: cs.onSurfaceVariant.withValues(alpha: 0.88),
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: _PrivacyBadge(
                borderColor: cs.outlineVariant.withValues(alpha: 0.22),
              ),
            ),
          ],
        );
      },
    );
  }

  String get _captionText {
    if (sampleCount >= totalSamples) {
      return 'Secure capture complete';
    }
    if (state == ScannerState.locked) {
      return 'Hold still — $sampleCount of $totalSamples secured';
    }
    if (state == ScannerState.searching) {
      return 'Center your face inside the guide';
    }
    return 'Hold still — $sampleCount of $totalSamples secured';
  }

  double _previewHeightFor({
    required double maxWidth,
    required double maxHeight,
  }) {
    final suggested = maxWidth < 460 ? maxWidth * 1.18 : maxWidth * 0.92;
    final limitedByViewport = maxHeight * (maxWidth >= 720 ? 0.76 : 0.7);
    return math.max(320.0, math.min(suggested, limitedByViewport));
  }
}

class _ResponsiveCameraPreview extends StatelessWidget {
  const _ResponsiveCameraPreview({required this.controller});

  final CameraController controller;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final fittedHeight =
            constraints.maxWidth * controller.value.aspectRatio;
        final fittedWidth =
            constraints.maxHeight / controller.value.aspectRatio;

        return ClipRect(
          child: OverflowBox(
            alignment: Alignment.center,
            minWidth: constraints.maxWidth,
            minHeight: constraints.maxHeight,
            maxWidth: math.max(constraints.maxWidth, fittedWidth),
            maxHeight: math.max(constraints.maxHeight, fittedHeight),
            child: AspectRatio(
              aspectRatio: controller.value.aspectRatio,
              child: CameraPreview(controller),
            ),
          ),
        );
      },
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.state,
    required this.statusMessage,
    required this.sampleCount,
    required this.totalSamples,
  });

  final ScannerState state;
  final String statusMessage;
  final int sampleCount;
  final int totalSamples;

  @override
  Widget build(BuildContext context) {
    final (icon, color, label) = switch (state) {
      ScannerState.searching => (
        Icons.center_focus_strong_rounded,
        AppColors.secondaryFixed,
        'Align your face',
      ),
      ScannerState.locked => (
        Icons.lock_outline_rounded,
        AppColors.warning,
        sampleCount >= totalSamples
            ? 'Finalizing capture'
            : 'Face locked • ${sampleCount + 1}/$totalSamples',
      ),
      ScannerState.captured => (
        Icons.check_circle_outline_rounded,
        AppColors.bioPayGreen,
        'Capture complete',
      ),
      ScannerState.error => (
        Icons.warning_amber_rounded,
        AppColors.error,
        'Adjust and retry',
      ),
      ScannerState.noMatch => (
        Icons.error_outline_rounded,
        AppColors.error,
        statusMessage,
      ),
    };

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.58),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.18),
            blurRadius: 18,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 8),
            Text(
              label,
              style: AppTypography.labelMd.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QualityToast extends StatelessWidget {
  const _QualityToast({required this.message, required this.issue});

  final String? message;
  final FaceQualityIssue? issue;

  @override
  Widget build(BuildContext context) {
    if (message == null) {
      return const SizedBox.shrink();
    }

    final (icon, accent) = switch (issue) {
      FaceQualityIssue.lowLighting => (
        Icons.light_mode_outlined,
        AppColors.warning,
      ),
      FaceQualityIssue.tooBright => (Icons.sunny, AppColors.warning),
      FaceQualityIssue.faceTooSmall => (
        Icons.zoom_in_map_rounded,
        AppColors.warning,
      ),
      FaceQualityIssue.yawTooHigh => (
        Icons.threesixty_rounded,
        AppColors.warning,
      ),
      FaceQualityIssue.eyesClosed => (
        Icons.visibility_rounded,
        AppColors.warning,
      ),
      FaceQualityIssue.multipleFaces => (Icons.groups_rounded, AppColors.error),
      null => (Icons.info_outline_rounded, AppColors.warning),
    };

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withValues(alpha: 0.36)),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.22),
            blurRadius: 16,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: accent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message!,
                style: AppTypography.bodySm.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SampleDots extends StatelessWidget {
  const _SampleDots({
    required this.sampleCount,
    required this.totalSamples,
    required this.stabilityProgress,
  });

  final int sampleCount;
  final int totalSamples;
  final double stabilityProgress;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var index = 0; index < totalSamples; index++) ...[
          _SampleDot(
            isCaptured: index < sampleCount,
            isCurrent: index == sampleCount && sampleCount < totalSamples,
            stabilityProgress: index == sampleCount ? stabilityProgress : 0,
          ),
          if (index != totalSamples - 1) const SizedBox(width: 10),
        ],
      ],
    );
  }
}

class _SampleDot extends StatelessWidget {
  const _SampleDot({
    required this.isCaptured,
    required this.isCurrent,
    required this.stabilityProgress,
  });

  final bool isCaptured;
  final bool isCurrent;
  final double stabilityProgress;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final currentFill = isCurrent
        ? stabilityProgress.clamp(0.0, 1.0).toDouble()
        : 0.0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isCaptured
            ? AppColors.bioPayGreen
            : isCurrent
            ? AppColors.warning.withValues(alpha: 0.16 + (currentFill * 0.22))
            : Colors.white.withValues(alpha: 0.08),
        border: Border.all(
          color: isCaptured
              ? AppColors.bioPayGreen
              : isCurrent
              ? AppColors.warning.withValues(alpha: 0.8)
              : cs.outlineVariant.withValues(alpha: 0.28),
        ),
        boxShadow: [
          if (isCaptured)
            BoxShadow(
              color: AppColors.bioPayGreen.withValues(alpha: 0.3),
              blurRadius: 12,
              spreadRadius: 1,
            ),
        ],
      ),
      child: Center(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          switchInCurve: Curves.easeOutBack,
          switchOutCurve: Curves.easeIn,
          child: isCaptured
              ? const Icon(
                  Icons.check_rounded,
                  key: ValueKey('captured'),
                  size: 12,
                  color: Colors.white,
                )
              : isCurrent
              ? Container(
                  key: const ValueKey('current'),
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.warning.withValues(
                      alpha: 0.45 + (currentFill * 0.35),
                    ),
                  ),
                )
              : const SizedBox.shrink(key: ValueKey('empty')),
        ),
      ),
    );
  }
}

class _PrivacyBadge extends StatelessWidget {
  const _PrivacyBadge({required this.borderColor});

  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: borderColor),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.lock_outline_rounded,
              size: 14,
              color: AppColors.bioPayGreen,
            ),
            const SizedBox(width: 8),
            Text(
              'No photos saved',
              style: AppTypography.labelMd.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
