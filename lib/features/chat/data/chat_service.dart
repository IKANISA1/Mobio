import 'dart:async';

import 'package:mobi_app/core/async/request_deadline.dart';
import 'package:mobi_app/core/auth/account_context.dart';
import 'package:mobi_app/core/errors/app_exception.dart';
import 'package:mobi_app/features/chat/data/chat_delivery_coordinator.dart';
import 'package:mobi_app/features/chat/data/chat_delivery_store.dart';
import 'package:mobi_app/features/chat/domain/chat_conversation.dart';
import 'package:mobi_app/features/chat/domain/chat_delivery.dart';
import 'package:mobi_app/features/chat/domain/chat_history_page.dart';
import 'package:mobi_app/features/chat/domain/chat_message.dart';
import 'package:mobi_app/features/chat/domain/chat_wire_record.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ChatAuthority {
  const ChatAuthority(this.ownerId, this.requireCurrent);
  final String ownerId;
  final void Function() requireCurrent;
}

class ChatService {
  ChatService({
    SupabaseClient? supabase,
    DateTime Function()? now,
    ChatDeliveryStore? deliveryStore,
    ChatAuthority Function()? captureAuthority,
    Duration requestTimeout = const Duration(seconds: 15),
  }) : _supabase = supabase ?? Supabase.instance.client,
       _store = deliveryStore ?? PreferencesChatDeliveryStore(),
       _captureOverride = captureAuthority,
       _queryTimeout = requestTimeout;
  final SupabaseClient _supabase;
  final ChatDeliveryStore _store;
  final ChatAuthority Function()? _captureOverride;
  final Duration _queryTimeout;
  String? get currentUserId => _supabase.auth.currentUser?.id;
  ChatAuthority _capture() {
    final override = _captureOverride;
    if (override != null) return override();
    final snapshot = AccountContext.capture();
    if (currentUserId != snapshot.userId) {
      throw const ChatDeliveryException('account_changed');
    }
    return ChatAuthority(
      snapshot.userId,
      () => AccountContext.requireCurrent(snapshot),
    );
  }

  Future<T> _guard<T>(Future<T> Function() action) async {
    final a = _capture();
    a.requireCurrent();
    final result = await RequestDeadline.read(action(), timeout: _queryTimeout);
    a.requireCurrent();
    return result;
  }

  Future<T> _mutate<T>(
    Future<T> Function() action, {
    required String operation,
    String? operationId,
  }) async {
    final a = _capture();
    a.requireCurrent();
    final result = await RequestDeadline.mutation(
      action(),
      operation: operation,
      operationId: operationId,
      timeout: _queryTimeout,
    );
    a.requireCurrent();
    return result;
  }

  Future<ChatConversation> getOrCreateConversation({
    required String peerId,
    String? tripId,
  }) {
    final account = _capture();
    return _mutate(
      () async {
        final row = await _supabase.rpc(
          'rpc_get_or_create_chat_conversation',
          params: {'p_peer_id': peerId, 'p_trip_id': tripId},
        );
        try {
          final conversation = ChatConversation.fromJson(
            ChatWireRecord.object(row),
            expectedOwnerId: account.ownerId,
          );
          if (conversation.peerIdFor(account.ownerId) != peerId ||
              conversation.tripId != tripId ||
              conversation.contextType !=
                  (tripId == null ? 'direct' : 'trip')) {
            throw const FormatException('Chat conversation recipient mismatch');
          }
          return conversation;
        } on FormatException catch (error, stackTrace) {
          throw MutationOutcomeUnknownException(
            operation: 'rpc_get_or_create_chat_conversation',
            operationId: tripId,
            originalError: error,
            stackTrace: stackTrace,
          );
        }
      },
      operation: 'rpc_get_or_create_chat_conversation',
      operationId: tripId,
    );
  }

