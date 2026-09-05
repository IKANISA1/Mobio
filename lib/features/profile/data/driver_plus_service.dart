import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
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
    final response = await supabase
        .rpc<dynamic>(
          'rpc_get_driver_plus_status',
          params: {'p_driver_id': driverId},
        )
        .timeout(_timeout);
    return DriverPlusStatus.fromJson(
      Map<String, dynamic>.from(response as Map),
    );
  }

  Future<DriverSubscriptionPaymentRequest> startSubscription({
    required String planId,
    required String paymentMethod,
    required String clientRequestId,
  }) async {
    final response = await supabase
        .rpc<dynamic>(
          'rpc_start_driver_subscription',
          params: {
            'p_plan_id': planId,
            'p_payment_method': paymentMethod,
            'p_client_request_id': clientRequestId,
          },
        )
        .timeout(_timeout);
    return DriverSubscriptionPaymentRequest.fromJson(
      Map<String, dynamic>.from(response as Map),
    );
  }

  Future<void> recordDialerOpened(String requestId) async {
    await supabase
        .rpc<dynamic>(
          'rpc_record_driver_subscription_dialer_opened',
          params: {'p_request_id': requestId},
        )
        .timeout(_timeout);
  }

  Future<bool> launchUssd(String ussdCode) async {
    final uri = ussdTelUri(ussdCode);
    if (defaultTargetPlatform == TargetPlatform.android) {
      final launched = await _launchAndroidNativeUssd(uri);
      if (launched) return true;
    }

    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Uri ussdTelUri(String ussdCode) {
    final encoded = ussdCode.replaceAll('#', Uri.encodeComponent('#'));
    return Uri.parse('tel:$encoded');
  }

  Future<bool> _launchAndroidNativeUssd(Uri uri) async {
    try {
      final response = await _androidUssdDialerChannel
          .invokeMapMethod<Object?, Object?>('launchUssd', {
            'uri': uri.toString(),
          });
      return response?['launched'] == true;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    } on Object {
      return false;
    }
  }
}
