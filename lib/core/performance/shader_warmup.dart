import 'package:flutter/material.dart';

/// Warms critical shaders before the first frame to prevent jank.
///
/// This renders the main gradient + rounded rect patterns used by
/// the Claymorphic UI system off-screen so that the GPU compiles
/// the necessary shaders during the splash screen period.
class MobiShaderWarmUp extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Warm up the primary gradient brush
    final gradient = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF6BEDB5), Color(0xFF3B9E7C)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), gradient);

    // Warm up rounded rect clipping (used by GlassCard, ClayCard)
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width * 0.6, size.height * 0.4),
      const Radius.circular(40),
    );
    canvas.drawRRect(rrect, gradient);

    // Warm up shadow shader
    final shadow = Paint()
      ..color = const Color(0x1A000000)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20);
    canvas.drawRRect(rrect, shadow);

    // Warm up circular clipping (used by profile avatars, nav items)
    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      40,
      gradient,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Widget that renders the warmup painter exactly once, invisibly.
/// Add to the widget tree during splash to pre-compile shaders.
class ShaderWarmUpWidget extends StatelessWidget {
  const ShaderWarmUpWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: 0.0,
      child: RepaintBoundary(
        child: CustomPaint(
          painter: MobiShaderWarmUp(),
          size: const Size(200, 200),
        ),
      ),
    );
  }
}
