import 'package:mobi_app/core/errors/app_exception.dart';
import 'package:mobi_app/core/errors/app_exception_mapper.dart';
import 'package:mobi_app/features/chat/models/chat_conversation.dart';
import 'package:mobi_app/features/chat/models/chat_message.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthException;

class ChatService {
  ChatService({SupabaseClient? supabase})
    : _supabase = supabase ?? Supabase.instance.client;

  final SupabaseClient _supabase;
  static const _queryTimeout = Duration(seconds: 15);

  String? get currentUserId => _supabase.auth.currentUser?.id;

  String _requireUserId() {
    final userId = currentUserId;
    if (userId == null || userId.isEmpty) {
      throw const AuthException(message: 'Please sign in to use chat.');
    }
    return userId;
  }

  Future<ChatConversation> getOrCreateConversation({
    required String peerId,
    String? tripId,
  }) async {
    _requireUserId();

    try {
      final response = await _supabase
          .rpc(
            'rpc_get_or_create_chat_conversation',
            params: {'p_peer_id': peerId, 'p_trip_id': tripId},
          )
          .timeout(_queryTimeout);

      if (response is! Map<String, dynamic>) {
        throw const ServerException(
          message: 'Unable to open chat right now. Please try again.',
        );
      }

      return ChatConversation.fromJson(response);
    } on AppException {
      rethrow;
    } on Object catch (error, stackTrace) {
      throw AppExceptionMapper.mapAndLog(
        error,
        stackTrace,
        'Error getting chat conversation',
      );
    }
  }

  Future<ChatConversation?> getConversationById(String conversationId) async {
    try {
      final row = await _supabase
          .from('chat_conversations')
          .select()
          .eq('id', conversationId)
          .maybeSingle()
          .timeout(_queryTimeout);

      if (row == null) {
        return null;
      }

      return ChatConversation.fromJson(row);
    } on AppException {
      rethrow;
    } on Object catch (error, stackTrace) {
      throw AppExceptionMapper.mapAndLog(
        error,
        stackTrace,
        'Error loading conversation $conversationId',
      );
    }
  }

  Future<List<ChatConversation>> listTripConversations(String tripId) async {
    _requireUserId();

    try {
      final rows = await _supabase
          .from('chat_conversations')
          .select()
          .eq('trip_id', tripId)
          .order('last_message_at', ascending: false)
          .timeout(_queryTimeout);

      return (rows as List<dynamic>)
          .whereType<Map<String, dynamic>>()
          .map(ChatConversation.fromJson)
          .toList();
    } on AppException {
      rethrow;
    } on Object catch (error, stackTrace) {
      throw AppExceptionMapper.mapAndLog(
        error,
        stackTrace,
        'Error listing trip conversations',
      );
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
          .limit(limit)
          .timeout(_queryTimeout);

      return (rows as List<dynamic>)
          .whereType<Map<String, dynamic>>()
          .map(ChatMessageModel.fromJson)
          .toList()
          .reversed
          .toList();
    } on AppException {
      rethrow;
    } on Object catch (error, stackTrace) {
      throw AppExceptionMapper.mapAndLog(
        error,
        stackTrace,
        'Error loading recent chat messages',
      );
    }
  }

  Stream<List<ChatMessageModel>> streamMessages(String conversationId) {
    return _supabase
        .from('chat_messages')
        .stream(primaryKey: ['id'])
        .eq('conversation_id', conversationId)
        .order('created_at', ascending: true)
        .map(
          (rows) => rows.map(ChatMessageModel.fromJson).toList(growable: false),
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
    final previousSendTime = _lastSendTime;
    _lastSendTime = now;

    try {
      await _supabase
          .from('chat_messages')
          .insert({
            'conversation_id': conversationId,
            'sender_id': userId,
            'message_type': 'text',
            'body': trimmed,
          })
          .timeout(_queryTimeout);
    } on AppException {
      _lastSendTime = previousSendTime;
      rethrow;
    } on Object catch (error, stackTrace) {
      _lastSendTime = previousSendTime;
      throw AppExceptionMapper.mapAndLog(
        error,
        stackTrace,
        'Error sending chat message',
      );
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
          .isFilter('read_at', null)
          .timeout(_queryTimeout);
    } on Object catch (error, stackTrace) {
      AppExceptionMapper.mapAndLog(
        error,
        stackTrace,
        'Error marking conversation read',
      );
    }
  }
}
