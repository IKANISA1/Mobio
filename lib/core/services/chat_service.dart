import 'package:mobi_app/core/utils/app_logger.dart';
import 'package:mobi_app/features/chat/models/chat_conversation.dart';
import 'package:mobi_app/features/chat/models/chat_message.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ChatService {
  ChatService({SupabaseClient? supabase})
    : _supabase = supabase ?? Supabase.instance.client;

  final SupabaseClient _supabase;

  String? get currentUserId => _supabase.auth.currentUser?.id;

  String _requireUserId() {
    final userId = currentUserId;
    if (userId == null || userId.isEmpty) {
      throw Exception('User must be authenticated to access chat.');
    }
    return userId;
  }

  Future<ChatConversation> getOrCreateConversation({
    required String peerId,
    String? tripId,
  }) async {
    _requireUserId();

    try {
      final response = await _supabase.rpc(
        'rpc_get_or_create_chat_conversation',
        params: {'p_peer_id': peerId, 'p_trip_id': tripId},
      );

      if (response is! Map<String, dynamic>) {
        throw Exception('Unexpected conversation response.');
      }

      return ChatConversation.fromJson(response);
    } on Object catch (error) {
      AppLogger.error('Error getting chat conversation: $error');
      rethrow;
    }
  }

  Future<ChatConversation?> getConversationById(String conversationId) async {
    try {
      final row = await _supabase
          .from('chat_conversations')
          .select()
          .eq('id', conversationId)
          .maybeSingle();

      if (row == null) {
        return null;
      }

      return ChatConversation.fromJson(row);
    } on Object catch (error) {
      AppLogger.error('Error loading conversation $conversationId: $error');
      return null;
    }
  }

  Future<List<ChatConversation>> listTripConversations(String tripId) async {
    _requireUserId();

    try {
      final rows = await _supabase
          .from('chat_conversations')
          .select()
          .eq('trip_id', tripId)
          .order('last_message_at', ascending: false);

      return (rows as List<dynamic>)
          .whereType<Map<String, dynamic>>()
          .map(ChatConversation.fromJson)
          .toList();
    } on Object catch (error) {
      AppLogger.error('Error listing trip conversations: $error');
      return [];
    }
  }

  Future<List<ChatMessageModel>> getRecentMessages(
    String conversationId, {
    int limit = 12,
  }) async {
    try {
      final rows = await _supabase
          .from('chat_messages')
          .select()
          .eq('conversation_id', conversationId)
          .order('created_at', ascending: false)
          .limit(limit);

      return (rows as List<dynamic>)
          .whereType<Map<String, dynamic>>()
          .map(ChatMessageModel.fromJson)
          .toList()
          .reversed
          .toList();
    } on Object catch (error) {
      AppLogger.error('Error loading recent chat messages: $error');
      return [];
    }
  }

  Stream<List<ChatMessageModel>> streamMessages(String conversationId) {
    return _supabase
        .from('chat_messages')
        .stream(primaryKey: ['id'])
        .eq('conversation_id', conversationId)
        .order('created_at', ascending: true)
        .map(
          (rows) => rows
              .map(ChatMessageModel.fromJson)
              .toList(growable: false),
        );
  }

  /// Minimum interval between message sends (prevents spam / double-tap).
  static const _sendCooldown = Duration(seconds: 1);
  static DateTime? _lastSendTime;

  Future<void> sendMessage({
    required String conversationId,
    required String body,
  }) async {
    final userId = _requireUserId();
    final trimmed = body.trim();
    if (trimmed.isEmpty) {
      return;
    }

    // Debounce: reject rapid duplicate sends
    final now = DateTime.now();
    if (_lastSendTime != null &&
        now.difference(_lastSendTime!) < _sendCooldown) {
      return; // silently skip — UI handles "sending" state
    }
    _lastSendTime = now;

    try {
      await _supabase.from('chat_messages').insert({
        'conversation_id': conversationId,
        'sender_id': userId,
        'message_type': 'text',
        'body': trimmed,
      });
    } on Object catch (error) {
      AppLogger.error('Error sending chat message: $error');
      rethrow;
    }
  }

  Future<void> markConversationRead(String conversationId) async {
    final userId = currentUserId;
    if (userId == null) {
      return;
    }

    try {
      await _supabase
          .from('chat_messages')
          .update({'read_at': DateTime.now().toIso8601String()})
          .eq('conversation_id', conversationId)
          .filter('sender_id', 'neq', userId)
          .isFilter('read_at', null);
    } on Object catch (error) {
      AppLogger.error('Error marking conversation read: $error');
    }
  }
}
