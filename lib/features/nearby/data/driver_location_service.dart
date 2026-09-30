import 'package:mobi_app/core/async/request_deadline.dart';
import 'package:mobi_app/core/utils/app_logger.dart';
import 'package:mobi_app/core/utils/mobio_member_id.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Data class representing a nearby driver returned by the RPC.
class NearbyDriver {
  final String driverId;
  final String memberId;
  final String vehicleTypeId;
  final double latitude;
  final double longitude;
  final double distanceKm;

  const NearbyDriver({
    required this.driverId,
    required this.memberId,
    required this.vehicleTypeId,
    required this.latitude,
    required this.longitude,
    required this.distanceKm,
  });

  factory NearbyDriver.fromJson(Map<String, dynamic> json) {
    final driverId = json['driver_id'];
    final memberId = json['member_id'];
    final vehicleTypeId = json['vehicle_type_id'];
    final latitude = json['latitude'];
    final longitude = json['longitude'];
    final distanceKm = json['distance_km'];
    if (driverId is! String ||
        !RegExp(
          r'^[0-9a-fA-F]{8}(-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}$',
        ).hasMatch(driverId) ||
        memberId is! String ||
        !isValidMobioMemberId(memberId) ||
        vehicleTypeId is! String ||
        vehicleTypeId.trim().isEmpty ||
        latitude is! num ||
        !latitude.toDouble().isFinite ||
        latitude < -90 ||
        latitude > 90 ||
        longitude is! num ||
        !longitude.toDouble().isFinite ||
        longitude < -180 ||
        longitude > 180 ||
        distanceKm is! num ||
        !distanceKm.toDouble().isFinite ||
        distanceKm < 0) {
      throw const FormatException('Invalid nearby driver RPC response');
    }
    return NearbyDriver(
      driverId: driverId,
      memberId: memberId,
      vehicleTypeId: vehicleTypeId,
      latitude: latitude.toDouble(),
      longitude: longitude.toDouble(),
      distanceKm: distanceKm.toDouble(),
    );
  }
}

class DiscoverSummary {
  const DiscoverSummary({
    required this.nearbyDriverCount,
    required this.scheduledTripCount,
  });

  final int nearbyDriverCount;
  final int scheduledTripCount;

  factory DiscoverSummary.fromJson(Map<String, dynamic> json) {
    final drivers = json['nearby_driver_count'];
    final trips = json['scheduled_trip_count'];
    if (drivers is! int || drivers < 0 || trips is! int || trips < 0) {
      throw const FormatException('Invalid discover summary RPC response');
    }
    return DiscoverSummary(
      nearbyDriverCount: drivers,
      scheduledTripCount: trips,
    );
  }
}

/// Service for driver location operations via Supabase.
///
/// Handles:
/// - Finding nearby drivers via `find_nearby_drivers()` RPC
/// - Updating driver location (upsert to `driver_locations`)
/// - Toggling online/offline status
class DriverLocationService {
  final SupabaseClient _supabase;

  DriverLocationService({SupabaseClient? supabase})
    : _supabase = supabase ?? Supabase.instance.client;

  String? get _currentUserId => _supabase.auth.currentUser?.id;

  // ---------------------------------------------------------------------------
  // Find Nearby Drivers (RPC)
  // ---------------------------------------------------------------------------

  /// Calls the `rpc_search_nearby_drivers` Postgres function.
  /// Returns a list of [NearbyDriver] sorted by proximity.
  Future<List<NearbyDriver>> findNearbyDrivers({
    required double latitude,
    required double longitude,
    double radiusKm = 10,
    String? vehicleType,
    int limit = 20,
  }) async {
    try {
      final params = <String, dynamic>{
        'p_user_lat': latitude,
        'p_user_lng': longitude,
        'p_limit': limit,
      };
      if (vehicleType != null) params['p_vehicle_type'] = vehicleType;

      final response = await RequestDeadline.read(
        _supabase.rpc('rpc_search_nearby_drivers', params: params),
      );

      if (response is! List) {
        throw const FormatException('Invalid nearby driver list');
      }
      final data = response;
      return data
          .map(
            (row) =>
                NearbyDriver.fromJson(Map<String, dynamic>.from(row as Map)),
          )
          .toList();
    } on Object catch (e) {
      AppLogger.error('Error finding nearby drivers: $e');
      rethrow;
    }
  }

