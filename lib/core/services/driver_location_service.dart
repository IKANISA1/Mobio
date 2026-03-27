import 'package:mobi_app/core/utils/app_logger.dart';
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
    return NearbyDriver(
      driverId: json['driver_id'] as String,
      memberId: json['member_id'] as String? ?? '',
      vehicleTypeId: json['vehicle_type_id'] as String? ?? 'cab',
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      distanceKm: (json['distance_km'] as num).toDouble(),
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

      final response = await _supabase.rpc(
        'rpc_search_nearby_drivers',
        params: params,
      );

      final List<dynamic> data = response as List<dynamic>;
      return data
          .map((row) => NearbyDriver.fromJson(row as Map<String, dynamic>))
          .toList();
    } catch (e) {
      AppLogger.error('Error finding nearby drivers: $e');
      return [];
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
    if (userId == null) return;

    try {
      await _supabase.from('driver_locations').upsert({
        'driver_id': userId,
        'latitude': latitude,
        'longitude': longitude,
        'heading': ?heading,
        'speed': ?speed,
        'vehicle_type_id': ?vehicleTypeId,
        'is_online': true,
      });
    } catch (e) {
      AppLogger.error('Error updating driver location: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Online/Offline Toggle
  // ---------------------------------------------------------------------------

  /// Sets the driver's online status.
  Future<void> setOnlineStatus(bool isOnline) async {
    final userId = _currentUserId;
    if (userId == null) return;

    try {
      await _supabase
          .from('driver_locations')
          .update({'is_online': isOnline})
          .eq('driver_id', userId);
    } catch (e) {
      AppLogger.error('Error toggling online status: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Discover Summary (RPC)
  // ---------------------------------------------------------------------------

  /// Gets the discover summary (nearby driver count + scheduled trip count).
  /// Used by the home screen hero card.
  Future<Map<String, dynamic>> getDiscoverSummary({
    double? latitude,
    double? longitude,
    String? vehicleType,
  }) async {
    try {
      final params = <String, dynamic>{};
      if (latitude != null) params['p_user_lat'] = latitude;
      if (longitude != null) params['p_user_lng'] = longitude;
      if (vehicleType != null) params['p_vehicle_type'] = vehicleType;

      final response = await _supabase.rpc(
        'rpc_get_discover_summary',
        params: params,
      );

      if (response is Map<String, dynamic>) {
        return response;
      }
      return {'nearby_driver_count': 0, 'scheduled_trip_count': 0};
    } catch (e) {
      AppLogger.error('Error fetching discover summary: $e');
      return {'nearby_driver_count': 0, 'scheduled_trip_count': 0};
    }
  }

  // ---------------------------------------------------------------------------
  // Driver Online Status (RPC)
  // ---------------------------------------------------------------------------

  /// Sets driver online/offline status via `rpc_set_driver_online_status`.
  /// Also updates `last_seen_at` in the profiles table.
  Future<void> setDriverOnlineStatus(bool isOnline) async {
    try {
      await _supabase.rpc(
        'rpc_set_driver_online_status',
        params: {'p_is_online': isOnline},
      );
    } catch (e) {
      AppLogger.error('Error setting driver online status via RPC: $e');
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
