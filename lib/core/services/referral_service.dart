import 'package:mobi_app/models/wallet.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ReferralService {
  const ReferralService({required this.supabase});

  final SupabaseClient supabase;
  static const _timeout = Duration(seconds: 15);

  Future<ReferralCode> getOrCreateCode() async {
    final response = await supabase
        .rpc<dynamic>('rpc_get_or_create_referral_code')
        .timeout(_timeout);
    return ReferralCode.fromJson(Map<String, dynamic>.from(response as Map));
  }

  Future<void> recordOpen({
    required String code,
    String? platform,
    Map<String, dynamic> metadata = const {},
  }) async {
    await supabase
        .rpc<dynamic>(
          'rpc_record_referral_open',
          params: {
            'p_code': code,
            'p_platform': platform,
            'p_metadata': metadata,
          },
        )
        .timeout(_timeout);
  }

  Future<void> completeSignup({
    required String code,
    String? installId,
    String? deviceHash,
    Map<String, dynamic> metadata = const {},
  }) async {
    await supabase
        .rpc<dynamic>(
          'rpc_complete_referral_signup',
          params: {
            'p_code': code,
            'p_install_id': installId,
            'p_device_hash': deviceHash,
            'p_metadata': metadata,
          },
        )
        .timeout(_timeout);
  }
}
