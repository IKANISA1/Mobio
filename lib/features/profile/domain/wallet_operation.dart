class WalletOperationRecord {
  const WalletOperationRecord({required this.operationId,required this.ownerId,
    required this.kind,required this.status,required this.amountTokens,
    required this.acknowledged,this.receiverMemberId,this.receipt});
  final String operationId,ownerId,kind,status;
  final int amountTokens;
  final bool acknowledged;
  final String? receiverMemberId;
  final Map<String,dynamic>? receipt;
  bool get committed=>status=='committed';
  factory WalletOperationRecord.fromJson(Map<String,dynamic> json,{required String ownerId}) {
    final amount=json['amount_tokens'];
    if(json['owner_id']!=ownerId || json['operation_id'] is! String ||
      !RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$').hasMatch(json['operation_id'] as String) ||
      !const ['transfer','redeem'].contains(json['kind']) ||
      !const ['prepared','committed','cancelled'].contains(json['status']) ||
      amount is! int || amount<=0 || amount>9007199254740991 || json['acknowledged'] is! bool) {
      throw const FormatException('INVALID_WALLET_OPERATION');
    }
    if (json['kind'] == 'transfer' && (json['receiver_member_id'] is! String ||
        !RegExp(r'^[0-9]{6}$').hasMatch(json['receiver_member_id'] as String))) {
      throw const FormatException('INVALID_WALLET_RECIPIENT');
    }
    if (json['kind'] == 'redeem' && json['receiver_member_id'] != null) {
      throw const FormatException('INVALID_WALLET_RECIPIENT');
    }
    final rawReceipt=json['receipt'];
    if(json['status']=='committed' && rawReceipt is! Map) throw const FormatException('INVALID_WALLET_RECEIPT');
    return WalletOperationRecord(operationId:json['operation_id'] as String,ownerId:ownerId,
      kind:json['kind'] as String,status:json['status'] as String,amountTokens:amount,
      acknowledged:json['acknowledged'] as bool,receiverMemberId:json['receiver_member_id'] as String?,
      receipt:rawReceipt is Map ? Map<String,dynamic>.from(rawReceipt):null);
  }
}
class WalletOperationResult<T> {
  const WalletOperationResult(this.operation,this.value);
  final WalletOperationRecord operation;
  final T value;
}
class UnknownWalletOutcome implements Exception {
  const UnknownWalletOutcome(this.operationId);
  final String operationId;
  @override String toString()=>'WALLET_OUTCOME_UNKNOWN';
}