  /// Returns the count of nearby online drivers (quick counter for hero card).
  Future<int> getNearbyDriverCount({
    required double latitude,
    required double longitude,
    double radiusKm = 10,
  }) async {
    final drivers = await findNearbyDrivers(
      latitude: latitude,
      longitude: longitude,
      radiusKm: radiusKm,
    );
    return drivers.length;
  }

  // ---------------------------------------------------------------------------
  // Update Driver Location
  // ---------------------------------------------------------------------------

  /// Upserts the current driver's location into `driver_locations`.
  Future<void> updateLocation({
    required double latitude,
    required double longitude,
    double? heading,
    double? speed,
    String? vehicleTypeId,
  }) async {
    final userId = _currentUserId;
    if (userId == null) throw StateError('Verified driver account required');

    try {
      await RequestDeadline.mutation(
        _supabase.from('driver_locations').upsert({
          'driver_id': userId,
          'latitude': latitude,
          'longitude': longitude,
          'heading': ?heading,
          'speed': ?speed,
          'vehicle_type_id': ?vehicleTypeId,
          'is_online': true,
        }),
        operation: 'update_driver_location',
        operationId: userId,
      );
    } on Object catch (e) {
      AppLogger.error('Error updating driver location: $e');
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // Online/Offline Toggle
  // ---------------------------------------------------------------------------

  /// Sets the driver's online status.
  Future<void> setOnlineStatus(bool isOnline) async {
    final userId = _currentUserId;
    if (userId == null) throw StateError('Verified driver account required');

    try {
      await RequestDeadline.mutation(
        _supabase
            .from('driver_locations')
            .update({'is_online': isOnline})
            .eq('driver_id', userId),
        operation: 'set_driver_online_status',
        operationId: userId,
      );
    } on Object catch (e) {
      AppLogger.error('Error toggling online status: $e');
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // Discover Summary (RPC)
  // ---------------------------------------------------------------------------

  /// Gets the discover summary (nearby driver count + scheduled trip count).
  /// Used by the home screen hero card.
  Future<DiscoverSummary> getDiscoverSummary({
    double? latitude,
    double? longitude,
    String? vehicleType,
  }) async {
    try {
      final params = <String, dynamic>{};
      if (latitude != null) params['p_user_lat'] = latitude;
      if (longitude != null) params['p_user_lng'] = longitude;
      if (vehicleType != null) params['p_vehicle_type'] = vehicleType;

      final response = await RequestDeadline.read(
        _supabase.rpc('rpc_get_discover_summary', params: params),
      );

      return DiscoverSummary.fromJson(
        Map<String, dynamic>.from(response as Map),
      );
    } on Object catch (e) {
      AppLogger.error('Error fetching discover summary: $e');
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // Driver Online Status (RPC)
  // ---------------------------------------------------------------------------

  /// Sets driver online/offline status via `rpc_set_driver_online_status`.
  /// Also updates `last_seen_at` in the profiles table.
  Future<void> setDriverOnlineStatus(bool isOnline) async {
    final userId = _currentUserId;
    if (userId == null) throw StateError('Verified driver account required');
    try {
      await RequestDeadline.mutation(
        _supabase.rpc(
          'rpc_set_driver_online_status',
          params: {'p_is_online': isOnline},
        ),
        operation: 'set_driver_online_status',
        operationId: userId,
      );
    } on Object catch (e) {
      AppLogger.error('Error setting driver online status via RPC: $e');
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // Realtime subscription for driver movement
  // ---------------------------------------------------------------------------

  /// Subscribes to realtime changes on online driver locations.
  /// Returns a [RealtimeChannel] that the caller should unsubscribe from
  /// when no longer needed.
  RealtimeChannel subscribeToDriverUpdates({
    required void Function(Map<String, dynamic> payload) onUpdate,
  }) {
    return _supabase
        .channel('driver_locations_realtime')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'driver_locations',
          callback: (payload) {
            onUpdate(payload.newRecord);
          },
        )
        .subscribe();
  }
}
