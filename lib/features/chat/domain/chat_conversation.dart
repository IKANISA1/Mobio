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
    return participantLowId;
  }

  factory ChatConversation.fromJson(Map<String, dynamic> json) {
    return ChatConversation(
      id: json['id'] as String,
      tripId: json['trip_id'] as String?,
      participantLowId: json['participant_low_id'] as String,
      participantHighId: json['participant_high_id'] as String,
      createdBy: json['created_by'] as String,
      contextType: (json['context_type'] as String?) ?? 'direct',
      status: (json['status'] as String?) ?? 'active',
      lastMessagePreview: (json['last_message_preview'] as String?) ?? '',
      lastMessageAt: DateTime.tryParse(
        json['last_message_at'] as String? ?? '',
      ),
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? ''),
      updatedAt: DateTime.tryParse(json['updated_at'] as String? ?? ''),
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
