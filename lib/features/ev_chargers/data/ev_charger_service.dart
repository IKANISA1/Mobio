import 'package:mobi_app/core/auth/admin_mutation_guard.dart';
import 'package:mobi_app/core/config/supabase_config.dart';
import 'package:mobi_app/core/errors/app_exception.dart';
import 'package:mobi_app/core/errors/app_exception_mapper.dart';
import 'package:mobi_app/features/ev_chargers/domain/ev_charger.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthException;

class EvChargerService {
  EvChargerService({this.supabase});

  final SupabaseClient? supabase;
  static const _networkTimeout = Duration(seconds: 15);
  static final _uuid = RegExp(
    r'^[0-9a-fA-F]{8}(-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}$',
  );

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
    if (supabase == null && SupabaseConfig.isLocalUiPreview) {
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

      return _requireRows(rows).map(_parseCharger).toList(growable: false);
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
    if (supabase == null && SupabaseConfig.isLocalUiPreview) {
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
      return _requireRows(rows).map(_parseCharger).toList(growable: false);
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
    final result = await AdminMutationGuard.run(
      _client.rpc(
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
      ),
      client: _client,
      operation: 'rpc_admin_upsert_ev_charger',
      operationId: id,
      timeout: _networkTimeout,
    );
    if (result is! String ||
        !_uuid.hasMatch(result) ||
        (id != null && result != id)) {
      throw MutationOutcomeUnknownException(
        operation: 'rpc_admin_upsert_ev_charger',
        operationId: id,
      );
    }
  }

  Future<void> setChargerActive(String id, bool isActive) async {
    await AdminMutationGuard.run(
      _client.rpc(
        'rpc_admin_set_ev_charger_active',
        params: {'p_charger_id': id, 'p_is_active': isActive},
      ),
      client: _client,
      operation: 'rpc_admin_set_ev_charger_active',
      operationId: id,
      timeout: _networkTimeout,
    );
  }

  List<Map<String, dynamic>> _requireRows(Object? raw) {
    if (raw is! List) throw const FormatException('Invalid EV charger list');
    return raw.map((row) {
      if (row is! Map) throw const FormatException('Invalid EV charger row');
      return Map<String, dynamic>.from(row);
    }).toList();
  }

  EvCharger _parseCharger(Map<String, dynamic> row) {
    final id = row['id'];
    final name = row['name'];
    final address = row['address'];
    final latitude = row['latitude'];
    final longitude = row['longitude'];
    final connectors = row['connector_types'];
    final active = row['is_active'];
    final distance = row['distance_km'];
    if (id is! String ||
        !_uuid.hasMatch(id) ||
        name is! String ||
        name.trim().isEmpty ||
        address is! String ||
        address.trim().isEmpty ||
        latitude is! num ||
        !latitude.toDouble().isFinite ||
        latitude < -90 ||
        latitude > 90 ||
        longitude is! num ||
        !longitude.toDouble().isFinite ||
        longitude < -180 ||
        longitude > 180 ||
        connectors is! List ||
        connectors.any((item) => item is! String) ||
        active is! bool ||
        (distance != null &&
            (distance is! num ||
                !distance.toDouble().isFinite ||
                distance < 0))) {
      throw const FormatException('Invalid EV charger response row');
    }
    return EvCharger.fromJson(row);
  }
}
