import 'package:mobi_app/core/async/request_deadline.dart';
import 'package:mobi_app/core/async/client_operation_id.dart';
import 'package:mobi_app/core/async/account_epoch.dart';
import 'package:mobi_app/core/auth/account_context.dart';
import 'package:mobi_app/core/errors/app_exception.dart';
import 'package:mobi_app/core/errors/app_exception_mapper.dart';
import 'package:mobi_shared_types/models/favorite_address.dart';
import 'package:mobi_shared_types/models/place.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthException;

class FavoriteAddressService {
  FavoriteAddressService({
    SupabaseClient? supabase,
    AccountSnapshot Function()? captureAccount,
    void Function(AccountSnapshot)? requireCurrent,
  }) : _supabase = supabase ?? Supabase.instance.client,
       _captureOverride = captureAccount,
       _requireOverride = requireCurrent;

  final SupabaseClient _supabase;
  final AccountSnapshot Function()? _captureOverride;
  final void Function(AccountSnapshot)? _requireOverride;
  static const _networkTimeout = Duration(seconds: 15);

  AccountSnapshot _capture() {
    final account = _captureOverride?.call() ?? AccountContext.capture();
    _require(account);
    return account;
  }

  void _require(AccountSnapshot account) {
    if (_requireUserId() != account.userId) throw const StaleAccountWork();
    (_requireOverride ?? AccountContext.requireCurrent)(account);
  }

  String _requireUserId() {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null || userId.isEmpty) {
      throw const AuthException(message: 'Sign in to manage saved addresses.');
    }
    return userId;
  }

  Future<List<FavoriteAddress>> list({bool activeOnly = true}) async {
    final account = _capture();
    final userId = account.userId;

    try {
      var query = _supabase
          .from('favorite_addresses')
          .select()
          .eq('profile_id', userId);

      if (activeOnly) {
        query = query.eq('is_active', true);
      }

      final rows = await query
          .order('sort_order')
          .order('created_at')
          .timeout(_networkTimeout);
      _require(account);

      final addresses = (rows as List<dynamic>)
          .map(
            (row) =>
                FavoriteAddress.fromJson(Map<String, dynamic>.from(row as Map)),
          )
          .toList();
      if (addresses.any((address) => address.profileId != userId)) {
        throw const FormatException('Saved address owner mismatch');
      }
      return addresses;
    } on AppException {
      rethrow;
    } on Object catch (error, stackTrace) {
      _require(account);
      throw AppExceptionMapper.mapAndLog(
        error,
        stackTrace,
        'Error loading favorite addresses',
      );
    }
  }

  Future<FavoriteAddress> save({
    String? id,
    required String label,
    required String addressType,
    required PlaceDetails place,
    int sortOrder = 0,
  }) async {
    final account = _capture();
    final userId = account.userId;
    final addressId = id ?? newClientOperationId();
    final payload = {
      if (id == null) 'id': addressId,
      'profile_id': userId,
      'label': label.trim(),
      'address_type': addressType,
      'formatted_address': place.formattedAddress,
      'place_id': place.placeId,
      'latitude': place.latitude == 0 ? null : place.latitude,
      'longitude': place.longitude == 0 ? null : place.longitude,
      'sort_order': sortOrder,
      'is_active': true,
      'updated_at': DateTime.now().toIso8601String(),
    };

    try {
      final row = id == null
          ? await RequestDeadline.mutation(
              _supabase
                  .from('favorite_addresses')
                  .insert(payload)
                  .select()
                  .single(),
              operation: 'create_favorite_address',
              operationId: addressId,
              timeout: _networkTimeout,
            )
          : await RequestDeadline.mutation(
              _supabase
                  .from('favorite_addresses')
                  .update(payload)
                  .eq('id', id)
                  .eq('profile_id', userId)
                  .select()
                  .single(),
              operation: 'update_favorite_address',
              operationId: id,
              timeout: _networkTimeout,
            );

      _require(account);
      try {
        final address = FavoriteAddress.fromJson(
          Map<String, dynamic>.from(row as Map),
        );
        if (address.profileId != userId || address.id != addressId) {
          throw const FormatException('Saved address identity mismatch');
        }
        return address;
      } on Object catch (error, stackTrace) {
        throw MutationOutcomeUnknownException(
          operation: 'save_favorite_address',
          operationId: addressId,
          originalError: error,
          stackTrace: stackTrace,
        );
      }
    } on AppException {
      rethrow;
    } on Object catch (error, stackTrace) {
      _require(account);
      throw AppExceptionMapper.mapAndLog(
        error,
        stackTrace,
        'Error saving favorite address',
      );
    }
  }

  Future<void> delete(String id) async {
    final account = _capture();
    final userId = account.userId;

    try {
      await RequestDeadline.mutation(
        _supabase
            .from('favorite_addresses')
            .delete()
            .eq('id', id)
            .eq('profile_id', userId),
        operation: 'delete_favorite_address',
        operationId: id,
        timeout: _networkTimeout,
      );
      _require(account);
    } on AppException {
      rethrow;
    } on Object catch (error, stackTrace) {
      _require(account);
      throw AppExceptionMapper.mapAndLog(
        error,
        stackTrace,
        'Error deleting favorite address',
      );
    }
  }
}
