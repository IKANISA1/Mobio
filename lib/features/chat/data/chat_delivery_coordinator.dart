import 'dart:convert';
import 'package:mobi_app/core/errors/app_exception.dart';
import 'package:mobi_app/features/chat/data/chat_delivery_store.dart';
import 'package:mobi_app/features/chat/domain/chat_delivery.dart';

typedef ChatRpc =
    Future<Map<String, dynamic>> Function(
      String function,
      Map<String, dynamic> params,
    );

/// Testable protocol; authority is captured by the caller for EACH invocation.
/// A timeout never creates a replacement ID. No automatic background replay.
class ChatDeliveryCoordinator {
  ChatDeliveryCoordinator({
    required this.ownerId,
    required this.store,
    required this.rpc,
    required this.requireCurrent,
  });
  final String ownerId;
  final ChatDeliveryStore store;
  final ChatRpc rpc;
  final void Function() requireCurrent;
  static final Set<String> _busy = {};
  Future<T> _exclusive<T>(String c, Future<T> Function() action) async {
    final key = '$ownerId:$c';
    if (!_busy.add(key)) throw const ChatDeliveryException('delivery_busy');
    try {
      requireCurrent();
      return await action();
    } finally {
      _busy.remove(key);
    }
  }

  Future<Map<String, dynamic>> _call(
    String fn,
    Map<String, dynamic> params,
  ) async {
    requireCurrent();
    final row = await rpc(fn, params);
    requireCurrent();
    return row;
  }

  Future<ChatSendPointer?> _pending(String c) async {
    final local = await store.read(ownerId, c);
    requireCurrent();
    final row = await _call('rpc_chat_delivery_status', {
      'p_conversation_id': c,
    });
    if (row['owner_id'] != ownerId || row['conversation_id'] != c) {
      throw const ChatDeliveryException('invalid_server_receipt');
    }
    if (row['state'] == 'not_observed') {
      if (row['client_message_id'] != null ||
          row['message_id'] != null ||
          row['acknowledged'] == true) {
        throw const ChatDeliveryException('invalid_server_receipt');
      }
      return local;
    }
    final remote = ChatSendPointer.fromJson(row, ownerId, c);
    final validated = ChatDeliveryReceipt.parse(row, remote);
    if (validated.state != ChatDeliveryState.sent || validated.acknowledged) {
      throw const ChatDeliveryException('invalid_server_receipt');
    }
    // An active server slot protects against another tab/device losing a reply.
    if (local != null &&
        (local.clientMessageId != remote.clientMessageId ||
            local.bodySha256 != remote.bodySha256)) {
      throw const ChatDeliveryException('recovery_storage_conflict');
    }
    if (local == null) {
      await store.write(remote);
      requireCurrent();
    }
    return remote;
  }

  Future<ChatDeliveryReceipt?> pending(String c) => _exclusive(c, () async {
    final p = await _pending(c);
    if (p == null) return null;
    return ChatDeliveryReceipt.parse(
      await _call('rpc_chat_delivery_status', {
        'p_conversation_id': c,
        'p_client_message_id': p.clientMessageId,
      }),
      p,
    );
  });
  Future<ChatDeliveryReceipt> send(
    String c,
    String input,
  ) => _exclusive(c, () async {
    final body = input.trim();
    if (body.isEmpty ||
        body.runes.length > 2000 ||
        utf8.encode(body).length > 8000) {
      throw const ChatDeliveryException('invalid_message');
    }
    var p = await _pending(c);
    if (p != null && p.bodySha256 != ChatSendPointer.bodyHash(body)) {
      throw const ChatDeliveryException('resolve_previous_message');
    }
    p ??= ChatSendPointer.create(ownerId, c, body);
    await store.write(p);
    requireCurrent(); // Never dispatch without recovery metadata.
    final row = await _call('rpc_send_chat_message_v2', {
      'p_conversation_id': c,
      'p_client_message_id': p.clientMessageId,
      'p_body': body,
    });
    final ChatDeliveryReceipt receipt;
    try {
      receipt = ChatDeliveryReceipt.parse(row, p);
    } on ChatDeliveryException catch (error, stackTrace) {
      throw MutationOutcomeUnknownException(
        operation: 'rpc_send_chat_message_v2',
        operationId: p.clientMessageId,
        originalError: error,
        stackTrace: stackTrace,
      );
    }
    if (receipt.state != ChatDeliveryState.sent) {
      throw const ChatDeliveryException('message_cancelled');
    }
    try {
      final closed = ChatDeliveryReceipt.parse(
        await _call('rpc_close_chat_delivery', {
          'p_conversation_id': c,
          'p_client_message_id': p.clientMessageId,
          'p_body_sha256': p.bodySha256,
        }),
        p,
      );
      if (closed.state != ChatDeliveryState.sent || !closed.acknowledged) {
        throw const ChatDeliveryException('invalid_server_receipt');
      }
      await store.remove(p);
      requireCurrent();
      return closed;
    } on Object {
      // The valid send receipt already proves that this message committed.
      // A close/local-cleanup failure must not relabel it as failed or unsent.
      // Keep its recovery pointer; the UI resolves that record before another
      // distinct send. Never return an old account's receipt to a new account.
      requireCurrent();
      return receipt;
    }
  });
  Future<ChatDeliveryReceipt?> resolve(
    String c, {
    bool cancelIfUnobserved = false,
  }) => _exclusive(c, () async {
    final p = await _pending(c);
    if (p == null) return null;
    final receipt = ChatDeliveryReceipt.parse(
      await _call('rpc_chat_delivery_status', {
        'p_conversation_id': c,
        'p_client_message_id': p.clientMessageId,
      }),
      p,
    );
    if (receipt.state == ChatDeliveryState.notObserved && !cancelIfUnobserved) {
      return receipt;
    }
    final row = await _call('rpc_close_chat_delivery', {
      'p_conversation_id': c,
      'p_client_message_id': p.clientMessageId,
      'p_body_sha256': p.bodySha256,
      'p_cancel_if_unobserved': cancelIfUnobserved,
    });
    final ChatDeliveryReceipt closed;
    try {
      closed = ChatDeliveryReceipt.parse(row, p);
      if (!closed.acknowledged ||
          closed.state == ChatDeliveryState.notObserved) {
        throw const ChatDeliveryException('invalid_server_receipt');
      }
    } on ChatDeliveryException catch (error, stackTrace) {
      throw MutationOutcomeUnknownException(
        operation: 'rpc_close_chat_delivery',
        operationId: p.clientMessageId,
        originalError: error,
        stackTrace: stackTrace,
      );
    }
    await store.remove(p);
    requireCurrent();
    return closed;
  });
}
