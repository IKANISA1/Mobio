// ignore_for_file: cascade_invocations

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
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

  factory VehicleTypeIcon.fromId({
    Key? key,
    required String vehicleTypeId,
    required double size,
    required Color color,
  }) {
    return VehicleTypeIcon(
      key: key,
      vehicleType: VehicleTypeModel(
        id: vehicleTypeId,
        label: vehicleTypeId,
        iconName: _fallbackIconName(vehicleTypeId),
      ),
      size: size,
      color: color,
    );
  }

  @override
  Widget build(BuildContext context) {
    final normalizedId = vehicleType.id.replaceAll('-', '_').toLowerCase();
    final svgAsset = switch (normalizedId) {
      'trike' => 'assets/icons/trike_cargo.svg',
      'private' || 'private_' => 'assets/icons/private_vehicle.svg',
      'rentals' => 'assets/icons/rental_vehicle.svg',
      _ => null,
    };

    if (svgAsset != null) {
      final semanticsLabel = switch (normalizedId) {
        'trike' => 'Cargo tricycle',
        'private' || 'private_' => 'Private vehicle',
        'rentals' => 'Rental vehicle',
        _ => 'Vehicle',
      };
      return SvgPicture.asset(
        svgAsset,
        width: size,
        height: size,
        colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
        semanticsLabel: semanticsLabel,
      );
    }

    final customPainter = switch (normalizedId) {
      'truck' => _CargoTruckIconPainter(color),
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

String _fallbackIconName(String vehicleTypeId) {
  return switch (vehicleTypeId.replaceAll('-', '_').toLowerCase()) {
    'moto' => 'bike',
    'bus' => 'bus',
    'cab' => 'car',
    'trike' => 'truck',
    'truck' => 'layout-grid',
    'private' || 'private_' => 'package',
    'rentals' => 'car',
    _ => 'car',
  };
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
