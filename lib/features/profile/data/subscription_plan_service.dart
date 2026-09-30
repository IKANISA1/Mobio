import 'package:mobi_app/core/async/request_deadline.dart';
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
        paymentRequests: _requireRows(
          results[0],
          'subscription requests',
        ).map(SubscriptionPaymentRequestOpsRow.fromJson).toList(),
        smsReceipts: _requireRows(
          results[1],
          'subscription SMS receipts',
        ).map(MomoSmsReceiptOpsRow.fromJson).toList(),
      );
    } on Object catch (e) {
      AppLogger.error('Error fetching subscription operations: $e');
      rethrow;
    }
  }

  Future<int> expireStalePaymentRequests() async {
    try {
      final response = await RequestDeadline.mutation(
        supabase.rpc<dynamic>(
          'rpc_admin_expire_driver_subscription_payment_requests',
        ),
        operation: 'rpc_admin_expire_driver_subscription_payment_requests',
        timeout: _networkTimeout,
      );
      final row = Map<String, dynamic>.from(response as Map);
      final count = row['expired_count'];
      if (count is! int || count < 0) {
        throw const FormatException('Invalid subscription expiry count');
      }
      return count;
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
      await RequestDeadline.mutation(
        supabase.rpc<dynamic>(
          'rpc_admin_confirm_momo_sms_receipt',
          params: {'p_receipt_id': receiptId, 'p_review_note': reviewNote},
        ),
        operation: 'rpc_admin_confirm_momo_sms_receipt',
        operationId: receiptId,
        timeout: _networkTimeout,
      );
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
      await RequestDeadline.mutation(
        supabase.rpc(
          'rpc_admin_upsert_subscription_plan',
          params: {
            'p_vehicle_type_id': vehicleTypeId,
            'p_country_id': countryId,
            'p_interval_days': intervalDays,
            'p_price': price,
            'p_currency': currency,
            'p_is_active': isActive,
          },
        ),
        operation: 'rpc_admin_upsert_subscription_plan',
        operationId: '$vehicleTypeId:$countryId:$intervalDays',
        timeout: _networkTimeout,
      );
      invalidateCache();
    } on Object catch (e) {
      AppLogger.error('Error upserting subscription plan: $e');
      invalidateCache();
      rethrow;
    }
  }

  /// Toggle active state.
  Future<void> toggleActive(String id, bool isActive) async {
    try {
      await RequestDeadline.mutation(
        supabase.rpc(
          'rpc_admin_set_subscription_plan_active',
          params: {'p_plan_id': id, 'p_is_active': isActive},
        ),
        operation: 'rpc_admin_set_subscription_plan_active',
        operationId: id,
        timeout: _networkTimeout,
      );
      invalidateCache();
    } on Object catch (e) {
      AppLogger.error('Error toggling subscription plan: $e');
      invalidateCache();
      rethrow;
    }
  }

  /// Admin delete.
  Future<void> delete(String id) async {
    try {
      await RequestDeadline.mutation(
        supabase.rpc(
          'rpc_admin_delete_subscription_plan',
          params: {'p_plan_id': id},
        ),
        operation: 'rpc_admin_delete_subscription_plan',
        operationId: id,
        timeout: _networkTimeout,
      );
      invalidateCache();
    } on Object catch (e) {
      AppLogger.error('Error deleting subscription plan: $e');
      invalidateCache();
      rethrow;
    }
  }

  void invalidateCache() => _cached = null;

  List<Map<String, dynamic>> _requireRows(Object? raw, String operation) {
    if (raw is! List) throw FormatException('Invalid $operation response');
    return raw.map((row) {
      if (row is! Map) throw FormatException('Invalid $operation row');
      return Map<String, dynamic>.from(row);
    }).toList();
  }
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
    final id = json['id'];
    final profileId = json['profile_id'];
    final vehicleTypeId = json['vehicle_type_id'];
    final paymentMethod = json['payment_method'];
    final amountRwf = json['amount_rwf'];
    final amountTokens = json['amount_tokens'];
    final currency = json['currency'];
    final referenceCode = json['reference_code'];
    final momoPayCode = json['momo_pay_code'];
    final status = json['status'];
    final createdAt = DateTime.tryParse(json['created_at'] as String? ?? '');
    final expiresAt = DateTime.tryParse(json['expires_at'] as String? ?? '');
    if (id is! String ||
        id.isEmpty ||
        profileId is! String ||
        profileId.isEmpty ||
        vehicleTypeId is! String ||
        vehicleTypeId.isEmpty ||
        !const {'tokens', 'momo_ussd'}.contains(paymentMethod) ||
        amountRwf is! int ||
        amountRwf <= 0 ||
        amountTokens is! int ||
        amountTokens <= 0 ||
        currency != 'RWF' ||
        referenceCode is! String ||
        referenceCode.isEmpty ||
        momoPayCode is! String ||
        momoPayCode.isEmpty ||
        !const {
          'pending',
          'dialer_opened',
          'confirmed',
          'expired',
          'cancelled',
          'failed',
        }.contains(status) ||
        createdAt == null ||
        expiresAt == null) {
      throw const FormatException('Invalid subscription request row');
    }
    return SubscriptionPaymentRequestOpsRow(
      id: id,
      profileId: profileId,
      vehicleTypeId: vehicleTypeId,
      paymentMethod: paymentMethod as String,
      amountRwf: amountRwf,
      amountTokens: amountTokens,
      currency: currency as String,
      referenceCode: referenceCode,
      momoPayCode: momoPayCode,
      status: status as String,
      providerTransactionRef: json['provider_transaction_ref'] as String?,
      confirmationSource: json['confirmation_source'] as String?,
      createdAt: createdAt,
      confirmedAt: DateTime.tryParse(json['confirmed_at'] as String? ?? ''),
      expiresAt: expiresAt,
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
    final id = json['id'];
    final momoPayCode = json['momo_pay_code'];
    final status = json['status'];
    final amountRwf = json['amount_rwf'];
    final createdAt = DateTime.tryParse(json['created_at'] as String? ?? '');
    if (id is! String ||
        id.isEmpty ||
        momoPayCode is! String ||
        momoPayCode.isEmpty ||
        status is! String ||
        status.isEmpty ||
        (amountRwf != null && (amountRwf is! int || amountRwf <= 0)) ||
        createdAt == null) {
      throw const FormatException('Invalid subscription SMS receipt row');
    }
    return MomoSmsReceiptOpsRow(
      id: id,
      sender: json['sender'] as String?,
      receivedAt: DateTime.tryParse(json['received_at'] as String? ?? ''),
      amountRwf: amountRwf as int?,
      momoPayCode: momoPayCode,
      referenceCode: json['reference_code'] as String?,
      payerPhone: json['payer_phone'] as String?,
      providerTransactionRef: json['provider_transaction_ref'] as String?,
      matchedPaymentRequestId: json['matched_payment_request_id'] as String?,
      status: status,
      createdAt: createdAt,
    );
  }
}
