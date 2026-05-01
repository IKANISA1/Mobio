import 'package:intl/intl.dart';
import 'package:mobi_app/core/errors/app_exception.dart';
import 'package:mobi_app/core/errors/app_exception_mapper.dart';
import 'package:mobi_app/models/trip.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthException;

/// Service for trip operations via Supabase direct table queries.
///
/// Handles:
/// - Creating trips via direct INSERT
/// - Listing trips (own + nearby)
/// - Getting trip details by ID
/// - Cancelling trips (status + is_active)
class TripService {
  final SupabaseClient _supabase;

  /// Minimum interval between trip creation calls (prevents double-tap / DoS).
  static const _createCooldown = Duration(seconds: 3);
  static DateTime? _lastCreateTime;

  /// Network timeout for data-fetching operations.
  static const _networkTimeout = Duration(seconds: 15);

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

  // ---------------------------------------------------------------------------
  // Create
  // ---------------------------------------------------------------------------

  /// Inserts a new trip directly and returns the created row.
  Future<Trip> createTrip({
    required String origin,
    double? originLat,
    double? originLng,
    required String destination,
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
    final userId = _requireUserId('Please sign in to schedule a trip.');

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
      final row = await _supabase
          .from('trips')
          .insert({
            'author_id': userId,
            'origin': origin,
            'origin_lat': originLat,
            'origin_lng': originLng,
            'destination': destination,
            'dest_lat': destLat,
            'dest_lng': destLng,
            'departure_date': departureDate,
            'departure_time': departureTime,
            'role': role,
            'vehicle_type': vehicleType,
            'is_recurring': isRecurring,
            'recurring_days': recurringDays,
            'note': note,
          })
          .select()
          .single()
          .timeout(_networkTimeout);

      return Trip.fromJson(row);
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
          .select()
          .eq('id', tripId)
          .maybeSingle();

      if (row == null) return null;
      return Trip.fromJson(row);
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
          .gte('departure_date', today)
          .order('departure_date', ascending: true)
          .order('departure_time', ascending: true)
          .timeout(_networkTimeout);

      return rows.map<Trip>(Trip.fromJson).toList();
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

  /// Fetches active trips from *other* users (nearby/discover feed).
  /// Excludes trips with departure dates in the past.
  Future<List<Trip>> getNearbyTrips() async {
    final userId = _currentUserId;
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

    try {
      var query = _supabase
          .from('trips')
          .select()
          .or('status.eq.active,status.eq.approved')
          .eq('is_active', true)
          .gte('departure_date', today);

      if (userId != null) {
        query = query.neq('author_id', userId);
      }

      final rows = await query
          .order('departure_date', ascending: true)
          .order('departure_time', ascending: true)
          .limit(50)
          .timeout(_networkTimeout);

      return rows.map<Trip>(Trip.fromJson).toList();
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

  // ---------------------------------------------------------------------------
  // Cancel
  // ---------------------------------------------------------------------------

  /// Cancels a trip by setting status to 'cancelled' and is_active to false.
  ///
  /// Only the trip author can cancel their own trip. RLS enforces this at the
  /// database layer, but this explicit check provides proper error feedback.
  Future<void> cancelTrip(String tripId) async {
    final userId = _requireUserId('Please sign in to cancel a trip.');

    try {
      final rows = await _supabase
          .from('trips')
          .update({'status': 'cancelled', 'is_active': false})
          .eq('id', tripId)
          .eq('author_id', userId)
          .select('id')
          .timeout(_networkTimeout);

      if ((rows as List).isEmpty) {
        throw const ForbiddenException(
          message: 'Trip not found or you do not have permission to cancel it.',
        );
      }
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
