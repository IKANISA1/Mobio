import 'package:mobi_app/core/async/request_deadline.dart';
import 'package:mobi_app/core/async/account_epoch.dart';
import 'package:mobi_app/core/auth/account_context.dart';
import 'package:mobi_app/features/profile/domain/wallet.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ReferralService {
  const ReferralService({
    required this.supabase,
    AccountSnapshot Function()? captureAccount,
    void Function(AccountSnapshot)? requireCurrent,
  }) : _captureOverride = captureAccount,
       _requireOverride = requireCurrent;

  final SupabaseClient supabase;
  final AccountSnapshot Function()? _captureOverride;
  final void Function(AccountSnapshot)? _requireOverride;
  static const _timeout = Duration(seconds: 15);

  AccountSnapshot _capture() {
    final account = _captureOverride?.call() ?? AccountContext.capture();
    _require(account);
    return account;
  }

  void _require(AccountSnapshot account) {
    if (supabase.auth.currentUser?.id != account.userId)
      throw const StaleAccountWork();
    (_requireOverride ?? AccountContext.requireCurrent)(account);
  }

  Future<ReferralCode> getOrCreateCode() async {
    final account = _capture();
    final response = await RequestDeadline.mutation(
      supabase.rpc<dynamic>('rpc_get_or_create_referral_code'),
      operation: 'rpc_get_or_create_referral_code',
      operationId: supabase.auth.currentUser?.id,
      timeout: _timeout,
    );
    _require(account);
    return ReferralCode.fromJson(Map<String, dynamic>.from(response as Map));
  }

  Future<void> recordOpen({
    required String code,
    String? platform,
    Map<String, dynamic> metadata = const {},
  }) async {
    await RequestDeadline.mutation(
      supabase.rpc<dynamic>(
        'rpc_record_referral_open',
        params: {
          'p_code': code,
          'p_platform': platform,
          'p_metadata': metadata,
        },
      ),
      operation: 'rpc_record_referral_open',
      operationId: code,
      timeout: _timeout,
    );
  }

  Future<void> completeSignup({
    required String code,
    String? installId,
    String? deviceHash,
    Map<String, dynamic> metadata = const {},
  }) async {
    final account = _capture();
    await RequestDeadline.mutation(
      supabase.rpc<dynamic>(
        'rpc_complete_referral_signup',
        params: {
          'p_code': code,
          'p_install_id': installId,
          'p_device_hash': deviceHash,
          'p_metadata': metadata,
        },
      ),
      operation: 'rpc_complete_referral_signup',
      operationId: installId ?? code,
      timeout: _timeout,
    );
    _require(account);
  }
}
