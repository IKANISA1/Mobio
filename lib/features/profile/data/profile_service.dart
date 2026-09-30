import 'package:mobi_app/core/async/account_epoch.dart';
import 'package:mobi_app/core/async/request_deadline.dart';
import 'package:mobi_app/core/auth/account_context.dart';
import 'package:mobi_app/core/utils/app_logger.dart';
import 'package:mobi_app/features/profile/domain/profile_wire_record.dart';
import 'package:mobi_shared_types/models/profile.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Service for profile CRUD operations via Supabase.
///
/// Handles:
/// - Fetching the current user's profile
/// - Updating profile via `rpc_update_profile` RPC
/// - Enabling/disabling driver mode via RPCs
/// - Fetching user rating via `get_user_rating()` RPC
class ProfileService {
  final SupabaseClient _supabase;
  final AccountSnapshot Function()? _captureOverride;
  final void Function(AccountSnapshot)? _requireCurrentOverride;

  ProfileService({
    SupabaseClient? supabase,
    AccountSnapshot Function()? captureAccount,
    void Function(AccountSnapshot)? requireCurrent,
  }) : _supabase = supabase ?? Supabase.instance.client,
       _captureOverride = captureAccount,
       _requireCurrentOverride = requireCurrent;

  String? get _currentUserId => _supabase.auth.currentUser?.id;

  AccountSnapshot _captureAccount() {
    final account = _captureOverride?.call() ?? AccountContext.capture();
    if (_currentUserId != account.userId) throw const StaleAccountWork();
    return account;
  }

  void _requireCurrent(AccountSnapshot account) {
    if (_currentUserId != account.userId) throw const StaleAccountWork();
    (_requireCurrentOverride ?? AccountContext.requireCurrent)(account);
  }

  // ---------------------------------------------------------------------------
  // Read
  // ---------------------------------------------------------------------------

  /// Fetches the current user's profile row.
  Future<Profile?> getMyProfile() async {
    final user = _supabase.auth.currentUser;
    if (user == null || user.isAnonymous) return null;
    final account = _captureAccount();
    if (account.userId != user.id) throw const StaleAccountWork();

    try {
      final row = await RequestDeadline.read(
        _supabase
            .from('profiles')
            .select()
            .eq('id', account.userId)
            .maybeSingle(),
      );
      _requireCurrent(account);
      return row == null
          ? null
          : ProfileWireRecord.parse(row, expectedId: account.userId);
    } on Object catch (e) {
      AppLogger.error('Error fetching profile: $e');
      rethrow;
    }
  }

  /// Fetches the limited public profile shape allowed for peer UI surfaces.
  Future<Profile?> getProfileById(String userId) async {
    final account = _captureAccount();
    try {
      final rows = await RequestDeadline.read(
        _supabase.rpc(
          'rpc_get_public_profile',
          params: {'p_profile_id': userId},
        ),
      );
      _requireCurrent(account);

      if (rows is! List) {
        throw const FormatException('Invalid public profile RPC response');
      }
      if (rows.isEmpty) return null;
      if (rows.length != 1 || rows.first is! Map) {
        throw const FormatException('Invalid public profile RPC row count');
      }
      return ProfileWireRecord.parse(
        Map<String, dynamic>.from(rows.first as Map),
        expectedId: userId,
      );
    } on Object catch (e) {
      AppLogger.error('Error fetching public profile $userId: $e');
      rethrow;
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
    String? momoNumber,
    String? momoPayCode,
    String? countryCode,
    String? vehicleType,
    String? vehicleNumberPlate,
    String? busAgencyName,
    int? busPassengerCapacity,
    bool includeBusFields = false,
    String? rentalVehicleModel,
    bool includeRentalFields = false,
    String? avatarUrl,
  }) async {
    try {
      final payload = <String, dynamic>{};
      if (phone != null) payload['phone'] = phone;
      if (whatsapp != null) payload['whatsapp'] = whatsapp;
      if (momoNumber != null) payload['momo_number'] = momoNumber;
      if (momoPayCode != null) payload['momo_pay_code'] = momoPayCode;
      if (countryCode != null) payload['country_code'] = countryCode;
      if (vehicleType != null) payload['vehicle_type'] = vehicleType;
      if (vehicleNumberPlate != null) {
        payload['vehicle_number_plate'] = vehicleNumberPlate;
      }
      if (includeBusFields) {
        payload['bus_agency_name'] = busAgencyName;
        payload['bus_passenger_capacity'] = busPassengerCapacity;
      }
      if (includeRentalFields) {
        payload['rental_vehicle_model'] = rentalVehicleModel;
      }
      if (avatarUrl != null) payload['avatar_url'] = avatarUrl;

      if (payload.isEmpty) return;

      final account = _captureAccount();

      await RequestDeadline.mutation(
        _supabase.rpc('rpc_update_profile', params: {'p_payload': payload}),
        operation: 'update_profile',
        operationId: account.userId,
      );
      _requireCurrent(account);
    } on Object catch (e) {
      AppLogger.error('Error updating profile via RPC: $e');
      rethrow;
    }
  }

