import 'package:mobi_app/core/errors/app_exception.dart';
import 'package:mobi_app/core/errors/app_exception_mapper.dart';
import 'package:mobi_app/models/public_transport.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthException;

class PublicTransportService {
  PublicTransportService({SupabaseClient? supabase})
    : _supabase = supabase ?? Supabase.instance.client;

  final SupabaseClient _supabase;
  static const _networkTimeout = Duration(seconds: 15);

  Future<List<PublicTransportSchedule>> searchSchedules({
    String? originSearch,
    String? destinationSearch,
    DateTime? departureDate,
    String? agencyId,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final rows = await _supabase
          .rpc(
            'rpc_search_bus_schedules',
            params: {
              'p_origin_search': originSearch,
              'p_destination_search': destinationSearch,
              'p_departure_date': departureDate == null
                  ? null
                  : _dateOnly(departureDate),
              'p_agency_id': agencyId,
              'p_limit': limit,
              'p_offset': offset,
            },
          )
          .timeout(_networkTimeout);

      return (rows as List<dynamic>)
          .map(
            (row) => PublicTransportSchedule.fromJson(
              Map<String, dynamic>.from(row as Map),
            ),
          )
          .toList();
    } on AppException {
      rethrow;
    } on Object catch (error, stackTrace) {
      throw AppExceptionMapper.mapAndLog(
        error,
        stackTrace,
        'Error searching bus schedules',
      );
    }
  }

  Future<BusSeatHold> holdSeats(BusSeatHoldRequest request) async {
    try {
      final rows = await _supabase
          .rpc(
            'rpc_hold_bus_seats',
            params: {
              'p_schedule_id': request.scheduleId,
              'p_seat_count': request.seatCount,
              'p_seat_numbers': request.seatNumbers,
              'p_passenger_name': request.passengerName,
              'p_passenger_phone': request.passengerPhone,
            },
          )
          .timeout(_networkTimeout);

      return BusSeatHold.fromJson(_firstRpcRow(rows as Object));
    } on AppException {
      rethrow;
    } on Object catch (error, stackTrace) {
      throw AppExceptionMapper.mapAndLog(
        error,
        stackTrace,
        'Error holding bus seats',
      );
    }
  }

  Future<BusBookingConfirmation> confirmBooking({
    required String bookingId,
    required String paymentProvider,
    required String providerReference,
    Map<String, dynamic> metadata = const {},
  }) async {
    try {
      final rows = await _supabase
          .rpc(
            'rpc_confirm_bus_booking',
            params: {
              'p_booking_id': bookingId,
              'p_payment_provider': paymentProvider,
              'p_provider_reference': providerReference,
              'p_metadata': metadata,
            },
          )
          .timeout(_networkTimeout);

      return BusBookingConfirmation.fromJson(_firstRpcRow(rows as Object));
    } on AppException {
      rethrow;
    } on Object catch (error, stackTrace) {
      throw AppExceptionMapper.mapAndLog(
        error,
        stackTrace,
        'Error confirming bus booking',
      );
    }
  }

  Future<void> cancelBooking(String bookingId) async {
    try {
      await _supabase
          .rpc('rpc_cancel_bus_booking', params: {'p_booking_id': bookingId})
          .timeout(_networkTimeout);
    } on AppException {
      rethrow;
    } on Object catch (error, stackTrace) {
      throw AppExceptionMapper.mapAndLog(
        error,
        stackTrace,
        'Error cancelling bus booking',
      );
    }
  }

  Future<BusPaymentStatus?> getPaymentStatus(String bookingId) async {
    try {
      final rows = await _supabase
          .rpc(
            'rpc_get_bus_payment_status',
            params: {'p_booking_id': bookingId},
          )
          .timeout(_networkTimeout);

      final list = rows as List<dynamic>;
      if (list.isEmpty) return null;
      return BusPaymentStatus.fromJson(
        Map<String, dynamic>.from(list.first as Map),
      );
    } on AppException {
      rethrow;
    } on Object catch (error, stackTrace) {
      throw AppExceptionMapper.mapAndLog(
        error,
        stackTrace,
        'Error loading bus payment status',
      );
    }
  }

  Future<String> ingestBusLocation(BusLocationIngestRequest request) async {
    try {
      final eventId = await _supabase
          .rpc(
            'rpc_ingest_bus_location',
            params: {
              'p_bus_id': request.busId,
              'p_latitude': request.latitude,
              'p_longitude': request.longitude,
              'p_heading_degrees': request.headingDegrees,
              'p_speed_kph': request.speedKph,
              'p_accuracy_meters': request.accuracyMeters,
              'p_tracking_source_id': request.trackingSourceId,
              'p_recorded_at': request.recordedAt?.toIso8601String(),
              'p_metadata': request.metadata,
            },
          )
          .timeout(_networkTimeout);

      return eventId as String;
    } on AppException {
      rethrow;
    } on Object catch (error, stackTrace) {
      throw AppExceptionMapper.mapAndLog(
        error,
        stackTrace,
        'Error ingesting bus location',
      );
    }
  }

  Map<String, dynamic> _firstRpcRow(Object rows) {
    final list = rows as List<dynamic>;
    if (list.isEmpty) {
      throw const NotFoundException(message: 'No public transport result.');
    }
    return Map<String, dynamic>.from(list.first as Map);
  }

  String _dateOnly(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }
}
