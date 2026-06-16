import 'package:mobi_app/models/wallet.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class WalletService {
  const WalletService({required this.supabase});

  final SupabaseClient supabase;
  static const _timeout = Duration(seconds: 15);

  Future<WalletSummary> getSummary() async {
    final response = await supabase
        .rpc<dynamic>('rpc_get_wallet_summary')
        .timeout(_timeout);
    return WalletSummary.fromJson(Map<String, dynamic>.from(response as Map));
  }

  Future<List<TokenLedgerEntry>> listLedger({int limit = 50}) async {
    final response = await supabase
        .rpc<dynamic>('rpc_list_token_ledger', params: {'p_limit': limit})
        .timeout(_timeout);
    final rows = response is List ? response : const [];
    return rows
        .whereType<Map<Object?, Object?>>()
        .map((row) => TokenLedgerEntry.fromJson(Map<String, dynamic>.from(row)))
        .toList();
  }

  Future<WalletTransferRecipient> lookupTransferRecipient({
    required String receiverMemberId,
  }) async {
    final response = await supabase
        .rpc<dynamic>(
          'rpc_lookup_wallet_transfer_recipient',
          params: {'p_receiver_member_id': receiverMemberId},
        )
        .timeout(_timeout);
    return WalletTransferRecipient.fromJson(
      Map<String, dynamic>.from(response as Map),
    );
  }

  Future<WalletTransferReceipt> transferTokens({
    required String receiverMemberId,
    required int amountTokens,
    required String idempotencyKey,
    String? note,
  }) async {
    final response = await supabase
        .rpc<dynamic>(
          'rpc_transfer_tokens',
          params: {
            'p_receiver_member_id': receiverMemberId,
            'p_amount_tokens': amountTokens,
            'p_note': note,
            'p_idempotency_key': idempotencyKey,
          },
        )
        .timeout(_timeout);
    return WalletTransferReceipt.fromJson(
      Map<String, dynamic>.from(response as Map),
    );
  }

  Future<WalletRedemptionReceipt> redeemTokens({
    required int amountTokens,
    required String idempotencyKey,
  }) async {
    final response = await supabase
        .rpc<dynamic>(
          'rpc_redeem_wallet_tokens',
          params: {
            'p_amount_tokens': amountTokens,
            'p_idempotency_key': idempotencyKey,
          },
        )
        .timeout(_timeout);
    return WalletRedemptionReceipt.fromJson(
      Map<String, dynamic>.from(response as Map),
    );
  }
}
