import 'package:mobi_app/core/utils/app_logger.dart';
import 'package:mobi_app/models/subscription_plan_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Admin & public service for driver platform access subscription tiers.
class SubscriptionPlanService {
  final SupabaseClient supabase;

  SubscriptionPlanService({required this.supabase});

  List<SubscriptionPlanModel>? _cached;

  static const _networkTimeout = Duration(seconds: 15);

  /// Fetch all plans.
  Future<List<SubscriptionPlanModel>> getAll({
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh && _cached != null) return _cached!;

    try {
      final rows = await supabase
          .from('subscription_plans')
          .select()
          .order('vehicle_type_id')
          .order('country_id')
          .order('interval_days')
          .timeout(_networkTimeout);

      final result = (rows as List<dynamic>)
          .map((r) => SubscriptionPlanModel.fromJson(r as Map<String, dynamic>))
          .toList();
      _cached = result;
      return result;
    } on Object catch (e) {
      AppLogger.error('Error fetching subscription plans: $e');
      rethrow;
    }
  }

  /// Get plans strictly for a matched vehicle and country.
  Future<List<SubscriptionPlanModel>> getAvailablePlans(
    String vehicleTypeId,
    String countryId,
  ) async {
    final all = await getAll();
    return all
        .where(
          (p) =>
              p.vehicleTypeId == vehicleTypeId &&
              p.countryId == countryId &&
              p.isActive,
        )
        .toList();
  }

  /// Admin upsert.
  Future<void> upsert({
    required String vehicleTypeId,
    required String countryId,
    required int intervalDays,
    required double price,
    required String currency,
    bool isActive = true,
  }) async {
    try {
      await supabase.from('subscription_plans').upsert({
        'vehicle_type_id': vehicleTypeId,
        'country_id': countryId,
        'interval_days': intervalDays,
        'price': price,
        'currency': currency,
        'is_active': isActive,
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'vehicle_type_id,country_id,interval_days');
      invalidateCache();
    } on Object catch (e) {
      AppLogger.error('Error upserting subscription plan: $e');
      rethrow;
    }
  }

  /// Toggle active state.
  Future<void> toggleActive(String id, bool isActive) async {
    try {
      await supabase
          .from('subscription_plans')
          .update({
            'is_active': isActive,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', id);
      invalidateCache();
    } on Object catch (e) {
      AppLogger.error('Error toggling subscription plan: $e');
      rethrow;
    }
  }

  /// Admin delete.
  Future<void> delete(String id) async {
    try {
      await supabase.from('subscription_plans').delete().eq('id', id);
      invalidateCache();
    } on Object catch (e) {
      AppLogger.error('Error deleting subscription plan: $e');
      rethrow;
    }
  }

  void invalidateCache() => _cached = null;
}
