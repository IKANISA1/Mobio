import 'package:flutter/material.dart';

/// WhatsApp SVG icon as a Flutter widget.
class WhatsAppIcon extends StatelessWidget {
  final double size;
  final Color color;

  const WhatsAppIcon({
    super.key,
    this.size = 24,
    this.color = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _WhatsAppPainter(color: color),
    );
  }
}

class _WhatsAppPainter extends CustomPainter {
  final Color color;
  _WhatsAppPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final scale = size.width / 24;
    canvas.scale(scale, scale);

    final path = Path()
      ..moveTo(17.472, 14.382)
      ..cubicTo(17.175, 14.233, 15.714, 13.515, 15.442, 13.415)
      ..cubicTo(15.169, 13.316, 14.971, 13.267, 14.772, 13.565)
      ..cubicTo(14.575, 13.862, 14.005, 14.531, 13.832, 14.729)
      ..cubicTo(13.659, 14.928, 13.485, 14.952, 13.188, 14.804)
      ..cubicTo(12.891, 14.654, 11.933, 14.341, 10.798, 13.329)
      ..cubicTo(9.915, 12.541, 9.318, 11.568, 9.145, 11.27)
      ..cubicTo(8.972, 10.973, 9.127, 10.812, 9.275, 10.664)
      ..cubicTo(9.409, 10.531, 9.573, 10.317, 9.721, 10.144)
      ..cubicTo(9.87, 9.97, 9.919, 9.846, 10.019, 9.647)
      ..cubicTo(10.118, 9.449, 10.069, 9.276, 9.994, 9.127)
      ..cubicTo(9.919, 8.978, 9.325, 7.515, 9.078, 6.92)
      ..cubicTo(8.836, 6.341, 8.591, 6.42, 8.409, 6.41)
      ..cubicTo(8.236, 6.402, 8.038, 6.4, 7.839, 6.4)
      ..cubicTo(7.641, 6.4, 7.319, 6.474, 7.047, 6.772)
      ..cubicTo(6.775, 7.069, 6.007, 7.788, 6.007, 9.251)
      ..cubicTo(6.007, 10.713, 7.072, 12.126, 7.22, 12.325)
      ..cubicTo(7.369, 12.523, 9.316, 15.525, 12.297, 16.812)
      ..cubicTo(13.006, 17.118, 13.559, 17.301, 13.991, 17.437)
      ..cubicTo(14.703, 17.664, 15.351, 17.632, 15.862, 17.555)
      ..cubicTo(16.433, 17.47, 17.62, 16.836, 17.868, 16.142)
      ..cubicTo(18.116, 15.448, 18.116, 14.853, 18.041, 14.729)
      ..cubicTo(17.967, 14.605, 17.769, 14.531, 17.472, 14.382);

    path.moveTo(12.051, 21.785);
    path.lineTo(12.047, 21.785);
    path.cubicTo(10.247, 21.786, 8.481, 21.317, 6.916, 20.407);
    path.lineTo(6.555, 20.193);
    path.lineTo(2.814, 21.175);
    path.lineTo(3.812, 17.527);
    path.lineTo(3.577, 17.153);
    path.cubicTo(2.577, 15.356, 2.067, 13.313, 2.082, 11.893);
    path.cubicTo(2.083, 6.443, 6.518, 2.009, 11.97, 2.009);
    path.cubicTo(14.61, 2.009, 17.092, 3.039, 18.958, 4.907);
    path.cubicTo(20.824, 6.775, 21.863, 9.206, 21.851, 11.901);
    path.cubicTo(21.848, 17.351, 17.414, 21.785, 12.051, 21.785);

    path.moveTo(20.464, 3.488);
    path.cubicTo(18.224, 1.246, 15.218, 0, 12.05, 0);
    path.cubicTo(5.414, 0, 0.018, 5.396, 0.015, 12.03);
    path.cubicTo(0.015, 14.15, 0.569, 16.219, 1.617, 18.09);
    path.lineTo(0, 24);
    path.lineTo(6.117, 22.395);
    path.cubicTo(7.899, 23.362, 9.902, 23.871, 11.942, 23.972);
    path.lineTo(11.947, 23.972);
    path.cubicTo(18.579, 23.972, 23.979, 18.576, 23.982, 11.941);
    path.cubicTo(23.985, 8.723, 22.73, 5.699, 20.464, 3.488);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
