import 'package:mobi_app/core/auth/admin_mutation_guard.dart';
import 'package:mobi_app/core/async/request_deadline.dart';
import 'package:mobi_app/shared/models/vehicle_type_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Service for fetching vehicle types from Supabase `vehicle_types` table.
///
/// Caches the result in memory after first fetch. Falls back to
/// hardcoded list if Supabase is unreachable.
class VehicleTypeService {
  final SupabaseClient _supabase;

  VehicleTypeService({SupabaseClient? supabase})
    : _supabase = supabase ?? Supabase.instance.client;

  List<VehicleTypeModel>? _cached;
  List<VehicleTypeModel>? _cachedAll;

  /// Get vehicle types, sorted by sort_order.
  ///
  /// By default only returns active types. Pass [includeInactive] = true
  /// for admin screens that need to see everything.
  Future<List<VehicleTypeModel>> getAll({bool includeInactive = false}) async {
    if (!includeInactive && _cached != null) return _cached!;
    if (includeInactive && _cachedAll != null) return _cachedAll!;

    try {
      // Fetch vehicle types
      var query = _supabase.from('vehicle_types').select();

      if (!includeInactive) {
        query = query.eq('is_active', true);
      }

      final vtResponse = await RequestDeadline.read(query.order('sort_order'));
      final vtRows = vtResponse as List<dynamic>;

      // Fetch country allocations
      final vtcResponse = await RequestDeadline.read(
        _supabase.from('vehicle_type_countries').select(),
      );

      final vtcRows = vtcResponse as List<dynamic>;

      // Group country IDs by vehicle type
      final countryMap = <String, List<String>>{};
      for (final row in vtcRows) {
        final vtId = row['vehicle_type_id'] as String;
        final cId = row['country_id'] as String;
        countryMap.putIfAbsent(vtId, () => []).add(cId);
      }

      final result = VehicleTypeModel.ordered(
        vtRows.map((r) {
          final json = r as Map<String, dynamic>;
          final id = json['id'] as String? ?? '';
          return VehicleTypeModel.fromJson(
            json,
            countries: countryMap[id] ?? [],
          );
        }),
      );

      if (includeInactive) {
        _cachedAll = result;
      } else {
        _cached = result;
      }

      return result;
    } on Object catch (_) {
      // Offline fallback
      final fallback = VehicleTypeModel.ordered(VehicleTypeModel.fallbackTypes);
      _cached = fallback;
      return fallback;
    }
  }

  /// Get vehicle types available in a specific country.
  Future<List<VehicleTypeModel>> getForCountry(String countryId) async {
    final all = await getAll();
    return all.where((vt) {
      // If no country restrictions, show everywhere
      if (vt.countryIds.isEmpty) return true;
      return vt.countryIds.contains(countryId);
    }).toList();
  }

  /// Find a vehicle type by ID.
  Future<VehicleTypeModel?> findById(String id) async {
    final all = await getAll();
    final matches = all.where((vt) => vt.id == id);
    return matches.isNotEmpty ? matches.first : null;
  }

  /// Clear cache (e.g. after admin updates).
  void invalidateCache() {
    _cached = null;
    _cachedAll = null;
  }

  /// Pre-warm the cache on app startup.
  Future<void> warmCache() async {
    await getAll();
  }

  /// Update a vehicle type (admin only).
  Future<void> update(VehicleTypeModel model) async {
    await AdminMutationGuard.run(
      _supabase.rpc(
        'rpc_admin_update_vehicle_type',
        params: {
          'p_vehicle_type_id': model.id,
          'p_label': model.label,
          'p_icon_name': model.iconName,
          'p_image_url': model.imageUrl,
          'p_sort_order': model.sortOrder,
          'p_is_active': model.isActive,
        },
      ),
      client: _supabase,
      operation: 'rpc_admin_update_vehicle_type',
      operationId: model.id,
    );
    invalidateCache();
  }

  /// Update country allocations for a vehicle type (admin only).
  Future<void> updateCountries(
    String vehicleTypeId,
    List<String> countryIds,
  ) async {
    await AdminMutationGuard.run(
      _supabase.rpc(
        'rpc_admin_set_vehicle_type_countries',
        params: {
          'p_vehicle_type_id': vehicleTypeId,
          'p_country_ids': countryIds,
        },
      ),
      client: _supabase,
      operation: 'rpc_admin_set_vehicle_type_countries',
      operationId: vehicleTypeId,
    );

    invalidateCache();
  }

  /// Toggle active status for a vehicle type (admin only).
  Future<void> toggleActive(String vehicleTypeId, bool isActive) async {
    await AdminMutationGuard.run(
      _supabase.rpc(
        'rpc_admin_set_vehicle_type_active',
        params: {'p_vehicle_type_id': vehicleTypeId, 'p_is_active': isActive},
      ),
      client: _supabase,
      operation: 'rpc_admin_set_vehicle_type_active',
      operationId: vehicleTypeId,
    );
    invalidateCache();
  }
}
