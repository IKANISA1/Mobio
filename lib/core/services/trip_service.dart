import 'package:intl/intl.dart';
import 'package:mobi_app/core/errors/app_exception.dart';
import 'package:mobi_app/core/errors/app_exception_mapper.dart';
import 'package:mobi_app/models/trip.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthException;

/// Service for trip operations via Supabase RPCs and direct read queries.
///
/// Handles:
/// - Creating trips through `rpc_create_trip`
/// - Listing trips (own + nearby)
/// - Getting trip details by ID
/// - Updating own scheduled trip posts
/// - Cancelling trips (status + is_active)
class TripService {
  final SupabaseClient _supabase;

  /// Minimum interval between trip creation calls (prevents double-tap / DoS).
  static const _createCooldown = Duration(seconds: 3);
  static DateTime? _lastCreateTime;

  /// Network timeout for data-fetching operations.
  static const _networkTimeout = Duration(seconds: 15);

  static const _publicTripSelect =
      'id, author_id, author_name, origin, origin_lat, origin_lng, '
      'destination, dest_lat, dest_lng, departure_date, departure_time, '
      'date, time, role, seats, price, note, description, is_active, status, '
      'vehicle_type, is_recurring, recurring_days, starts_at, '
      'recurrence_end_date, recurrence_skip_dates, origin_place_id, '
      'destination_place_id, client_request_id, cancelled_at, created_at, '
      'updated_at';

  TripService({SupabaseClient? supabase})
    : _supabase = supabase ?? Supabase.instance.client;

  String? get _currentUserId => _supabase.auth.currentUser?.id;

  String _requireUserId(String message) {
    final userId = _currentUserId;
    if (userId == null || userId.isEmpty) {
      throw AuthException(message: message);
    }
    return userId;
  }

  Trip _publicTripFromJson(Map<String, dynamic> row) {
    final safeRow = Map<String, dynamic>.from(row)..['whatsapp'] = '';
    return Trip.fromJson(safeRow);
  }

  // ---------------------------------------------------------------------------
  // Create
  // ---------------------------------------------------------------------------