  Future<bool> isPeerBlocked(String peerId) => _guard(() async {
    final row = await _supabase.rpc(
      'rpc_is_user_blocked',
      params: {'p_peer_id': peerId},
    );
    if (row is! bool) throw const ChatDeliveryException('invalid_block_status');
    return row;
  });
  Future<void> blockUser({required String peerId, String? reason}) => _mutate(
    () async {
      await _supabase.rpc(
        'rpc_block_user',
        params: {'p_blocked_id': peerId, 'p_reason': reason},
      );
    },
    operation: 'rpc_block_user',
    operationId: peerId,
  );
  Future<void> unblockUser(String peerId) => _mutate(
    () async {
      await _supabase.rpc('rpc_unblock_user', params: {'p_blocked_id': peerId});
    },
    operation: 'rpc_unblock_user',
    operationId: peerId,
  );
  Future<void> reportUser({
    required String peerId,
    String? conversationId,
    String? tripId,
    required String category,
    required String details,
  }) => _mutate(
    () async {
      await _supabase.rpc(
        'rpc_report_user',
        params: {
          'p_reported_id': peerId,
          'p_conversation_id': conversationId,
          'p_trip_id': tripId,
          'p_category': category,
          'p_details': details,
        },
      );
    },
    operation: 'rpc_report_user',
    operationId: conversationId,
  );
  Future<ChatConversation?> getConversationById(String conversationId) {
    final account = _capture();
    return _guard(() async {
      final row = await _supabase
          .from('chat_conversations')
          .select()
          .eq('id', conversationId)
          .maybeSingle();
      return row == null
          ? null
          : ChatConversation.fromJson(
              row,
              expectedId: conversationId,
              expectedOwnerId: account.ownerId,
            );
    });
  }

  Future<List<ChatConversation>> listTripConversations(String tripId) {
    final account = _capture();
    return _guard(() async {
      final rows = await _supabase
          .from('chat_conversations')
          .select()
          .eq('trip_id', tripId)
          .order('last_message_at', ascending: false)
          .limit(100);
      return rows.map((row) {
        final conversation = ChatConversation.fromJson(
          row,
          expectedOwnerId: account.ownerId,
        );
        if (conversation.tripId != tripId ||
            conversation.contextType != 'trip') {
          throw const FormatException('Chat trip mismatch');
        }
        return conversation;
      }).toList();
    });
  }

  Future<ChatHistoryPage> getMessagesPage(
    String conversationId, {
    int limit = 50,
    ChatHistoryCursor? before,
  }) => _guard(() async {
    if (limit < 1 || limit > 100) {
      throw const ChatDeliveryException('invalid_history_limit');
    }
    final rows = await _supabase.rpc(
      'rpc_list_chat_messages_page',
      params: {
        'p_conversation_id': conversationId,
        'p_limit': limit,
        ...?before?.params,
      },
    );
    return ChatHistoryPage.parse(rows, conversationId, limit);
  });
  Future<List<ChatMessageModel>> getRecentMessages(
    String conversationId, {
    int limit = 100,
  }) async => (await getMessagesPage(conversationId, limit: limit)).messages;

  ChatDeliveryCoordinator _delivery() {
    final a = _capture();
    return ChatDeliveryCoordinator(
      ownerId: a.ownerId,
      store: _store,
      requireCurrent: a.requireCurrent,
      rpc: (fn, params) async {
        final request = _supabase.rpc(fn, params: params);
        final row = fn == 'rpc_chat_delivery_status'
            ? await RequestDeadline.read(request, timeout: _queryTimeout)
            : await RequestDeadline.mutation(
                request,
                operation: fn,
                operationId: params['p_client_message_id'] as String?,
                timeout: _queryTimeout,
              );
        try {
          return ChatWireRecord.object(row);
        } on FormatException catch (error, stackTrace) {
          if (fn == 'rpc_chat_delivery_status') rethrow;
          throw MutationOutcomeUnknownException(
            operation: fn,
            operationId: params['p_client_message_id'] as String?,
            originalError: error,
            stackTrace: stackTrace,
          );
        }
      },
    );
  }

  Future<void> sendMessage({
    required String conversationId,
    required String body,
  }) async {
    await _delivery().send(conversationId, body);
  }

