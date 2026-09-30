import 'dart:async';
import 'package:mobi_app/core/auth/account_context.dart';
import 'package:mobi_app/features/profile/data/wallet_operation_journal.dart';
import 'package:mobi_app/features/profile/domain/wallet_operation.dart';
import 'package:mobi_app/features/profile/domain/wallet.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class WalletService {
  const WalletService({required this.supabase});

  final SupabaseClient supabase;
  static const _timeout = Duration(seconds: 15);

  Future<WalletSummary> getSummary() async {
    final account=AccountContext.capture();
    final response = await supabase
        .rpc<dynamic>('rpc_get_wallet_summary')
        .timeout(_timeout);
    AccountContext.requireCurrent(account);
    return WalletSummary.fromJson(Map<String, dynamic>.from(response as Map));
  }

  Future<List<TokenLedgerEntry>> listLedger({int limit = 50}) async {
    final account=AccountContext.capture();
    final response = await supabase
        .rpc<dynamic>('rpc_list_token_ledger', params: {'p_limit': limit})
        .timeout(_timeout);
    AccountContext.requireCurrent(account);
    final rows = response is List ? response : const [];
    return rows
        .whereType<Map<Object?, Object?>>()
        .map((row) => TokenLedgerEntry.fromJson(Map<String, dynamic>.from(row)))
        .toList();
  }

  Future<WalletTransferRecipient> lookupTransferRecipient({
    required String receiverMemberId,
  }) async {
    final account=AccountContext.capture();
    final response = await supabase
        .rpc<dynamic>(
          'rpc_lookup_wallet_transfer_recipient',
          params: {'p_receiver_member_id': receiverMemberId},
        )
        .timeout(_timeout);
    AccountContext.requireCurrent(account);
    return WalletTransferRecipient.fromLookupJson(
      Map<String, dynamic>.from(response as Map),
      requestedMemberId: receiverMemberId,
    );
  }

  Future<WalletOperationRecord?> activeOperation() async {
    final account=AccountContext.capture();
    final response=await supabase.rpc<dynamic>('rpc_wallet_operation_status').timeout(_timeout);
    AccountContext.requireCurrent(account);
    if(response is Map && response['status']=='not_observed')return null;
    return WalletOperationRecord.fromJson(Map<String,dynamic>.from(response as Map),ownerId:account.userId);
  }

  Future<WalletOperationRecord> _execute({required String operationId,required String kind,
    required int amountTokens,String? receiverMemberId,String? note}) async {
    final account=AccountContext.capture();
    var durableId=operationId;
    try {
      await WalletOperationJournal.assertNoUnattributedLegacyRequest().timeout(const Duration(seconds:4));
      AccountContext.requireCurrent(account);
      final prepared=await supabase.rpc<dynamic>('rpc_prepare_wallet_operation',params:{
        'p_operation_id':operationId,'p_kind':kind,'p_amount_tokens':amountTokens,
        'p_receiver_member_id':receiverMemberId,'p_note':note,
      }).timeout(_timeout);
      AccountContext.requireCurrent(account);
      final operation=WalletOperationRecord.fromJson(Map<String,dynamic>.from(prepared as Map),ownerId:account.userId);
      durableId=operation.operationId;
      if(operation.kind!=kind||operation.amountTokens!=amountTokens||operation.receiverMemberId!=receiverMemberId) {
        throw StateError('WALLET_OPERATION_CONFLICT');
      }
      // A lost preparation response creates no financial effect. The server
      // returns the same unresolved operation on the next preparation request.
      await WalletOperationJournal.save(operation).timeout(const Duration(seconds:4));
      AccountContext.requireCurrent(account);
      if(operation.committed)return operation;
      if(operation.status!='prepared')throw StateError('WALLET_OPERATION_CLOSED');
      final executed=await supabase.rpc<dynamic>('rpc_execute_wallet_operation',
        params:{'p_operation_id':durableId}).timeout(_timeout);
      AccountContext.requireCurrent(account);
      final result=WalletOperationRecord.fromJson(Map<String,dynamic>.from(executed as Map),ownerId:account.userId);
      if(result.operationId!=durableId||!result.committed)throw StateError('INVALID_WALLET_RECEIPT');
      return result;
    } on TimeoutException {
      // A deadline does NOT cancel the server transaction. Preserve the pointer
      // and reconcile through status. Do not automatically execute another ID.
      throw UnknownWalletOutcome(durableId);
    }
  }
  Future<WalletOperationResult<WalletTransferReceipt>> transferOperation({
    required String receiverMemberId,required int amountTokens,required String idempotencyKey,String? note}) async {
    final operation=await _execute(operationId:idempotencyKey,kind:'transfer',
      amountTokens:amountTokens,receiverMemberId:receiverMemberId,note:note?.trim());
    return WalletOperationResult(operation,WalletTransferReceipt.fromJson(operation.receipt!));
  }
  Future<WalletOperationResult<WalletRedemptionReceipt>> redemptionOperation({
    required int amountTokens,required String idempotencyKey}) async {
    final operation=await _execute(operationId:idempotencyKey,kind:'redeem',amountTokens:amountTokens);
    return WalletOperationResult(operation,WalletRedemptionReceipt.fromJson(operation.receipt!));
  }
  // Existing API signatures remain available; closing a receipt is deliberately
  // explicit and never automatic inside these compatibility methods.
  Future<WalletTransferReceipt> transferTokens({required String receiverMemberId,
    required int amountTokens,required String idempotencyKey,String? note}) async =>
    (await transferOperation(receiverMemberId:receiverMemberId,amountTokens:amountTokens,
      idempotencyKey:idempotencyKey,note:note)).value;
  Future<WalletRedemptionReceipt> redeemTokens({required int amountTokens,required String idempotencyKey}) async =>
    (await redemptionOperation(amountTokens:amountTokens,idempotencyKey:idempotencyKey)).value;
  Future<void> closeOperation(WalletOperationRecord operation,{required bool cancel}) async {
    final account=AccountContext.capture();
    if(account.userId!=operation.ownerId)throw StateError('ACCOUNT_CHANGED');
    final response=await supabase.rpc<dynamic>('rpc_close_wallet_operation',params:{
      'p_operation_id':operation.operationId,'p_action':cancel?'cancel':'acknowledge',
    }).timeout(_timeout);
    AccountContext.requireCurrent(account);
    final result=WalletOperationRecord.fromJson(Map<String,dynamic>.from(response as Map),ownerId:account.userId);
    if(result.operationId!=operation.operationId||!result.acknowledged)throw StateError('WALLET_CLOSE_UNCONFIRMED');
    // If local cleanup fails, the server still retains the prior closed receipt.
    // A later server read remains authoritative; never claim the transfer failed.
    try{await WalletOperationJournal.clear(account.userId,operation.operationId);}
    on Object{ /* Stale local pointers cannot open a new server operation. */ }
  }
}
