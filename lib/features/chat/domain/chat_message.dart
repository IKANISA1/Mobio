import 'package:mobi_app/features/chat/domain/chat_wire_record.dart';

class ChatMessageModel {
  const ChatMessageModel({
    required this.id,
    required this.conversationId,
    required this.messageType,
    required this.body,
    required this.createdAt,
    this.senderId,
    this.readAt,
    this.metadata = const {},
  });

  final String id;
  final String conversationId;
  final String? senderId;
  final String messageType;
  final String body;
  final DateTime createdAt;
  final DateTime? readAt;
  final Map<String, dynamic> metadata;

  bool get isSystem => messageType == 'system';

  bool isFrom(String currentUserId) => senderId == currentUserId;

  factory ChatMessageModel.fromJson(Map<String, dynamic> json) {
    return ChatMessageModel(
      id: ChatWireRecord.id(json, 'id'),
      conversationId: ChatWireRecord.id(json, 'conversation_id'),
      senderId: ChatWireRecord.optionalId(json, 'sender_id'),
      messageType: ChatWireRecord.state(json, 'message_type', {
        'text',
        'system',
      }),
      body: ChatWireRecord.text(json, 'body'),
      createdAt: ChatWireRecord.date(json, 'created_at'),
      readAt: ChatWireRecord.optionalDate(json, 'read_at'),
      metadata: ChatWireRecord.object(json['metadata']),
    );
  }
}
