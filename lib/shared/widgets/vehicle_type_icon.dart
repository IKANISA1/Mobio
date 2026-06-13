// ignore_for_file: cascade_invocations

import 'package:flutter/material.dart';
import 'package:mobi_app/models/vehicle_type_model.dart';

class VehicleTypeIcon extends StatelessWidget {
  const VehicleTypeIcon({
    super.key,
    required this.vehicleType,
    required this.size,
    required this.color,
  });

  final VehicleTypeModel vehicleType;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final normalizedId = vehicleType.id.replaceAll('-', '_').toLowerCase();
    final customPainter = switch (normalizedId) {
      'trike' => _TrikeIconPainter(color),
      'truck' => _CargoTruckIconPainter(color),
      'private' || 'private_' => _OtherVehicleIconPainter(color),
      _ => null,
    };

    if (customPainter != null) {
      return SizedBox.square(
        dimension: size,
        child: CustomPaint(painter: customPainter),
      );
    }

    return Icon(vehicleType.icon, size: size, color: color);
  }
}

abstract class _VehicleLineIconPainter extends CustomPainter {
  _VehicleLineIconPainter(this.color);

  final Color color;

  Paint get _stroke => Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.2
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  @override
  bool shouldRepaint(covariant _VehicleLineIconPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class _TrikeIconPainter extends _VehicleLineIconPainter {
  _TrikeIconPainter(super.color);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    canvas.save();
    canvas.translate((size.width - s) / 2, (size.height - s) / 2);
    canvas.scale(s / 24);

    final stroke = _stroke;
    canvas.drawCircle(const Offset(6, 18), 2.2, stroke);
    canvas.drawCircle(const Offset(18, 18), 2.2, stroke);
    canvas.drawCircle(const Offset(16, 9), 1.8, stroke);
    canvas.drawPath(
      Path()
        ..moveTo(6, 18)
        ..lineTo(10, 12)
        ..lineTo(15, 18)
        ..lineTo(18, 18)
        ..moveTo(10, 12)
        ..lineTo(16, 9)
        ..lineTo(19, 7)
        ..moveTo(14, 11)
        ..lineTo(13, 15)
        ..lineTo(9, 15),
      stroke,
    );

    canvas.restore();
  }
}

class _CargoTruckIconPainter extends _VehicleLineIconPainter {
  _CargoTruckIconPainter(super.color);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    canvas.save();
    canvas.translate((size.width - s) / 2, (size.height - s) / 2);
    canvas.scale(s / 24);

    final stroke = _stroke;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(3, 8, 10, 7),
        const Radius.circular(1.8),
      ),
      stroke,
    );
    canvas.drawPath(
      Path()
        ..moveTo(13, 11)
        ..lineTo(17, 11)
        ..lineTo(21, 15)
        ..lineTo(21, 17)
        ..lineTo(19, 17)
        ..moveTo(13, 17)
        ..lineTo(9, 17)
        ..moveTo(5, 17)
        ..lineTo(3, 17)
        ..moveTo(16, 13)
        ..lineTo(18, 15)
        ..lineTo(13, 15),
      stroke,
    );
    canvas.drawCircle(const Offset(7, 17), 2.1, stroke);
    canvas.drawCircle(const Offset(17, 17), 2.1, stroke);

    canvas.restore();
  }
}

class _OtherVehicleIconPainter extends _VehicleLineIconPainter {
  _OtherVehicleIconPainter(super.color);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    canvas.save();
    canvas.translate((size.width - s) / 2, (size.height - s) / 2);
    canvas.scale(s / 24);

    final stroke = _stroke;
    canvas.drawPath(
      Path()
        ..moveTo(12, 3)
        ..lineTo(20, 7.5)
        ..lineTo(20, 16.5)
        ..lineTo(12, 21)
        ..lineTo(4, 16.5)
        ..lineTo(4, 7.5)
        ..close()
        ..moveTo(4.5, 7.8)
        ..lineTo(12, 12)
        ..lineTo(19.5, 7.8)
        ..moveTo(12, 12)
        ..lineTo(12, 20.5),
      stroke,
    );

    canvas.restore();
  }
}
