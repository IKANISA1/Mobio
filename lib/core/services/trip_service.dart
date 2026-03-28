import 'package:mobi_app/core/utils/app_logger.dart';
import 'package:mobi_app/models/trip.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

  TripService({SupabaseClient? supabase})
    : _supabase = supabase ?? Supabase.instance.client;

  String? get _currentUserId => _supabase.auth.currentUser?.id;

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
    final userId = _currentUserId;
    if (userId == null) {
      throw Exception('User must be authenticated to create a trip.');
    }

    // Debounce: reject rapid duplicate submissions
    final now = DateTime.now();
    if (_lastCreateTime != null &&
        now.difference(_lastCreateTime!) < _createCooldown) {
      throw Exception('Please wait a moment before creating another trip.');
    }
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
          .single();

      return Trip.fromJson(row);
    } on Object catch (e) {
      AppLogger.error('Error creating trip: $e');
      rethrow;
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
    } on Object catch (e) {
      AppLogger.error('Error fetching trip $tripId: $e');
      return null;
    }
  }

  /// Fetches trips created by the current user, ordered by departure.
  Future<List<Trip>> getMyTrips() async {
    final userId = _currentUserId;
    if (userId == null) return [];

    try {
      final rows = await _supabase
          .from('trips')
          .select()
          .eq('author_id', userId)
          .order('departure_date', ascending: true)
          .order('departure_time', ascending: true);

      return rows.map<Trip>(Trip.fromJson).toList();
    } on Object catch (e) {
      AppLogger.error('Error fetching my trips: $e');
      return [];
    }
  }

  /// Fetches active trips from *other* users (nearby/discover feed).
  Future<List<Trip>> getNearbyTrips() async {
    final userId = _currentUserId;

    try {
      var query = _supabase
          .from('trips')
          .select()
          .or('status.eq.active,status.eq.approved')
          .eq('is_active', true);

      if (userId != null) {
        query = query.neq('author_id', userId);
      }

      final rows = await query
          .order('departure_date', ascending: true)
          .order('departure_time', ascending: true)
          .limit(50);

      return rows.map<Trip>(Trip.fromJson).toList();
    } on Object catch (e) {
      AppLogger.error('Error fetching nearby trips: $e');
      return [];
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
    final userId = _currentUserId;
    if (userId == null) {
      throw Exception('User must be authenticated to cancel a trip.');
    }

    try {
      final rows = await _supabase
          .from('trips')
          .update({'status': 'cancelled', 'is_active': false})
          .eq('id', tripId)
          .eq('author_id', userId)
          .select('id');

      if ((rows as List).isEmpty) {
        throw Exception(
          'Trip not found or you do not have permission to cancel it.',
        );
      }
    } on Object catch (e) {
      AppLogger.error('Error cancelling trip $tripId: $e');
      rethrow;
    }
  }
}
