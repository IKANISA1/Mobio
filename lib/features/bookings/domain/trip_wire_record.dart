import 'package:mobi_shared_types/models/trip.dart';

/// Validates a scheduled trip row before the UI model's legacy defaults apply.
abstract final class TripWireRecord {
  static final RegExp _uuid = RegExp(
    r'^[0-9a-fA-F]{8}(-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}$',
  );
  static final RegExp _date = RegExp(r'^\d{4}-\d{2}-\d{2}$');
  static const _roles = {'driver', 'passenger'};
  static const _vehicleTypes = {
    'cab',
    'moto',
    'bus',
    'trike',
    'truck',
    'private',
    'rentals',
  };
  static const _statuses = {
    'active',
    'cancelled',
    'approved',
    'pending',
    'suspended',
    'blocked',
  };

  static String requireId(Object? value) {
    if (value is! String || !_uuid.hasMatch(value)) {
      throw const FormatException('Invalid trip RPC ID');
    }
    return value;
  }

  static Trip parse(Map<String, dynamic> row, {bool redactWhatsApp = true}) {
    requireId(row['id']);
    requireId(row['author_id']);
    final origin = row['origin'];
    final destination = row['destination'];
    final departureDate = row['departure_date'];
    final departureTime = row['departure_time'];
    final role = row['role'];
    final vehicleType = row['vehicle_type'];
    final status = row['status'];
    final isActive = row['is_active'];
    final parsedDate = departureDate is String
        ? DateTime.tryParse(departureDate)
        : null;
    if (origin is! String ||
        origin.trim().isEmpty ||
        destination is! String ||
        destination.trim().isEmpty ||
        departureDate is! String ||
        !_date.hasMatch(departureDate) ||
        parsedDate == null ||
        parsedDate.toIso8601String().substring(0, 10) != departureDate ||
        departureTime is! String ||
        departureTime.trim().isEmpty ||
        role is! String ||
        !_roles.contains(role) ||
        vehicleType is! String ||
        !_vehicleTypes.contains(vehicleType) ||
        status is! String ||
        !_statuses.contains(status) ||
        isActive is! bool) {
      throw const FormatException('Invalid scheduled trip RPC row');
    }
    final safe = Map<String, dynamic>.from(row);
    if (redactWhatsApp) safe['whatsapp'] = '';
    return Trip.fromJson(safe);
  }
}
