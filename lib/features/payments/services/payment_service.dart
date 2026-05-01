import 'package:mobi_app/core/utils/app_logger.dart';
import 'package:mobi_app/features/payments/models/payment_intent.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PaymentService {
  PaymentService({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  final SupabaseClient _supabase;

  Future<PaymentIntent> createIntent({
    required String payeeId,
    String? tripId,
    required double amount,
    required String currency,
    required String paymentMethod,
  }) async {
    try {
      final response = await _supabase.functions.invoke(
        'create-payment-intent',
        body: {
          'payee_id': payeeId,
          'trip_id': tripId,
          'amount': amount,
          'currency': currency,
          'payment_method': paymentMethod,
        },
      );

      if (response.status != 200) {
        throw Exception('Failed to create payment intent: ${response.data}');
      }

      return PaymentIntent.fromJson(response.data as Map<String, dynamic>);
    } catch (e, stackTrace) {
      AppLogger.error('PaymentService.createIntent failed: $e', e, stackTrace);
      rethrow;
    }
  }

  Future<PaymentIntent> verifyStatus(String intentId) async {
    try {
      final response = await _supabase.functions.invoke(
        'verify-payment-status',
        method: HttpMethod.get,
        queryParameters: {'intent_id': intentId},
      );

      if (response.status != 200) {
        throw Exception('Failed to verify payment status: ${response.data}');
      }

      return PaymentIntent.fromJson(response.data as Map<String, dynamic>);
    } catch (e, stackTrace) {
      AppLogger.error('PaymentService.verifyStatus failed: $e', e, stackTrace);
      rethrow;
    }
  }

  Stream<PaymentIntent> watchIntent(String intentId) {
    return _supabase
        .from('payment_intents')
        .stream(primaryKey: ['id'])
        .eq('id', intentId)
        .map((data) => PaymentIntent.fromJson(data.first));
  }
}
