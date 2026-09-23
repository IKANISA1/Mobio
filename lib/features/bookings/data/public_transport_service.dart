import 'package:mobi_app/core/config/supabase_config.dart';
import 'package:mobi_app/core/errors/app_exception.dart';
import 'package:mobi_app/core/errors/app_exception_mapper.dart';
import 'package:mobi_app/features/bookings/domain/transport_agency_catalog.dart';
import 'package:mobi_shared_types/models/public_transport.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthException;

class PublicTransportService {
  PublicTransportService({this.supabase});

  final SupabaseClient? supabase;
  static const _networkTimeout = Duration(seconds: 15);
  static const fallbackAgencyNames = rwandaTransportAgencyNames;

  List<TransportAgency>? _cachedAgencies;
  List<TransportAgency>? _cachedAllAgencies;

  SupabaseClient get _client {
    final client = supabase;
    if (client != null) return client;
    if (!SupabaseConfig.isConfigured) {
      throw StateError(
        'Supabase client is unavailable because Supabase is not configured.',
      );
    }
    return Supabase.instance.client;
  }

  Future<List<TransportAgency>> getAgencies({
    bool includeInactive = false,
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh) {
      final cached = includeInactive ? _cachedAllAgencies : _cachedAgencies;
      if (cached != null) return cached;
    }

    try {
      var query = _client
          .from('transport_agencies')
          .select(
            'id, name, slug, phone, whatsapp, email, service_area, '
            'is_active, created_at, updated_at',
          );
      if (!includeInactive) {
        query = query.eq('is_active', true);
      }

      final rows = await query.order('name').timeout(_networkTimeout);
      final agencies =
          (rows as List<dynamic>)
              .whereType<Map<String, dynamic>>()
              .map(TransportAgency.fromJson)
              .where((agency) => agency.name.trim().isNotEmpty)
              .toList()
            ..sort(
              (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
            );

      if (includeInactive) {
        _cachedAllAgencies = agencies;
      } else {
        _cachedAgencies = agencies;
      }
      return agencies;
    } on Object {
      if (SupabaseConfig.isLocalUiPreview) {
        return _fallbackAgencies(includeInactive: includeInactive);
      }
      rethrow;
    }
  }

  Future<List<String>> getAgencyNames({bool includeInactive = false}) async {
    try {
      final names =
          (await getAgencies(includeInactive: includeInactive))
              .map(
                (agency) => agency.name.replaceAll(RegExp(r'\s+'), ' ').trim(),
              )
              .where((name) => name.isNotEmpty)
              .toSet()
              .toList()
            ..sort();

      return names;
    } on Object {
      if (SupabaseConfig.isLocalUiPreview) return fallbackAgencyNames;
      rethrow;
    }
  }

  Future<void> upsertAgency({
    String? id,
    required String name,
    String? phone,
    String? whatsapp,
    String? email,
    String serviceArea = 'rwanda',
    bool isActive = true,
  }) async {
    await _client
        .rpc(
          'rpc_admin_upsert_transport_agency',
          params: {
            'p_agency_id': id,
            'p_name': name,
            'p_phone': phone,
            'p_whatsapp': whatsapp,
            'p_email': email,
            'p_service_area': serviceArea,
            'p_is_active': isActive,
          },
        )
        .timeout(_networkTimeout);
    invalidateAgencyCache();
  }

  Future<void> setAgencyActive(String id, bool isActive) async {
    await _client
        .rpc(
          'rpc_admin_set_transport_agency_active',
          params: {'p_agency_id': id, 'p_is_active': isActive},
        )
        .timeout(_networkTimeout);
    invalidateAgencyCache();
  }

  Future<void> removeAgency(String id) async {
    await _client
        .rpc('rpc_admin_remove_transport_agency', params: {'p_agency_id': id})
        .timeout(_networkTimeout);
    invalidateAgencyCache();
  }

  void invalidateAgencyCache() {
    _cachedAgencies = null;
    _cachedAllAgencies = null;
  }

  Future<List<PublicTransportSchedule>> searchSchedules({
    String? originSearch,
    String? destinationSearch,
    DateTime? departureDate,
    String? agencyId,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final rows = await _client
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
      final rows = await _client
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
      final rows = await _client
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
      await _client
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
      final rows = await _client
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
      final eventId = await _client
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

  List<TransportAgency> _fallbackAgencies({required bool includeInactive}) {
    return [
      for (final name in fallbackAgencyNames)
        TransportAgency(
          id: name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-'),
          name: name,
          slug: name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-'),
          isActive: true,
        ),
    ];
  }
}
