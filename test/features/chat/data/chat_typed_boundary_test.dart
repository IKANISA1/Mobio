import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobi_app/core/errors/app_exception.dart';
import 'package:mobi_app/features/chat/data/chat_service.dart';
import 'package:mobi_app/features/chat/domain/chat_conversation.dart';
import 'package:mobi_app/features/chat/domain/chat_message.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _owner = '00000000-0000-4000-8000-000000000001';
const _peer = '00000000-0000-4000-8000-000000000002';
const _other = '00000000-0000-4000-8000-000000000003';
const _conversation = '00000000-0000-4000-8000-000000000010';

Map<String, dynamic> _row() => {
  'id': _conversation,
  'trip_id': null,
  'participant_low_id': _owner,
  'participant_high_id': _peer,
  'created_by': _owner,
  'context_type': 'direct',
  'status': 'active',
  'last_message_preview': '',
  'last_message_at': null,
  'created_at': '2026-09-30T08:00:00Z',
  'updated_at': '2026-09-30T08:00:00Z',
};

ChatService _service(Object? response) {
  final client = SupabaseClient(
    'https://chat-contract.invalid',
    'mock-public-key',
    authOptions: const AuthClientOptions(autoRefreshToken: false),
    httpClient: MockClient(
      (request) async => http.Response(
        jsonEncode(response),
        200,
        headers: {'content-type': 'application/json'},
        request: request,
      ),
    ),
  );
  addTearDown(client.dispose);
  return ChatService(
    supabase: client,
    captureAuthority: () => const ChatAuthority(_owner, _current),
  );
}

void _current() {}

void main() {
  test(
    'conversation preserves valid nullable fields and explicit archived status',
    () {
      final conversation = ChatConversation.fromJson(
        {..._row(), 'status': 'archived'},
        expectedOwnerId: _owner,
        expectedId: _conversation,
      );
      expect(conversation.status, 'archived');
      expect(conversation.lastMessageAt, isNull);
      expect(conversation.peerIdFor(_owner), _peer);
      expect(() => conversation.peerIdFor(_other), throwsStateError);
    },
  );

  test(
    'conversation cannot default missing context, state, times or identity',
    () {
      for (final key in [
        'id',
        'created_by',
        'participant_low_id',
        'participant_high_id',
        'context_type',
        'status',
        'last_message_preview',
        'created_at',
        'updated_at',
      ]) {
        expect(
          () => ChatConversation.fromJson({..._row()}..remove(key)),
          throwsFormatException,
        );
      }
      expect(
        () => ChatConversation.fromJson({..._row(), 'context_type': 'trip'}),
        throwsFormatException,
      );
      expect(
        () => ChatConversation.fromJson({
          ..._row(),
          'participant_high_id': _owner,
        }),
        throwsFormatException,
      );
    },
  );

  test(
    'chat message requires explicit content and state while system sender remains nullable',
    () {
      final row = <String, dynamic>{
        'id': _conversation,
        'conversation_id': _conversation,
        'sender_id': null,
        'message_type': 'system',
        'body': '',
        'metadata': <String, dynamic>{},
        'created_at': '2026-09-30T08:00:00Z',
        'read_at': null,
      };
      final message = ChatMessageModel.fromJson(row);
      expect(message.senderId, isNull);
      expect(message.body, '');
      expect(message.readAt, isNull);
      for (final key in [
        'id',
        'conversation_id',
        'message_type',
        'body',
        'metadata',
        'created_at',
      ]) {
        expect(
          () => ChatMessageModel.fromJson({...row}..remove(key)),
          throwsFormatException,
        );
      }
      expect(
        () => ChatMessageModel.fromJson({...row, 'message_type': 'success'}),
        throwsFormatException,
      );
    },
  );

  test(
    'malformed or mismatched create acknowledgement cannot confirm a conversation',
    () async {
      for (final response in [
        null,
        <String, dynamic>{},
        [_row()],
        {..._row(), 'participant_high_id': _other},
        {..._row(), 'participant_low_id': _other},
        {..._row(), 'trip_id': _conversation},
      ]) {
        await expectLater(
          _service(response).getOrCreateConversation(peerId: _peer),
          throwsA(isA<MutationOutcomeUnknownException>()),
        );
      }
      expect(
        (await _service(_row()).getOrCreateConversation(peerId: _peer)).id,
        _conversation,
      );
    },
  );

  test(
    'single and trip-list reads correlate requested identity and participant',
    () async {
      await expectLater(
        _service({..._row(), 'id': _other}).getConversationById(_conversation),
        throwsFormatException,
      );
      await expectLater(
        _service({
          ..._row(),
          'participant_low_id': _other,
        }).getConversationById(_conversation),
        throwsFormatException,
      );
      await expectLater(
        _service([_row()]).listTripConversations(_conversation),
        throwsFormatException,
      );
      final row = {..._row(), 'context_type': 'trip', 'trip_id': _conversation};
      expect(
        (await _service([
          row,
        ]).listTripConversations(_conversation)).single.tripId,
        _conversation,
      );
    },
  );
}
