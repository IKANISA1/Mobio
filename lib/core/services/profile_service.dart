import 'package:mobi_app/core/utils/app_logger.dart';
import 'package:mobi_app/features/biopay/models/biopay_handle.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Service for profile CRUD operations via Supabase.
///
/// Handles:
/// - Fetching the current user's profile
/// - Updating profile via `rpc_update_profile` RPC
/// - Enabling/disabling driver mode via RPCs
/// - Fetching user rating via `get_user_rating()` RPC
/// - BioPay handle management
class ProfileService {
  final SupabaseClient _supabase;

  ProfileService({SupabaseClient? supabase})
    : _supabase = supabase ?? Supabase.instance.client;

  String? get _currentUserId => _supabase.auth.currentUser?.id;

  // ---------------------------------------------------------------------------
  // Read
  // ---------------------------------------------------------------------------

  /// Fetches the current user's profile row.
  Future<Map<String, dynamic>?> getMyProfile() async {
    final userId = _currentUserId;
    if (userId == null) return null;

    try {
      final row = await _supabase
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();
      return row;
    } on Object catch (e) {
      AppLogger.error('Error fetching profile: $e');
      return null;
    }
  }

  /// Fetches a specific user's profile by ID.
  Future<Map<String, dynamic>?> getProfileById(String userId) async {
    try {
      final row = await _supabase
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();
      return row;
    } on Object catch (e) {
      AppLogger.error('Error fetching profile $userId: $e');
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // Update (RPC)
  // ---------------------------------------------------------------------------

  /// Updates the current user's profile via `rpc_update_profile` RPC.
  /// Only non-null fields will be sent.
  Future<void> updateProfileViaRpc({
    String? phone,
    String? whatsapp,
    String? countryCode,
    String? vehicleType,
    String? vehicleNumberPlate,
    String? avatarUrl,
    String? bioPayHandleType,
    String? bioPayHandleValue,
  }) async {
    try {
      final payload = <String, dynamic>{};
      if (phone != null) payload['phone'] = phone;
      if (whatsapp != null) payload['whatsapp'] = whatsapp;
      if (countryCode != null) payload['country_code'] = countryCode;
      if (vehicleType != null) payload['vehicle_type'] = vehicleType;
      if (vehicleNumberPlate != null) {
        payload['vehicle_number_plate'] = vehicleNumberPlate;
      }
      if (avatarUrl != null) payload['avatar_url'] = avatarUrl;
      if (bioPayHandleType != null) {
        payload['biopay_handle_type'] = bioPayHandleType;
      }
      if (bioPayHandleValue != null) {
        payload['biopay_handle_value'] = bioPayHandleValue;
      }

      if (payload.isEmpty) return;

      await _supabase.rpc('rpc_update_profile', params: {'p_payload': payload});
    } on Object catch (e) {
      AppLogger.error('Error updating profile via RPC: $e');
      rethrow;
    }
  }

  Future<void> saveProfileSettings({
    required String whatsapp,
    required String countryCode,
    required BiopayHandleType biopayHandleType,
    required String biopayHandleValue,
    required bool isDriver,
    required String vehicleTypeId,
    required String vehicleNumberPlate,
    required bool previousIsDriver,
  }) async {
    await updateProfileViaRpc(
      whatsapp: whatsapp,
      countryCode: countryCode,
      vehicleType: isDriver ? vehicleTypeId : null,
      vehicleNumberPlate: isDriver ? vehicleNumberPlate : null,
      bioPayHandleType: biopayHandleType.storageValue,
      bioPayHandleValue: biopayHandleValue.trim(),
    );

    if (previousIsDriver != isDriver) {
      if (isDriver) {
        await enableDriverMode(
          vehicleType: vehicleTypeId,
          vehicleNumberPlate: vehicleNumberPlate,
        );
      } else {
        await disableDriverMode();
      }
    }
  }

  /// Legacy: Updates the current user's profile fields directly.
  ///
  /// **Deprecated:** Use [updateProfileViaRpc] or [saveProfileSettings]
  /// instead. This method bypasses the server-side field restrictions enforced
  /// by the `rpc_update_profile` RPC.
  @Deprecated(
    'Use updateProfileViaRpc() instead — direct table writes bypass RPC field protections',
  )
  Future<void> updateProfile({
    String? phone,
    String? countryCode,
    String? role,
    String? vehicleType,
    bool? isDriver,
  }) async {
    final userId = _currentUserId;
    if (userId == null) {
      throw Exception('User must be authenticated to update profile.');
    }

    final updates = <String, dynamic>{};
    if (phone != null) updates['phone'] = phone;
    if (countryCode != null) updates['country_code'] = countryCode;
    if (role != null) updates['role'] = role;
    if (vehicleType != null) updates['vehicle_type'] = vehicleType;
    if (isDriver != null) {
      updates['role'] = isDriver ? 'driver' : 'passenger';
    }

    if (updates.isEmpty) return;

    try {
      await _supabase.from('profiles').update(updates).eq('id', userId);
    } on Object catch (e) {
      AppLogger.error('Error updating profile: $e');
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // Driver Mode (RPCs)
  // ---------------------------------------------------------------------------

  /// Enables driver mode via `rpc_enable_driver_mode` RPC.
  Future<void> enableDriverMode({
    String vehicleType = 'cab',
    String? vehicleNumberPlate,
  }) async {
    try {
      await _supabase.rpc(
        'rpc_enable_driver_mode',
        params: {
          'p_vehicle_type': vehicleType,
          'p_vehicle_number_plate': vehicleNumberPlate,
        },
      );
    } on Object catch (e) {
      AppLogger.error('Error enabling driver mode: $e');
      rethrow;
    }
  }

  /// Disables driver mode via `rpc_disable_driver_mode` RPC.
  Future<void> disableDriverMode() async {
    try {
      await _supabase.rpc('rpc_disable_driver_mode');
    } on Object catch (e) {
      AppLogger.error('Error disabling driver mode: $e');
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // Rating (RPC)
  // ---------------------------------------------------------------------------

  /// Fetches user rating by querying the `ratings` table directly.
  /// Returns `{ 'average_score': double, 'total_ratings': int }`.
  Future<Map<String, dynamic>> getUserRating([String? userId]) async {
    final uid = userId ?? _currentUserId;
    if (uid == null) return {'average_score': 0.0, 'total_ratings': 0};

    try {
      final rows = await _supabase
          .from('ratings')
          .select('score')
          .eq('rated_user_id', uid);

      final ratings = rows as List<dynamic>;
      if (ratings.isEmpty) {
        return {'average_score': 0.0, 'total_ratings': 0};
      }

      double total = 0;
      for (final row in ratings) {
        total += (row['score'] as num).toDouble();
      }

      return {
        'average_score': total / ratings.length,
        'total_ratings': ratings.length,
      };
    } on Object catch (e) {
      AppLogger.error('Error fetching user rating: $e');
      return {'average_score': 0.0, 'total_ratings': 0};
    }
  }

  // ---------------------------------------------------------------------------
  // Member Info
  // ---------------------------------------------------------------------------

  /// Returns the year the user joined (from `created_at`).
  Future<int?> getMemberSinceYear() async {
    final profile = await getMyProfile();
    if (profile == null) return null;

    final createdAt = profile['created_at'] as String?;
    if (createdAt == null) return null;

    final date = DateTime.tryParse(createdAt);
    return date?.year;
  }

  /// Returns the user's server-generated numeric member_id.
  Future<String?> getMemberId() async {
    final profile = await getMyProfile();
    return profile?['member_id'] as String?;
  }

  // ---------------------------------------------------------------------------
}
