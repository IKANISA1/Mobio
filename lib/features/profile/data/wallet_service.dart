import 'dart:async';
import 'package:mobi_app/core/async/request_deadline.dart';
import 'package:mobi_app/core/auth/account_context.dart';
import 'package:mobi_app/features/profile/data/wallet_operation_journal.dart';
import 'package:mobi_app/features/profile/domain/wallet.dart';
import 'package:mobi_app/features/profile/domain/wallet_operation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class WalletAuthority {
  const WalletAuthority({required this.userId, required this.requireCurrent});
  final String userId;
  final void Function() requireCurrent;
}

class WalletService {
  const WalletService({
    required this.supabase,
    WalletAuthority Function()? captureAuthority,
  }) : _captureOverride = captureAuthority;

  final SupabaseClient supabase;
  final WalletAuthority Function()? _captureOverride;

  WalletAuthority _captureAuthority() {
    final override = _captureOverride;
    if (override != null) return override();
    final snapshot = AccountContext.capture();
    if (supabase.auth.currentUser?.id != snapshot.userId) {
      throw const FormatException('Wallet client owner mismatch');
    }
    return WalletAuthority(
      userId: snapshot.userId,
      requireCurrent: () => AccountContext.requireCurrent(snapshot),
    );
  }

  WalletOperationRecord _parseOperation(
    Object? raw, {
    required String ownerId,
  }) {
    final operation = WalletOperationRecord.fromJson(
      WalletWireRecord.object(raw),
      ownerId: ownerId,
    );
    if (operation.committed) {
      if (operation.kind == 'transfer') {
        final receipt = WalletTransferReceipt.fromJson(operation.receipt!);
        if (receipt.status != 'completed') {
          throw const FormatException('Invalid committed wallet transfer');
        }
      } else {
        final receipt = WalletRedemptionReceipt.fromJson(operation.receipt!);
        if (receipt.amountTokens != operation.amountTokens ||
            receipt.amountRwf != operation.amountTokens) {
          throw const FormatException('Wallet redemption amount mismatch');
        }
      }
    }
    return operation;
  }

  static const _timeout = Duration(seconds: 15);

  Future<WalletSummary> getSummary() async {
    final account = _captureAuthority();
    final response = await supabase
        .rpc<dynamic>('rpc_get_wallet_summary')
        .timeout(_timeout);
    account.requireCurrent();
    return WalletSummary.fromJson(
      WalletWireRecord.object(response),
      expectedProfileId: account.userId,
    );
  }

  Future<List<TokenLedgerEntry>> listLedger({int limit = 50}) async {
    final account = _captureAuthority();
    final response = await supabase
        .rpc<dynamic>('rpc_list_token_ledger', params: {'p_limit': limit})
        .timeout(_timeout);
    account.requireCurrent();
    return WalletWireRecord.rows(response)
        .map(
          (row) =>
              TokenLedgerEntry.fromJson(row, expectedProfileId: account.userId),
        )
        .toList(growable: false);
  }

  Future<WalletTransferRecipient> lookupTransferRecipient({
    required String receiverMemberId,
  }) async {
    final account = _captureAuthority();
    final response = await supabase
        .rpc<dynamic>(
          'rpc_lookup_wallet_transfer_recipient',
          params: {'p_receiver_member_id': receiverMemberId},
        )
        .timeout(_timeout);
    account.requireCurrent();
    return WalletTransferRecipient.fromLookupJson(
      WalletWireRecord.object(response),
      requestedMemberId: receiverMemberId,
    );
  }

  Future<WalletOperationRecord?> activeOperation() async {
    final account = _captureAuthority();
    final response = await supabase
        .rpc<dynamic>('rpc_wallet_operation_status')
        .timeout(_timeout);
    account.requireCurrent();
    final row = WalletWireRecord.object(response);
    if (row['status'] == 'not_observed') return null;
    return _parseOperation(row, ownerId: account.userId);
  }

