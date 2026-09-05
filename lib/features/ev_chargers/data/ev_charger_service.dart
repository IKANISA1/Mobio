import 'package:mobi_app/core/config/supabase_config.dart';
import 'package:mobi_app/core/errors/app_exception.dart';
import 'package:mobi_app/core/errors/app_exception_mapper.dart';
import 'package:mobi_app/features/ev_chargers/domain/ev_charger.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthException;

class EvChargerService {
  EvChargerService({this.supabase});

  final SupabaseClient? supabase;
  static const _networkTimeout = Duration(seconds: 15);

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

  Future<List<EvCharger>> findNearestChargers({
    required double latitude,
    required double longitude,
    double radiusKm = 30,
    int limit = 5,
  }) async {
    if (SupabaseConfig.isLocalUiPreview) {
      return EvCharger.previewChargers(
        originLat: latitude,
        originLng: longitude,
      ).take(limit).toList(growable: false);
    }

    try {
      final rows = await _client
          .rpc(
            'rpc_find_nearest_ev_chargers',
            params: {
              'p_latitude': latitude,
              'p_longitude': longitude,
              'p_radius_km': radiusKm,
              'p_limit': limit,
            },
          )
          .timeout(_networkTimeout);

      return (rows as List<dynamic>)
          .whereType<Map<String, dynamic>>()
          .map(EvCharger.fromJson)
          .toList(growable: false);
    } on AppException {
      rethrow;
    } on Object catch (error, stackTrace) {
      throw AppExceptionMapper.mapAndLog(
        error,
        stackTrace,
        'Error finding EV chargers',
      );
    }
  }

  Future<List<EvCharger>> listChargers({bool includeInactive = false}) async {
    if (SupabaseConfig.isLocalUiPreview) {
      return EvCharger.previewChargers();
    }

    try {
      var query = _client
          .from('ev_chargers')
          .select(
            'id, name, address, latitude, longitude, connector_types, '
            'operator_name, phone, power_kw, price_note, place_id, is_active',
          );
      if (!includeInactive) {
        query = query.eq('is_active', true);
      }
      final rows = await query.order('name').timeout(_networkTimeout);
      return (rows as List<dynamic>)
          .whereType<Map<String, dynamic>>()
          .map(EvCharger.fromJson)
          .toList(growable: false);
    } on AppException {
      rethrow;
    } on Object catch (error, stackTrace) {
      throw AppExceptionMapper.mapAndLog(
        error,
        stackTrace,
        'Error listing EV chargers',
      );
    }
  }

  Future<void> upsertCharger({
    String? id,
    required String name,
    required String address,
    required double latitude,
    required double longitude,
    List<String> connectorTypes = const [],
    String? operatorName,
    String? phone,
    double? powerKw,
    String? priceNote,
    String? placeId,
    bool isActive = true,
  }) async {
    await _client
        .rpc(
          'rpc_admin_upsert_ev_charger',
          params: {
            'p_charger_id': id,
            'p_name': name,
            'p_address': address,
            'p_latitude': latitude,
            'p_longitude': longitude,
            'p_connector_types': connectorTypes,
            'p_operator_name': operatorName,
            'p_phone': phone,
            'p_power_kw': powerKw,
            'p_price_note': priceNote,
            'p_place_id': placeId,
            'p_is_active': isActive,
          },
        )
        .timeout(_networkTimeout);
  }

  Future<void> setChargerActive(String id, bool isActive) async {
    await _client
        .rpc(
          'rpc_admin_set_ev_charger_active',
          params: {'p_charger_id': id, 'p_is_active': isActive},
        )
        .timeout(_networkTimeout);
  }
}
