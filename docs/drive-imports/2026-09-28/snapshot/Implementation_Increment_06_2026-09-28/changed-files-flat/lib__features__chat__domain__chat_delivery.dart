import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';

final _uuid = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');
final _digest = RegExp(r'^[0-9a-f]{64}$');

class ChatDeliveryException implements Exception {
  const ChatDeliveryException(this.code);
  final String code;
  @override String toString() => 'ChatDeliveryException($code)';
}

/// Local recovery metadata only. Message text is never written to preferences.
class ChatSendPointer {
  const ChatSendPointer({required this.ownerId, required this.conversationId,
    required this.clientMessageId, required this.bodySha256});
  final String ownerId;
  final String conversationId;
  final String clientMessageId;
  final String bodySha256;

  static String bodyHash(String exactBody) => sha256.convert(utf8.encode(exactBody)).toString();
  static String newId() {
    final random = Random.secure();
    final b = List<int>.generate(16, (_) => random.nextInt(256));
    b[6] = (b[6] & 15) | 64; b[8] = (b[8] & 63) | 128;
    final h = b.map((v) => v.toRadixString(16).padLeft(2, '0')).join();
    return '${h.substring(0,8)}-${h.substring(8,12)}-${h.substring(12,16)}-${h.substring(16,20)}-${h.substring(20)}';
  }
  factory ChatSendPointer.create(String owner, String conversation, String body) =>
    ChatSendPointer.fromJson({'owner_id': owner, 'conversation_id': conversation,
      'client_message_id': newId(), 'body_sha256': bodyHash(body)}, owner, conversation);
  factory ChatSendPointer.fromJson(Map<String, dynamic> row, String owner, String conversation) {
    if (row['owner_id'] != owner || row['conversation_id'] != conversation ||
        !_uuid.hasMatch(owner) || !_uuid.hasMatch(conversation) ||
        row['client_message_id'] is! String || !_uuid.hasMatch(row['client_message_id'] as String) ||
        row['body_sha256'] is! String || !_digest.hasMatch(row['body_sha256'] as String)) {
      throw const ChatDeliveryException('invalid_recovery_record');
    }
    return ChatSendPointer(ownerId:owner, conversationId:conversation,
      clientMessageId:row['client_message_id'] as String, bodySha256:row['body_sha256'] as String);
  }
  Map<String, dynamic> toJson() => {'owner_id':ownerId,'conversation_id':conversationId,
    'client_message_id':clientMessageId,'body_sha256':bodySha256};
}

enum ChatDeliveryState { sent, cancelled, notObserved }
class ChatDeliveryReceipt {
  const ChatDeliveryReceipt(this.pointer, this.state, this.messageId, this.acknowledged);
  final ChatSendPointer pointer;
  final ChatDeliveryState state;
  final String? messageId;
  final bool acknowledged;
  factory ChatDeliveryReceipt.parse(Map<String,dynamic> row, ChatSendPointer expected) {
    if (row['state']=='not_observed') {
      if(row['owner_id']!=expected.ownerId || row['conversation_id']!=expected.conversationId ||
        row['client_message_id']!=expected.clientMessageId || row['message_id']!=null ||
        row['acknowledged']==true || row['body_sha256']!=null) {
        throw const ChatDeliveryException('invalid_server_receipt');
      }
      return ChatDeliveryReceipt(expected,ChatDeliveryState.notObserved,null,false);
    }
    final p=ChatSendPointer.fromJson(row,expected.ownerId,expected.conversationId);
    if (p.clientMessageId!=expected.clientMessageId || p.bodySha256!=expected.bodySha256 ||
        row['acknowledged'] is! bool ||
        (row['message_id']!=null && (row['message_id'] is! String || !_uuid.hasMatch(row['message_id'] as String)))) {
      throw const ChatDeliveryException('invalid_server_receipt');
    }
    final state=switch(row['state']) {'sent'=>ChatDeliveryState.sent,
      'cancelled'=>ChatDeliveryState.cancelled,_=>throw const ChatDeliveryException('invalid_server_receipt')};
    if (state==ChatDeliveryState.cancelled && (row['message_id']!=null || row['acknowledged']!=true)) {
      throw const ChatDeliveryException('invalid_server_receipt');
    }
    return ChatDeliveryReceipt(p,state,row['message_id'] as String?,row['acknowledged'] as bool);
  }
}