  Future<void> saveProfileSettings({
    required String momoNumber,
    required String momoPayCode,
    required bool isDriver,
    required String vehicleTypeId,
    required String vehicleNumberPlate,
    String? busAgencyName,
    int? busPassengerCapacity,
    String? rentalVehicleModel,
    required bool previousIsDriver,
  }) async {
    final account = _captureAccount();
    final isBusDriver = isDriver && vehicleTypeId == 'bus';
    final isRentalOwner = isDriver && vehicleTypeId == 'rentals';

    await updateProfileViaRpc(
      momoNumber: momoNumber,
      momoPayCode: momoPayCode,
      vehicleType: isDriver ? vehicleTypeId : null,
      vehicleNumberPlate: isDriver ? vehicleNumberPlate : null,
      busAgencyName: isBusDriver ? busAgencyName : null,
      busPassengerCapacity: isBusDriver ? busPassengerCapacity : null,
      includeBusFields: true,
      rentalVehicleModel: isRentalOwner ? rentalVehicleModel : null,
      includeRentalFields: true,
    );
    _requireCurrent(account);

    if (previousIsDriver != isDriver) {
      if (isDriver) {
        await enableDriverMode(
          vehicleType: vehicleTypeId,
          vehicleNumberPlate: vehicleNumberPlate,
          busAgencyName: isBusDriver ? busAgencyName : null,
          busPassengerCapacity: isBusDriver ? busPassengerCapacity : null,
          rentalVehicleModel: isRentalOwner ? rentalVehicleModel : null,
        );
      } else {
        await disableDriverMode();
      }
      _requireCurrent(account);
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
      final account = _captureAccount();
      await RequestDeadline.mutation(
        _supabase.from('profiles').update(updates).eq('id', userId),
        operation: 'legacy_update_profile',
        operationId: userId,
      );
      _requireCurrent(account);
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
    String? busAgencyName,
    int? busPassengerCapacity,
    String? rentalVehicleModel,
  }) async {
    try {
      final account = _captureAccount();
      await RequestDeadline.mutation(
        _supabase.rpc(
          'rpc_enable_driver_mode',
          params: {
            'p_vehicle_type': vehicleType,
            'p_vehicle_number_plate': vehicleNumberPlate,
            'p_bus_agency_name': busAgencyName,
            'p_bus_passenger_capacity': busPassengerCapacity,
            'p_rental_vehicle_model': rentalVehicleModel,
          },
        ),
        operation: 'enable_driver_mode',
        operationId: account.userId,
      );
      _requireCurrent(account);
    } on Object catch (e) {
      AppLogger.error('Error enabling driver mode: $e');
      rethrow;
    }
  }

  /// Disables driver mode via `rpc_disable_driver_mode` RPC.
  Future<void> disableDriverMode() async {
    try {
      final account = _captureAccount();
      await RequestDeadline.mutation(
        _supabase.rpc('rpc_disable_driver_mode'),
        operation: 'disable_driver_mode',
        operationId: account.userId,
      );
      _requireCurrent(account);
    } on Object catch (e) {
      AppLogger.error('Error disabling driver mode: $e');
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // Rating (RPC)
  // ---------------------------------------------------------------------------

  /// Fetches user rating by querying the `ratings` table directly.
  Future<UserRating> getUserRating([String? userId]) async {
    final account = _captureAccount();
    final uid = userId ?? _currentUserId;
    if (uid == null) throw const StaleAccountWork();

    try {
      final rows = await RequestDeadline.read(
        _supabase.from('ratings').select('score').eq('rated_user_id', uid),
      );

      _requireCurrent(account);
      final ratings = rows;
      if (ratings.isEmpty) {
        return const UserRating(averageScore: 0, totalRatings: 0);
      }

      double total = 0;
      for (final row in ratings) {
        if (row['score'] is! num) {
          throw const FormatException('Invalid rating row');
        }
        final score = (row['score'] as num).toDouble();
        if (!score.isFinite || score < 1 || score > 5) {
          throw const FormatException('Invalid rating score');
        }
        total += score;
      }

      return UserRating(
        averageScore: total / ratings.length,
        totalRatings: ratings.length,
      );
    } on Object catch (e) {
      AppLogger.error('Error fetching user rating: $e');
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // Member Info
  // ---------------------------------------------------------------------------

  /// Returns the year the user joined (from `created_at`).
  Future<int?> getMemberSinceYear() async {
    final profile = await getMyProfile();
    if (profile == null) return null;

    final createdAt = profile.createdAt;
    if (createdAt == null) return null;

    final date = DateTime.tryParse(createdAt);
    return date?.year;
  }

  /// Returns the user's server-generated numeric member_id.
  Future<String?> getMemberId() async {
    final profile = await getMyProfile();
    return profile?.memberId;
  }

  // ---------------------------------------------------------------------------
}

class UserRating {
  const UserRating({required this.averageScore, required this.totalRatings});

  final double averageScore;
  final int totalRatings;
}
