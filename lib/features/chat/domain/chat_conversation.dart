import 'package:mobi_app/features/chat/domain/chat_wire_record.dart';

class ChatConversation {
  const ChatConversation({
    required this.id,
    required this.participantLowId,
    required this.participantHighId,
    required this.createdBy,
    required this.contextType,
    required this.status,
    this.tripId,
    this.lastMessagePreview = '',
    this.lastMessageAt,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String? tripId;
  final String participantLowId;
  final String participantHighId;
  final String createdBy;
  final String contextType;
  final String status;
  final String lastMessagePreview;
  final DateTime? lastMessageAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isTripConversation => contextType == 'trip' && tripId != null;

  String peerIdFor(String currentUserId) {
    if (participantLowId == currentUserId) {
      return participantHighId;
    }
    if (participantHighId == currentUserId) return participantLowId;
    throw StateError('CHAT_PARTICIPANT_MISMATCH');
  }

  factory ChatConversation.fromJson(
    Map<String, dynamic> json, {
    String? expectedId,
    String? expectedOwnerId,
  }) {
    final id = ChatWireRecord.id(json, 'id');
    final low = ChatWireRecord.id(json, 'participant_low_id');
    final high = ChatWireRecord.id(json, 'participant_high_id');
    final context = ChatWireRecord.state(json, 'context_type', {
      'direct',
      'trip',
    });
    final tripId = ChatWireRecord.optionalId(json, 'trip_id');
    if (low == high ||
        (expectedId != null && id != expectedId) ||
        (expectedOwnerId != null &&
            low != expectedOwnerId &&
            high != expectedOwnerId) ||
        (context == 'trip' && tripId == null)) {
      throw const FormatException('Chat conversation identity mismatch');
    }
    return ChatConversation(
      id: id,
      tripId: tripId,
      participantLowId: low,
      participantHighId: high,
      createdBy: ChatWireRecord.id(json, 'created_by'),
      contextType: context,
      status: ChatWireRecord.state(json, 'status', {
        'active',
        'archived',
        'closed',
      }),
      lastMessagePreview: ChatWireRecord.text(json, 'last_message_preview'),
      lastMessageAt: ChatWireRecord.optionalDate(json, 'last_message_at'),
      createdAt: ChatWireRecord.date(json, 'created_at'),
      updatedAt: ChatWireRecord.date(json, 'updated_at'),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'trip_id': tripId,
    'participant_low_id': participantLowId,
    'participant_high_id': participantHighId,
    'created_by': createdBy,
    'context_type': contextType,
    'status': status,
    'last_message_preview': lastMessagePreview,
    'last_message_at': lastMessageAt?.toIso8601String(),
  };
}
