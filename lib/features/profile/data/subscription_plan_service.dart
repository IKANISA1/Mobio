import 'package:mobi_app/core/utils/app_logger.dart';
import 'package:mobi_shared_types/models/subscription_plan_model.dart';
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

  Future<SubscriptionOperationsSnapshot> getOperationsSnapshot({
    int limit = 25,
  }) async {
    try {
      final cappedLimit = limit.clamp(1, 100).toInt();
      final results = await Future.wait([
        supabase
            .from('driver_subscription_payment_requests')
            .select(
              'id, profile_id, vehicle_type_id, payment_method, amount_rwf, '
              'amount_tokens, currency, reference_code, momo_pay_code, '
              'status, provider_transaction_ref, confirmation_source, '
              'created_at, confirmed_at, expires_at',
            )
            .order('created_at', ascending: false)
            .limit(cappedLimit)
            .timeout(_networkTimeout),
        supabase
            .from('driver_subscription_momo_sms_receipts')
            .select(
              'id, sender, received_at, amount_rwf, momo_pay_code, '
              'reference_code, payer_phone, provider_transaction_ref, '
              'matched_payment_request_id, status, created_at',
            )
            .order('received_at', ascending: false)
            .limit(cappedLimit)
            .timeout(_networkTimeout),
      ]);

      return SubscriptionOperationsSnapshot(
        paymentRequests: (results[0] as List<dynamic>)
            .whereType<Map<String, dynamic>>()
            .map(SubscriptionPaymentRequestOpsRow.fromJson)
            .toList(),
        smsReceipts: (results[1] as List<dynamic>)
            .whereType<Map<String, dynamic>>()
            .map(MomoSmsReceiptOpsRow.fromJson)
            .toList(),
      );
    } on Object catch (e) {
      AppLogger.error('Error fetching subscription operations: $e');
      rethrow;
    }
  }

  Future<int> expireStalePaymentRequests() async {
    try {
      final response = await supabase
          .rpc<dynamic>('rpc_admin_expire_driver_subscription_payment_requests')
          .timeout(_networkTimeout);
      final row = Map<String, dynamic>.from(response as Map);
      return (row['expired_count'] as num?)?.toInt() ?? 0;
    } on Object catch (e) {
      AppLogger.error('Error expiring subscription payment requests: $e');
      rethrow;
    }
  }

  Future<void> confirmMomoSmsReceipt({
    required String receiptId,
    String? reviewNote,
  }) async {
    try {
      await supabase
          .rpc<dynamic>(
            'rpc_admin_confirm_momo_sms_receipt',
            params: {'p_receipt_id': receiptId, 'p_review_note': reviewNote},
          )
          .timeout(_networkTimeout);
    } on Object catch (e) {
      AppLogger.error('Error confirming MoMo SMS receipt: $e');
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

class SubscriptionOperationsSnapshot {
  const SubscriptionOperationsSnapshot({
    required this.paymentRequests,
    required this.smsReceipts,
  });

  final List<SubscriptionPaymentRequestOpsRow> paymentRequests;
  final List<MomoSmsReceiptOpsRow> smsReceipts;
}

class SubscriptionPaymentRequestOpsRow {
  const SubscriptionPaymentRequestOpsRow({
    required this.id,
    required this.profileId,
    required this.vehicleTypeId,
    required this.paymentMethod,
    required this.amountRwf,
    required this.amountTokens,
    required this.currency,
    required this.referenceCode,
    required this.momoPayCode,
    required this.status,
    required this.providerTransactionRef,
    required this.confirmationSource,
    required this.createdAt,
    required this.confirmedAt,
    required this.expiresAt,
  });

  final String id;
  final String profileId;
  final String vehicleTypeId;
  final String paymentMethod;
  final int amountRwf;
  final int amountTokens;
  final String currency;
  final String referenceCode;
  final String momoPayCode;
  final String status;
  final String? providerTransactionRef;
  final String? confirmationSource;
  final DateTime? createdAt;
  final DateTime? confirmedAt;
  final DateTime? expiresAt;

  factory SubscriptionPaymentRequestOpsRow.fromJson(Map<String, dynamic> json) {
    return SubscriptionPaymentRequestOpsRow(
      id: json['id'] as String? ?? '',
      profileId: json['profile_id'] as String? ?? '',
      vehicleTypeId: json['vehicle_type_id'] as String? ?? '',
      paymentMethod: json['payment_method'] as String? ?? '',
      amountRwf: (json['amount_rwf'] as num?)?.toInt() ?? 0,
      amountTokens: (json['amount_tokens'] as num?)?.toInt() ?? 0,
      currency: json['currency'] as String? ?? 'RWF',
      referenceCode: json['reference_code'] as String? ?? '',
      momoPayCode: json['momo_pay_code'] as String? ?? '',
      status: json['status'] as String? ?? '',
      providerTransactionRef: json['provider_transaction_ref'] as String?,
      confirmationSource: json['confirmation_source'] as String?,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? ''),
      confirmedAt: DateTime.tryParse(json['confirmed_at'] as String? ?? ''),
      expiresAt: DateTime.tryParse(json['expires_at'] as String? ?? ''),
    );
  }
}

class MomoSmsReceiptOpsRow {
  const MomoSmsReceiptOpsRow({
    required this.id,
    required this.sender,
    required this.receivedAt,
    required this.amountRwf,
    required this.momoPayCode,
    required this.referenceCode,
    required this.payerPhone,
    required this.providerTransactionRef,
    required this.matchedPaymentRequestId,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String? sender;
  final DateTime? receivedAt;
  final int? amountRwf;
  final String momoPayCode;
  final String? referenceCode;
  final String? payerPhone;
  final String? providerTransactionRef;
  final String? matchedPaymentRequestId;
  final String status;
  final DateTime? createdAt;

  factory MomoSmsReceiptOpsRow.fromJson(Map<String, dynamic> json) {
    return MomoSmsReceiptOpsRow(
      id: json['id'] as String? ?? '',
      sender: json['sender'] as String?,
      receivedAt: DateTime.tryParse(json['received_at'] as String? ?? ''),
      amountRwf: (json['amount_rwf'] as num?)?.toInt(),
      momoPayCode: json['momo_pay_code'] as String? ?? '',
      referenceCode: json['reference_code'] as String?,
      payerPhone: json['payer_phone'] as String?,
      providerTransactionRef: json['provider_transaction_ref'] as String?,
      matchedPaymentRequestId: json['matched_payment_request_id'] as String?,
      status: json['status'] as String? ?? '',
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? ''),
    );
  }
}