  Future<WalletOperationRecord> _execute({
    required String operationId,
    required String kind,
    required int amountTokens,
    String? receiverMemberId,
    String? note,
  }) async {
    final account = _captureAuthority();
    var durableId = operationId;
    var executionAcknowledged = false;
    try {
      await WalletOperationJournal.assertNoUnattributedLegacyRequest().timeout(
        const Duration(seconds: 4),
      );
      account.requireCurrent();
      final prepared = await supabase
          .rpc<dynamic>(
            'rpc_prepare_wallet_operation',
            params: {
              'p_operation_id': operationId,
              'p_kind': kind,
              'p_amount_tokens': amountTokens,
              'p_receiver_member_id': receiverMemberId,
              'p_note': note,
            },
          )
          .timeout(_timeout);
      account.requireCurrent();
      final operation = _parseOperation(prepared, ownerId: account.userId);
      durableId = operation.operationId;
      if (operation.kind != kind ||
          operation.amountTokens != amountTokens ||
          operation.receiverMemberId != receiverMemberId) {
        throw StateError('WALLET_OPERATION_CONFLICT');
      }
      // A lost preparation response creates no financial effect. The server
      // returns the same unresolved operation on the next preparation request.
      await WalletOperationJournal.save(
        operation,
      ).timeout(const Duration(seconds: 4));
      account.requireCurrent();
      if (operation.committed) return operation;
      if (operation.status != 'prepared') {
        throw StateError('WALLET_OPERATION_CLOSED');
      }
      final executed = await supabase
          .rpc<dynamic>(
            'rpc_execute_wallet_operation',
            params: {'p_operation_id': durableId},
          )
          .timeout(_timeout);
      account.requireCurrent();
      executionAcknowledged = true;
      final result = _parseOperation(executed, ownerId: account.userId);
      if (result.operationId != durableId ||
          !result.committed ||
          result.kind != operation.kind ||
          result.amountTokens != operation.amountTokens ||
          result.receiverMemberId != operation.receiverMemberId) {
        throw StateError('INVALID_WALLET_RECEIPT');
      }
      return result;
    } on Object catch (error) {
      if (!executionAcknowledged && !RequestDeadline.responseWasLost(error)) {
        rethrow;
      }
      // A deadline does NOT cancel the server transaction. Preserve the pointer
      // after any lost response and reconcile through status. Do not
      // automatically execute another ID.
      throw UnknownWalletOutcome(durableId);
    }
  }

  Future<WalletOperationResult<WalletTransferReceipt>> transferOperation({
    required String receiverMemberId,
    required int amountTokens,
    required String idempotencyKey,
    String? note,
  }) async {
    final operation = await _execute(
      operationId: idempotencyKey,
      kind: 'transfer',
      amountTokens: amountTokens,
      receiverMemberId: receiverMemberId,
      note: note?.trim(),
    );
    return WalletOperationResult(
      operation,
      WalletTransferReceipt.fromJson(operation.receipt!),
    );
  }

  Future<WalletOperationResult<WalletRedemptionReceipt>> redemptionOperation({
    required int amountTokens,
    required String idempotencyKey,
  }) async {
    final operation = await _execute(
      operationId: idempotencyKey,
      kind: 'redeem',
      amountTokens: amountTokens,
    );
    return WalletOperationResult(
      operation,
      WalletRedemptionReceipt.fromJson(operation.receipt!),
    );
  }

  // Existing API signatures remain available; closing a receipt is deliberately
  // explicit and never automatic inside these compatibility methods.
  Future<WalletTransferReceipt> transferTokens({
    required String receiverMemberId,
    required int amountTokens,
    required String idempotencyKey,
    String? note,
  }) async => (await transferOperation(
    receiverMemberId: receiverMemberId,
    amountTokens: amountTokens,
    idempotencyKey: idempotencyKey,
    note: note,
  )).value;
  Future<WalletRedemptionReceipt> redeemTokens({
    required int amountTokens,
    required String idempotencyKey,
  }) async => (await redemptionOperation(
    amountTokens: amountTokens,
    idempotencyKey: idempotencyKey,
  )).value;
  Future<void> closeOperation(
    WalletOperationRecord operation, {
    required bool cancel,
  }) async {
    final account = _captureAuthority();
    if (account.userId != operation.ownerId) {
      throw StateError('ACCOUNT_CHANGED');
    }
    final Object? response;
    try {
      response = await supabase
          .rpc<dynamic>(
            'rpc_close_wallet_operation',
            params: {
              'p_operation_id': operation.operationId,
              'p_action': cancel ? 'cancel' : 'acknowledge',
            },
          )
          .timeout(_timeout);
    } on Object catch (error) {
      if (!RequestDeadline.responseWasLost(error)) rethrow;
      throw UnknownWalletOutcome(operation.operationId);
    }
    account.requireCurrent();
    try {
      final result = _parseOperation(response, ownerId: account.userId);
      if (result.operationId != operation.operationId ||
          !result.acknowledged ||
          result.kind != operation.kind ||
          result.amountTokens != operation.amountTokens ||
          result.receiverMemberId != operation.receiverMemberId ||
          result.status != (cancel ? 'cancelled' : 'committed')) {
        throw const FormatException('WALLET_CLOSE_UNCONFIRMED');
      }
    } on Object {
      throw UnknownWalletOutcome(operation.operationId);
    }
    // If local cleanup fails, the server still retains the prior closed receipt.
    // A later server read remains authoritative; never claim the transfer failed.
    try {
      await WalletOperationJournal.clear(account.userId, operation.operationId);
    } on Object {
      /* Stale local pointers cannot open a new server operation. */
    }
  }
}