  Future<ChatDeliveryReceipt?> pendingDelivery(String conversationId) =>
      _delivery().pending(conversationId);
  Future<ChatDeliveryReceipt?> resolveDelivery(
    String conversationId, {
    bool cancelIfUnobserved = false,
  }) => _delivery().resolve(
    conversationId,
    cancelIfUnobserved: cancelIfUnobserved,
  );
  Future<bool> sendsEnabled() => _guard(() async {
    final row = await _supabase.rpc('rpc_chat_runtime_status');
    if (row is! Map || row['sends_enabled'] is! bool) {
      throw const ChatDeliveryException('invalid_chat_status');
    }
    return row['sends_enabled'] as bool;
  });
  Future<void> markConversationRead(
    String conversationId, {
    ChatHistoryCursor? through,
  }) async {
    // No broad table UPDATE and no client-now watermark. The visible latest row
    // bounds the mutation. Opening a screen without visible history marks none.
    if (through == null) return;
    await _mutate(
      () async {
        await _supabase.rpc(
          'rpc_mark_chat_read',
          params: {
            'p_conversation_id': conversationId,
            'p_through_created_at': through.wireTimestamp,
            'p_through_id': through.id,
          },
        );
      },
      operation: 'rpc_mark_chat_read',
      operationId: conversationId,
    );
  }

  Stream<List<ChatMessageModel>> streamMessages(String conversationId) =>
      watchMessagePages(conversationId).map((page) => page.messages);
  Stream<ChatHistoryPage> watchMessagePages(String conversationId) {
    final a = _capture();
    late StreamController<ChatHistoryPage> controller;
    RealtimeChannel? channel;
    Timer? poll;
    var closed = false, refreshing = false, queued = false;
    Future<void> refresh() async {
      if (closed) return;
      if (refreshing) {
        queued = true;
        return;
      }
      refreshing = true;
      try {
        do {
          queued = false;
          a.requireCurrent();
          final page = await getMessagesPage(conversationId);
          a.requireCurrent();
          if (!closed) controller.add(page);
        } while (queued && !closed);
      } on Object catch (error, stack) {
        if (!closed) controller.addError(error, stack);
      } finally {
        refreshing = false;
      }
    }

    late void Function() authorityChanged;
    Future<void> stop() async {
      closed = true;
      poll?.cancel();
      AccountContext.changes.removeListener(authorityChanged);
      final active = channel;
      channel = null;
      if (active != null) {
        try {
          await active.unsubscribe().timeout(const Duration(seconds: 3));
        } on Object {
          /* A transport error cannot restore local access. */
        }
      }
    }

    authorityChanged = () {
      try {
        a.requireCurrent();
      } on Object catch (error, stack) {
        if (!closed) {
          controller.addError(error, stack);
          unawaited(stop());
          unawaited(controller.close());
        }
      }
    };
    controller = StreamController<ChatHistoryPage>(
      onListen: () {
        AccountContext.changes.addListener(authorityChanged);
        unawaited(refresh());
        channel = _supabase
            .channel('chat_v2_${conversationId}_${ChatSendPointer.newId()}')
            .onPostgresChanges(
              event: PostgresChangeEvent.update,
              schema: 'public',
              table: 'chat_conversations',
              filter: PostgresChangeFilter(
                type: PostgresChangeFilterType.eq,
                column: 'id',
                value: conversationId,
              ),
              callback: (_) => unawaited(refresh()),
            )
            .subscribe((status, _) {
              if (closed) return;
              if (status == RealtimeSubscribeStatus.subscribed) {
                unawaited(refresh());
              }
              if (status == RealtimeSubscribeStatus.channelError ||
                  status == RealtimeSubscribeStatus.timedOut) {
                controller.addError(
                  const ChatDeliveryException('history_connection_unavailable'),
                );
              }
            });
        poll = Timer.periodic(
          const Duration(seconds: 30),
          (_) => unawaited(refresh()),
        );
      },
      onCancel: stop,
    );
    return controller.stream;
  }
}
