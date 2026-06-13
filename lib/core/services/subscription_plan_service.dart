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
      await supabase.rpc(
        'rpc_admin_upsert_subscription_plan',
        params: {
          'p_vehicle_type_id': vehicleTypeId,
          'p_country_id': countryId,
          'p_interval_days': intervalDays,
          'p_price': price,
          'p_currency': currency,
          'p_is_active': isActive,
        },
      );
      invalidateCache();
    } on Object catch (e) {
      AppLogger.error('Error upserting subscription plan: $e');
      rethrow;
    }
  }

  /// Toggle active state.
  Future<void> toggleActive(String id, bool isActive) async {
    try {
      await supabase.rpc(
        'rpc_admin_set_subscription_plan_active',
        params: {'p_plan_id': id, 'p_is_active': isActive},
      );
      invalidateCache();
    } on Object catch (e) {
      AppLogger.error('Error toggling subscription plan: $e');
      rethrow;
    }
  }

  /// Admin delete.
  Future<void> delete(String id) async {
    try {
      await supabase.rpc(
        'rpc_admin_delete_subscription_plan',
        params: {'p_plan_id': id},
      );
      invalidateCache();
    } on Object catch (e) {
      AppLogger.error('Error deleting subscription plan: $e');
      rethrow;
    }
  }

  void invalidateCache() => _cached = null;
}
