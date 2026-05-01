import 'package:mobi_app/models/vehicle_type_model.dart';
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

      final vtResponse = await query.order('sort_order');
      final vtRows = vtResponse as List<dynamic>;

      // Fetch country allocations
      final vtcResponse = await _supabase
          .from('vehicle_type_countries')
          .select();

      final vtcRows = vtcResponse as List<dynamic>;

      // Group country IDs by vehicle type
      final countryMap = <String, List<String>>{};
      for (final row in vtcRows) {
        final vtId = row['vehicle_type_id'] as String;
        final cId = row['country_id'] as String;
        countryMap.putIfAbsent(vtId, () => []).add(cId);
      }

      final result = vtRows.map((r) {
        final json = r as Map<String, dynamic>;
        final id = json['id'] as String? ?? '';
        return VehicleTypeModel.fromJson(json, countries: countryMap[id] ?? []);
      }).toList();

      if (includeInactive) {
        _cachedAll = result;
      } else {
        _cached = result;
      }

      return result;
    } on Object catch (_) {
      // Offline fallback
      const fallback = VehicleTypeModel.fallbackTypes;
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
    await _supabase
        .from('vehicle_types')
        .update(model.toJson())
        .eq('id', model.id);
    invalidateCache();
  }

  /// Update country allocations for a vehicle type (admin only).
  Future<void> updateCountries(
    String vehicleTypeId,
    List<String> countryIds,
  ) async {
    final client = _supabase;

    // Delete existing allocations
    await client
        .from('vehicle_type_countries')
        .delete()
        .eq('vehicle_type_id', vehicleTypeId);

    // Insert new allocations
    if (countryIds.isNotEmpty) {
      final rows = countryIds
          .map(
            (cId) => <String, dynamic>{
              'vehicle_type_id': vehicleTypeId,
              'country_id': cId,
            },
          )
          .toList();
      await client.from('vehicle_type_countries').insert(rows);
    }

    invalidateCache();
  }

  /// Toggle active status for a vehicle type (admin only).
  Future<void> toggleActive(String vehicleTypeId, bool isActive) async {
    await _supabase
        .from('vehicle_types')
        .update({'is_active': isActive})
        .eq('id', vehicleTypeId);
    invalidateCache();
  }
}
