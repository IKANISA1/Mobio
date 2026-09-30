import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:mobi_app/core/async/request_deadline.dart';
import 'package:mobi_app/core/errors/app_exception.dart';
import 'package:mobi_app/features/profile/domain/wallet.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class DriverPlusService {
  const DriverPlusService({required this.supabase});

  final SupabaseClient supabase;
  static const _timeout = Duration(seconds: 15);
  static const _androidUssdDialerChannel = MethodChannel(
    'rw.mobi.app/biopay_ussd_dialer',
  );

  Future<DriverPlusStatus> getStatus({String? driverId}) async {
    final expectedDriverId = driverId ?? supabase.auth.currentUser?.id;
    final response = await RequestDeadline.read(
      supabase.rpc<dynamic>(
        'rpc_get_driver_plus_status',
        params: {'p_driver_id': driverId},
      ),
      timeout: _timeout,
    );
    final status = DriverPlusStatus.fromJson(
      Map<String, dynamic>.from(response as Map),
    );
    if (expectedDriverId == null || status.driverId != expectedDriverId) {
      throw const FormatException('Driver Plus identity mismatch');
    }
    return status;
  }

  Future<DriverSubscriptionPaymentRequest> startSubscription({
    required String planId,
    required String paymentMethod,
    required String clientRequestId,
  }) async {
    final response = await RequestDeadline.mutation(
      supabase.rpc<dynamic>(
        'rpc_start_driver_subscription',
        params: {
          'p_plan_id': planId,
          'p_payment_method': paymentMethod,
          'p_client_request_id': clientRequestId,
        },
      ),
      operation: 'rpc_start_driver_subscription',
      operationId: clientRequestId,
      timeout: _timeout,
    );
    try {
      final request = DriverSubscriptionPaymentRequest.fromJson(
        Map<String, dynamic>.from(response as Map),
      );
      if (request.paymentMethod != paymentMethod)
        throw const FormatException('Subscription payment method mismatch');
      return request;
    } on Object catch (error, stackTrace) {
      throw MutationOutcomeUnknownException(
        operation: 'rpc_start_driver_subscription',
        operationId: clientRequestId,
        originalError: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> recordDialerOpened(String requestId) async {
    await RequestDeadline.mutation(
      supabase.rpc<dynamic>(
        'rpc_record_driver_subscription_dialer_opened',
        params: {'p_request_id': requestId},
      ),
      operation: 'rpc_record_driver_subscription_dialer_opened',
      operationId: requestId,
      timeout: _timeout,
    );
  }

  Future<bool> launchUssd(String ussdCode) async {
    final uri = ussdTelUri(ussdCode);
    if (defaultTargetPlatform == TargetPlatform.android) {
      final launched = await _launchAndroidNativeUssd(uri);
      if (launched) return true;
    }

    return RequestDeadline.mutation(
      launchUrl(uri, mode: LaunchMode.externalApplication),
      operation: 'open_driver_subscription_ussd',
      timeout: const Duration(seconds: 10),
    );
  }

  Uri ussdTelUri(String ussdCode) {
    final encoded = ussdCode.replaceAll('#', Uri.encodeComponent('#'));
    return Uri.parse('tel:$encoded');
  }

  Future<bool> _launchAndroidNativeUssd(Uri uri) async {
    try {
      final response = await RequestDeadline.mutation(
        _androidUssdDialerChannel.invokeMapMethod<Object?, Object?>(
          'launchUssd',
          {'uri': uri.toString()},
        ),
        operation: 'open_driver_subscription_ussd_native',
        timeout: const Duration(seconds: 10),
      );
      return response?['launched'] == true;
    } on MutationOutcomeUnknownException {
      rethrow;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    } on Object {
      return false;
    }
  }
}
