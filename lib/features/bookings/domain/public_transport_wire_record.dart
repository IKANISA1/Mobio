import 'package:mobi_shared_types/models/public_transport.dart';

/// Validates the authoritative table/RPC shape before constructing display
/// models, whose defaults also support local preview fixtures.
abstract final class PublicTransportWireRecord {
  static List<Map<String, dynamic>> rows(Object? raw) {
    if (raw is! List) throw const FormatException('Invalid transport list');
    return raw
        .map((row) {
          if (row is! Map) throw const FormatException('Invalid transport row');
          return Map<String, dynamic>.from(row);
        })
        .toList(growable: false);
  }

  static Map<String, dynamic> single(Object? raw) {
    final result = rows(raw);
    if (result.length != 1)
      throw const FormatException('Expected one transport result');
    return result.single;
  }

  static TransportAgency agency(Map<String, dynamic> row) {
    for (final key in ['id', 'name', 'slug', 'service_area']) {
      _text(row, key);
    }
    if (row['is_active'] is! bool)
      throw const FormatException('Invalid agency activation state');
    _time(row, 'created_at');
    _time(row, 'updated_at');
    return TransportAgency.fromJson(row);
  }

  static PublicTransportSchedule schedule(Map<String, dynamic> row) {
    for (final key in [
      'schedule_id',
      'agency_id',
      'agency_name',
      'route_id',
      'route_code',
      'origin_name',
      'destination_name',
      'currency',
    ]) {
      _text(row, key);
    }
    _time(row, 'departure_at');
    _time(row, 'arrival_window_start', optional: true);
    _time(row, 'arrival_window_end', optional: true);
    _money(row, 'fare_amount');
    _count(row, 'available_seats');
    _state(row, 'status', {'scheduled', 'boarding'});
    return PublicTransportSchedule.fromJson(row);
  }

  static BusSeatHold hold(Map<String, dynamic> row) {
    _booking(row);
    _time(row, 'hold_expires_at');
    return BusSeatHold.fromJson(row);
  }

  static BusBookingConfirmation confirmation(
    Map<String, dynamic> row, {
    required String bookingId,
  }) {
    _booking(row);
    if (row['booking_id'] != bookingId)
      throw const FormatException('Booking identity mismatch');
    return BusBookingConfirmation.fromJson(row);
  }

  static BusPaymentStatus paymentStatus(
    Map<String, dynamic> row, {
    required String bookingId,
  }) {
    if (_text(row, 'booking_id') != bookingId)
      throw const FormatException('Booking identity mismatch');
    _state(row, 'booking_status', _bookingStates);
    _state(row, 'payment_status', _paymentStates);
    _money(row, 'amount');
    _text(row, 'currency');
    _time(row, 'updated_at');
    return BusPaymentStatus.fromJson(row);
  }

  static const _bookingStates = {'held', 'confirmed', 'cancelled', 'expired'};
  static const _paymentStates = {
    'pending',
    'paid',
    'failed',
    'refunded',
    'refund_pending',
  };

  static void _booking(Map<String, dynamic> row) {
    _text(row, 'booking_id');
    _text(row, 'ticket_reference');
    _state(row, 'status', _bookingStates);
    _state(row, 'payment_status', _paymentStates);
    _money(row, 'amount');
    _text(row, 'currency');
  }

  static String _text(Map<String, dynamic> row, String key) {
    final value = row[key];
    if (value is! String || value.trim().isEmpty)
      throw FormatException('Invalid transport $key');
    return value;
  }

  static void _state(
    Map<String, dynamic> row,
    String key,
    Set<String> allowed,
  ) {
    if (!allowed.contains(row[key]))
      throw FormatException('Invalid transport $key');
  }

  static void _count(Map<String, dynamic> row, String key) {
    final value = row[key];
    if (value is! int || value < 0)
      throw FormatException('Invalid transport $key');
  }

  static void _money(Map<String, dynamic> row, String key) {
    final value = row[key];
    if (value is! num || !value.toDouble().isFinite || value < 0)
      throw FormatException('Invalid transport $key');
  }

  static void _time(
    Map<String, dynamic> row,
    String key, {
    bool optional = false,
  }) {
    final value = row[key];
    if (optional && value == null) return;
    if (value is! String ||
        !RegExp(r'(Z|[+-]\d{2}:\d{2})$').hasMatch(value) ||
        DateTime.tryParse(value) == null)
      throw FormatException('Invalid transport $key');
  }
}
