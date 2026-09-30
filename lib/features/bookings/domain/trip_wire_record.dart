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
    final isRecurring = row['is_recurring'];
    final recurringDays = row['recurring_days'];
    final skipDates = row['recurrence_skip_dates'];
    final endDate = row['recurrence_end_date'];
    if (isRecurring is! bool ||
        recurringDays is! List ||
        recurringDays.any((day) => day is! int || day < 0 || day > 6) ||
        recurringDays.toSet().length != recurringDays.length ||
        (isRecurring && recurringDays.isEmpty) ||
        skipDates is! List ||
        skipDates.any((date) => !_validDate(date)) ||
        (endDate != null && !_validDate(endDate))) {
      throw const FormatException('Invalid scheduled trip recurrence');
    }
    if (endDate is String && endDate.compareTo(departureDate) < 0) {
      throw const FormatException('Invalid scheduled trip repeat window');
    }
    for (final key in ['origin_lat', 'dest_lat']) {
      _optionalCoordinate(row[key], minimum: -90, maximum: 90);
    }
    for (final key in ['origin_lng', 'dest_lng']) {
      _optionalCoordinate(row[key], minimum: -180, maximum: 180);
    }
    final safe = Map<String, dynamic>.from(row);
    if (redactWhatsApp) safe['whatsapp'] = '';
    return Trip.fromJson(safe);
  }

  static bool _validDate(Object? value) {
    if (value is! String || !_date.hasMatch(value)) return false;
    final parsed = DateTime.tryParse(value);
    return parsed != null && parsed.toIso8601String().substring(0, 10) == value;
  }

  static void _optionalCoordinate(
    Object? value, {
    required double minimum,
    required double maximum,
  }) {
    if (value == null) return;
    if (value is! num ||
        !value.toDouble().isFinite ||
        value < minimum ||
        value > maximum) {
      throw const FormatException('Invalid scheduled trip coordinate');
    }
  }

  /// This RPC returns one matching occurrence, rather than the original
  /// recurrence definition. Its SQL explicitly restricts active posts.
  static Trip parsePoolOccurrence(Map<String, dynamic> row) {
    final score = row['score'];
    final reason = row['reason'];
    if (score is! num ||
        !score.toDouble().isFinite ||
        reason is! String ||
        reason.trim().isEmpty) {
      throw const FormatException('Invalid pool occurrence response');
    }
    return parse({
      ...row,
      'id': requireId(row['trip_id']),
      'status': 'active',
      'is_active': true,
      'is_recurring': false,
      'recurring_days': <int>[],
      'recurrence_end_date': null,
      'recurrence_skip_dates': <String>[],
    });
  }
}
