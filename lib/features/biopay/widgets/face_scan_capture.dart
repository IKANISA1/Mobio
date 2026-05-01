import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:mobi_app/features/biopay/models/biopay_models.dart';
import 'package:mobi_app/features/biopay/widgets/oval_painter.dart';

class FaceScanCapture extends StatelessWidget {
  const FaceScanCapture({
    super.key,
    required this.controller,
    required this.statusMessage,
    required this.stabilityProgress,
    this.qualityIssue,
  });

  final CameraController controller;
  final String statusMessage;
  final double stabilityProgress;
  final FaceQualityIssue? qualityIssue;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final scale = 1 / (controller.value.aspectRatio * size.aspectRatio);

    final scannerState = qualityIssue != null
        ? ScannerState.error
        : (stabilityProgress >= 1.0 ? ScannerState.locked : ScannerState.searching);

    return ClipRRect(
      borderRadius: BorderRadius.circular(32),
      child: AspectRect(
        aspectRatio: 3 / 4,
        child: Stack(
          alignment: Alignment.center,
          fit: StackFit.expand,
          children: [
            Transform.scale(
              scale: scale,
              child: Center(child: CameraPreview(controller)),
            ),
            CustomPaint(
              painter: OvalPainter(
                state: scannerState,
                progress: stabilityProgress,
              ),
            ),
            Positioned(
              bottom: 32,
              left: 24,
              right: 24,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  statusMessage,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AspectRect extends StatelessWidget {
  const AspectRect({
    super.key,
    required this.aspectRatio,
    required this.child,
  });

  final double aspectRatio;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = width / aspectRatio;
        return SizedBox(
          width: width,
          height: height,
          child: child,
        );
      },
    );
  }
}
