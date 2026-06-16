import 'dart:async';

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

  Future<bool> isPeerBlocked(String peerId) async {
    _requireUserId();

    try {
      final response = await _supabase
          .rpc('rpc_is_user_blocked', params: {'p_peer_id': peerId})
          .timeout(_queryTimeout);
      return response == true;
    } on AppException {
      rethrow;
    } on Object catch (error, stackTrace) {
      throw AppExceptionMapper.mapAndLog(
        error,
        stackTrace,
        'Error checking chat block status',
      );
    }
  }

  Future<void> blockUser({required String peerId, String? reason}) async {
    _requireUserId();

    try {
      await _supabase
          .rpc(
            'rpc_block_user',
            params: {'p_blocked_id': peerId, 'p_reason': reason},
          )
          .timeout(_queryTimeout);
    } on AppException {
      rethrow;
    } on Object catch (error, stackTrace) {
      throw AppExceptionMapper.mapAndLog(
        error,
        stackTrace,
        'Error blocking chat peer',
      );
    }
  }

  Future<void> unblockUser(String peerId) async {
    _requireUserId();

    try {
      await _supabase
          .rpc('rpc_unblock_user', params: {'p_blocked_id': peerId})
          .timeout(_queryTimeout);
    } on AppException {
      rethrow;
    } on Object catch (error, stackTrace) {
      throw AppExceptionMapper.mapAndLog(
        error,
        stackTrace,
        'Error unblocking chat peer',
      );
    }
  }

  Future<void> reportUser({
    required String peerId,
    String? conversationId,
    String? tripId,
    required String category,
    required String details,
  }) async {
    _requireUserId();

    try {
      await _supabase
          .rpc(
            'rpc_report_user',
            params: {
              'p_reported_id': peerId,
              'p_conversation_id': conversationId,
              'p_trip_id': tripId,
              'p_category': category,
              'p_details': details,
            },
          )
          .timeout(_queryTimeout);
    } on AppException {
      rethrow;
    } on Object catch (error, stackTrace) {
      throw AppExceptionMapper.mapAndLog(
        error,
        stackTrace,
        'Error reporting chat peer',
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
    int limit = 100,
  }) async {
    try {
      final rows = await _supabase
          .rpc<dynamic>(
            'rpc_list_chat_messages',
            params: {'p_conversation_id': conversationId, 'p_limit': limit},
          )
          .timeout(_queryTimeout);

      return (rows as List<dynamic>)
          .whereType<Map<String, dynamic>>()
          .map(ChatMessageModel.fromJson)
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
    late final StreamController<List<ChatMessageModel>> controller;
    RealtimeChannel? channel;
    var isRefreshing = false;
    var refreshQueued = false;

    Future<void> refreshMessages() async {
      if (isRefreshing) {
        refreshQueued = true;
        return;
      }

      isRefreshing = true;
      do {
        refreshQueued = false;
        try {
          final messages = await getRecentMessages(conversationId);
          if (!controller.isClosed) {
            controller.add(messages);
          }
        } on Object catch (error, stackTrace) {
          if (!controller.isClosed) {
            controller.addError(error, stackTrace);
          }
        }
      } while (refreshQueued && !controller.isClosed);
      isRefreshing = false;
    }

    controller = StreamController<List<ChatMessageModel>>(
      onListen: () {
        unawaited(refreshMessages());
        channel = _supabase
            .channel('chat_conversation_$conversationId')
            .onPostgresChanges(
              event: PostgresChangeEvent.update,
              schema: 'public',
              table: 'chat_conversations',
              filter: PostgresChangeFilter(
                type: PostgresChangeFilterType.eq,
                column: 'id',
                value: conversationId,
              ),
              callback: (_) => unawaited(refreshMessages()),
            )
            .subscribe();
      },
      onCancel: () async {
        final activeChannel = channel;
        channel = null;
        if (activeChannel != null) {
          await activeChannel.unsubscribe();
        }
        await controller.close();
      },
    );

    return controller.stream;
  }

  /// Minimum interval between message sends (prevents spam / double-tap).
  static const _sendCooldown = Duration(seconds: 1);
  static DateTime? _lastSendTime;

  Future<void> sendMessage({
    required String conversationId,
    required String body,
  }) async {
    _requireUserId();
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
          .rpc<dynamic>(
            'rpc_send_chat_message',
            params: {'p_conversation_id': conversationId, 'p_body': trimmed},
          )
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