  /// Creates a new trip through the server-side RPC and returns the created row.
  Future<Trip> createTrip({
    required String origin,
    String? originPlaceId,
    double? originLat,
    double? originLng,
    required String destination,
    String? destinationPlaceId,
    double? destLat,
    double? destLng,
    required String departureDate,
    required String departureTime,
    required String role,
    String vehicleType = 'cab',
    bool isRecurring = false,
    List<int> recurringDays = const [],
    String? clientRequestId,
    String? note,
  }) async {
    _requireUserId('Please sign in to schedule a trip.');

    // Debounce: reject rapid duplicate submissions
    final now = DateTime.now();
    if (_lastCreateTime != null &&
        now.difference(_lastCreateTime!) < _createCooldown) {
      throw const ValidationException(
        message: 'Please wait a moment before scheduling another trip.',
      );
    }
    final previousCreateTime = _lastCreateTime;
    _lastCreateTime = now;

    try {
      final tripId = await _supabase
          .rpc(
            'rpc_create_trip',
            params: {
              'p_payload': {
                'origin': origin,
                'origin_place_id': originPlaceId,
                'origin_lat': originLat,
                'origin_lng': originLng,
                'destination': destination,
                'destination_place_id': destinationPlaceId,
                'dest_lat': destLat,
                'dest_lng': destLng,
                'departure_date': departureDate,
                'departure_time': departureTime,
                'role': role,
                'vehicle_type': vehicleType,
                'is_recurring': isRecurring,
                'recurring_days': recurringDays,
                'client_request_id': clientRequestId,
                'note': note,
              },
            },
          )
          .timeout(_networkTimeout);

      final trip = await getTripById(tripId as String);
      if (trip == null) {
        throw const NotFoundException(message: 'Scheduled trip was not found.');
      }

      return trip;
    } on AppException {
      _lastCreateTime = previousCreateTime;
      rethrow;
    } on Object catch (error, stackTrace) {
      _lastCreateTime = previousCreateTime;
      throw AppExceptionMapper.mapAndLog(
        error,
        stackTrace,
        'Error creating trip',
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Read
  // ---------------------------------------------------------------------------

  /// Fetches a single trip by ID. Returns null if not found.
  Future<Trip?> getTripById(String tripId) async {
    try {
      final row = await _supabase
          .from('trips')
          .select(_publicTripSelect)
          .eq('id', tripId)
          .maybeSingle();

      if (row == null) return null;
      return _publicTripFromJson(row);
    } on AppException {
      rethrow;
    } on Object catch (error, stackTrace) {
      throw AppExceptionMapper.mapAndLog(
        error,
        stackTrace,
        'Error fetching trip $tripId',
      );
    }
  }

  /// Fetches trips created by the current user, ordered by departure.
  /// Excludes trips with departure dates in the past.
  Future<List<Trip>> getMyTrips() async {
    final userId = _currentUserId;
    if (userId == null) return [];

    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

    try {
      final rows = await _supabase
          .from('trips')
          .select()
          .eq('author_id', userId)
          .or('departure_date.gte.$today,recurrence_end_date.gte.$today')
          .order('departure_date', ascending: true)
          .order('departure_time', ascending: true)
          .timeout(_networkTimeout);

      return expandTripsForScheduleWindow(
        rows.map<Trip>(Trip.fromJson),
        DateTime.now(),
      );
    } on AppException {
      rethrow;
    } on Object catch (error, stackTrace) {
      throw AppExceptionMapper.mapAndLog(
        error,
        stackTrace,
        'Error fetching my trips',
      );
    }
  }

  /// Fetches active scheduled trips from *other* users.
  ///
  /// Use [role] to enforce the product privacy split:
  /// - passengers discover driver scheduled trips
  /// - drivers discover passenger scheduled trips
  ///
  /// Passenger live availability is intentionally not modelled here.
  /// Excludes trips with departure dates in the past.
  Future<List<Trip>> getNearbyTrips({String? role}) async {
    final userId = _currentUserId;
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final normalizedRole = role?.trim().toLowerCase();

    try {
      var query = _supabase
          .from('trips')
          .select(_publicTripSelect)
          .or('status.eq.active,status.eq.approved')
          .eq('is_active', true)
          .or('departure_date.gte.$today,recurrence_end_date.gte.$today');

      if (userId != null) {
        query = query.neq('author_id', userId);
      }
      if (normalizedRole == 'driver' || normalizedRole == 'passenger') {
        query = query.eq('role', normalizedRole!);
      }

      final rows = await query
          .order('departure_date', ascending: true)
          .order('departure_time', ascending: true)
          .limit(50)
          .timeout(_networkTimeout);

      return expandTripsForScheduleWindow(
        rows.map<Trip>(_publicTripFromJson),
        DateTime.now(),
        limit: 50,
      );
    } on AppException {
      rethrow;
    } on Object catch (error, stackTrace) {
      throw AppExceptionMapper.mapAndLog(
        error,
        stackTrace,
        'Error fetching nearby trips',
      );
    }
  }

  Future<List<Trip>> getCounterpartScheduledTrips(String viewerMode) {
    final roleToView = viewerMode.trim().toLowerCase() == 'driver'
        ? 'passenger'
        : 'driver';
    return getNearbyTrips(role: roleToView);
  }

  /// Returns server-ranked pool or driver/passenger suggestions for a trip.
  Future<List<Trip>> getPoolSuggestions(String tripId, {int limit = 10}) async {
    try {
      final rows = await _supabase
          .rpc(
            'rpc_suggest_trip_pools',
            params: {'p_trip_id': tripId, 'p_limit': limit},
          )
          .timeout(_networkTimeout);

      return (rows as List<dynamic>).map((row) {
        final json = Map<String, dynamic>.from(row as Map);
        json['id'] = json.remove('trip_id');
        json['status'] ??= 'active';
        json['is_active'] ??= true;
        json['whatsapp'] = '';
        return Trip.fromJson(json);
      }).toList();
    } on AppException {
      rethrow;
    } on Object catch (error, stackTrace) {
      throw AppExceptionMapper.mapAndLog(
        error,
        stackTrace,
        'Error fetching pool suggestions for trip $tripId',
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Update
  // ---------------------------------------------------------------------------

  /// Updates an existing scheduled trip post owned by the current user.
  Future<Trip> updateTrip({
    required String tripId,
    required String origin,
    String? originPlaceId,
    double? originLat,
    double? originLng,
    required String destination,
    String? destinationPlaceId,
    double? destLat,
    double? destLng,
    required String departureDate,
    required String departureTime,
    required String role,
    String vehicleType = 'cab',
    bool isRecurring = false,
    List<int> recurringDays = const [],
    String? note,
  }) async {
    _requireUserId('Please sign in to edit this trip.');
    final normalizedTripId = tripId.trim();
    if (normalizedTripId.isEmpty) {
      throw const ValidationException(message: 'Trip ID is required.');
    }

    try {
      final updatedTripId = await _supabase
          .rpc(
            'rpc_update_trip',
            params: {
              'p_trip_id': normalizedTripId,
              'p_payload': {
                'origin': origin,
                'origin_place_id': originPlaceId,
                'origin_lat': originLat,
                'origin_lng': originLng,
                'destination': destination,
                'destination_place_id': destinationPlaceId,
                'dest_lat': destLat,
                'dest_lng': destLng,
                'departure_date': departureDate,
                'departure_time': departureTime,
                'role': role,
                'vehicle_type': vehicleType,
                'is_recurring': isRecurring,
                'recurring_days': recurringDays,
                'note': note,
              },
            },
          )
          .timeout(_networkTimeout);

      final trip = await getTripById(updatedTripId as String);
      if (trip == null) {
        throw const NotFoundException(message: 'Updated trip was not found.');
      }

      return trip;
    } on AppException {
      rethrow;
    } on Object catch (error, stackTrace) {
      throw AppExceptionMapper.mapAndLog(
        error,
        stackTrace,
        'Error updating trip $normalizedTripId',
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Cancel
  // ---------------------------------------------------------------------------

  /// Cancels a trip by setting status to 'cancelled' and is_active to false.
  ///
  /// Only the trip author can cancel their own trip. RLS enforces this at the
  /// database layer, but this explicit check provides proper error feedback.
  Future<void> cancelTrip(String tripId) async {
    _requireUserId('Please sign in to cancel a trip.');

    try {
      await _supabase
          .rpc(
            'rpc_cancel_trip',
            params: {'p_trip_id': tripId, 'p_reason': null},
          )
          .timeout(_networkTimeout);
    } on AppException {
      rethrow;
    } on Object catch (error, stackTrace) {
      throw AppExceptionMapper.mapAndLog(
        error,
        stackTrace,
        'Error cancelling trip $tripId',
      );
    }
  }
}

List<Trip> expandTripsForScheduleWindow(
  Iterable<Trip> trips,
  DateTime now, {
  int limit = 100,
}) {
  final today = DateTime(now.year, now.month, now.day);
  final horizon = today.add(const Duration(days: 180));
  final expanded = <Trip>[];

  for (final trip in trips) {
    final baseDate = _parseIsoDate(trip.departureDate);
    if (baseDate == null) {
      expanded.add(trip);
      continue;
    }

    if (!trip.isRecurring || trip.recurringDays.isEmpty) {
      if (!baseDate.isBefore(today)) {
        expanded.add(trip);
      }
      continue;
    }

    final recurrenceEnd =
        _parseIsoDate(trip.recurrenceEndDate ?? '') ??
        baseDate.add(const Duration(days: 90));
    var day = _maxDate(today, baseDate);
    final lastDay = _minDate(recurrenceEnd, horizon);

    while (!day.isAfter(lastDay)) {
      final weekdayIndex = day.weekday - 1;
      final dateText = DateFormat('yyyy-MM-dd').format(day);
      final isSkipped = trip.recurrenceSkipDates.contains(dateText);
      if (trip.recurringDays.contains(weekdayIndex) && !isSkipped) {
        expanded.add(
          trip.copyWith(
            departureDate: dateText,
            date: dateText,
            startsAt: _startsAtUtcText(day, trip.departureTime),
          ),
        );
      }
      day = day.add(const Duration(days: 1));
    }
  }

  expanded.sort(_compareTripsByDeparture);
  if (limit > 0 && expanded.length > limit) {
    return expanded.take(limit).toList(growable: false);
  }
  return expanded;
}

DateTime? _parseIsoDate(String value) {
  final parsed = DateTime.tryParse(value.trim());
  if (parsed == null) return null;
  return DateTime(parsed.year, parsed.month, parsed.day);
}

int _compareTripsByDeparture(Trip a, Trip b) {
  final aDate = _parseIsoDate(a.departureDate) ?? DateTime(9999);
  final bDate = _parseIsoDate(b.departureDate) ?? DateTime(9999);
  final dateCompare = aDate.compareTo(bDate);
  if (dateCompare != 0) return dateCompare;
  return _minutesFromTimeText(
    a.departureTime,
  ).compareTo(_minutesFromTimeText(b.departureTime));
}

DateTime _maxDate(DateTime a, DateTime b) => a.isAfter(b) ? a : b;

DateTime _minDate(DateTime a, DateTime b) => a.isBefore(b) ? a : b;

String _startsAtUtcText(DateTime date, String timeText) {
  final minutes = _minutesFromTimeText(timeText);
  final startsAt = DateTime.utc(
    date.year,
    date.month,
    date.day,
    minutes ~/ 60,
    minutes % 60,
  );
  return startsAt.toIso8601String();
}

int _minutesFromTimeText(String value) {
  final trimmed = value.trim();
  final match = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(trimmed);
  if (match == null) return 24 * 60;

  var hour = int.tryParse(match.group(1) ?? '') ?? 0;
  final minute = int.tryParse(match.group(2) ?? '') ?? 0;
  final lower = trimmed.toLowerCase();
  if (lower.contains('pm') && hour < 12) {
    hour += 12;
  } else if (lower.contains('am') && hour == 12) {
    hour = 0;
  }

  return hour.clamp(0, 23) * 60 + minute.clamp(0, 59);
}
