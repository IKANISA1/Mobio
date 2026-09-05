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
      id: json['id'] as String,
      conversationId: json['conversation_id'] as String,
      senderId: json['sender_id'] as String?,
      messageType: (json['message_type'] as String?) ?? 'text',
      body: (json['body'] as String?) ?? '',
      createdAt:
          DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now(),
      readAt: DateTime.tryParse(json['read_at'] as String? ?? ''),
      metadata: json['metadata'] is Map<String, dynamic>
          ? json['metadata'] as Map<String, dynamic>
          : const {},
    );
  }
}
