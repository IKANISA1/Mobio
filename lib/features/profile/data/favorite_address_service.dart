import 'package:mobi_app/core/async/request_deadline.dart';
import 'package:mobi_app/core/errors/app_exception.dart';
import 'package:mobi_app/core/errors/app_exception_mapper.dart';
import 'package:mobi_shared_types/models/favorite_address.dart';
import 'package:mobi_shared_types/models/place.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthException;

class FavoriteAddressService {
  FavoriteAddressService({SupabaseClient? supabase})
    : _supabase = supabase ?? Supabase.instance.client;

  final SupabaseClient _supabase;
  static const _networkTimeout = Duration(seconds: 15);

  String _requireUserId() {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null || userId.isEmpty) {
      throw const AuthException(message: 'Sign in to manage saved addresses.');
    }
    return userId;
  }

  Future<List<FavoriteAddress>> list({bool activeOnly = true}) async {
    final userId = _requireUserId();

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

      return (rows as List<dynamic>)
          .map(
            (row) =>
                FavoriteAddress.fromJson(Map<String, dynamic>.from(row as Map)),
          )
          .toList();
    } on AppException {
      rethrow;
    } on Object catch (error, stackTrace) {
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
    final userId = _requireUserId();
    final payload = {
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

      return FavoriteAddress.fromJson(Map<String, dynamic>.from(row as Map));
    } on AppException {
      rethrow;
    } on Object catch (error, stackTrace) {
      throw AppExceptionMapper.mapAndLog(
        error,
        stackTrace,
        'Error saving favorite address',
      );
    }
  }

  Future<void> delete(String id) async {
    final userId = _requireUserId();

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
    } on AppException {
      rethrow;
    } on Object catch (error, stackTrace) {
      throw AppExceptionMapper.mapAndLog(
        error,
        stackTrace,
        'Error deleting favorite address',
      );
    }
  }
}
