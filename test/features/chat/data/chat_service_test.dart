import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobi_app/core/errors/app_exception.dart' as app;
import 'package:mobi_app/features/chat/data/chat_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _userId = '00000000-0000-4000-8000-000000000001';
const _conversationId = '00000000-0000-4000-8000-000000000010';

String _encode(Object value) =>
    base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');

Future<SupabaseClient> _client(
  Future<http.Response> Function(http.Request) respond,
) async {
  final client = SupabaseClient(
    'https://chat-fixture.invalid',
    'synthetic-public-fixture-key',
    authOptions: const AuthClientOptions(autoRefreshToken: false),
    httpClient: MockClient((request) {
      expect(request.url.host, 'chat-fixture.invalid');
      return respond(request);
    }),
  );
  final expiry = DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600;
  final accessToken =
      '${_encode({'alg': 'none', 'typ': 'JWT'})}.'
      '${_encode({'sub': _userId, 'exp': expiry, 'role': 'authenticated'})}.'
      'synthetic-not-a-valid-server-signature';
  await client.auth.recoverSession(
    jsonEncode({
      'access_token': accessToken,
      'refresh_token': 'synthetic-refresh-fixture',
      'token_type': 'bearer',
      'expires_in': 3600,
      'expires_at': expiry,
      'user': {
        'id': _userId,
        'aud': 'authenticated',
        'created_at': '2026-01-01T00:00:00Z',
        'app_metadata': {'provider': 'whatsapp_cloud_otp'},
        'user_metadata': <String, Object?>{},
      },
    }),
  );
  addTearDown(client.dispose);
  return client;
}

void main() {
  test('a second send cannot report success without a server call', () async {
    final sent = <String>[];
    final client = await _client((request) async {
      expect(request.url.path, '/rest/v1/rpc/rpc_send_chat_message');
      sent.add((jsonDecode(request.body) as Map)['p_body'] as String);
      return http.Response(
        jsonEncode('fixture-message-id'),
        200,
        headers: {'content-type': 'application/json'},
        request: request,
      );
    });
    var now = DateTime.utc(2026, 9, 14);
    final service = ChatService(supabase: client, now: () => now);
    await service.sendMessage(conversationId: _conversationId, body: 'First');
    Object? secondError;
    try {
      await service.sendMessage(
        conversationId: _conversationId,
        body: 'Second',
      );
    } on Object catch (error) {
      secondError = error;
    }
    // A deliberate cooldown may reject the send, but successful completion
    // must always mean that the message was submitted to the server.
    expect(
      sent.length == 2 || secondError is app.AppException,
      isTrue,
      reason: 'The UI clears its draft after a successful Future.',
    );
    expect(secondError, isA<app.ValidationException>());
    expect(sent, ['First']);
    now = now.add(const Duration(seconds: 1));
    await service.sendMessage(conversationId: _conversationId, body: 'Second');
    expect(sent, ['First', 'Second']);
  });

  test('server rejection is surfaced and permits an immediate retry', () async {
    var attempts = 0;
    final client = await _client((request) async {
      attempts++;
      if (attempts == 1) {
        return http.Response(
          jsonEncode({'message': 'temporary failure', 'code': 'P0001'}),
          503,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }
      return http.Response(
        jsonEncode('fixture-message-id'),
        200,
        headers: {'content-type': 'application/json'},
        request: request,
      );
    });
    final service = ChatService(supabase: client);
    await expectLater(
      service.sendMessage(conversationId: _conversationId, body: 'Retry me'),
      throwsA(isA<app.AppException>()),
    );
    await service.sendMessage(
      conversationId: _conversationId,
      body: 'Retry me',
    );
    expect(attempts, 2);
  });

  test('separate chat clients do not suppress one another', () async {
    final sent = <String>[];
    final client = await _client((request) async {
      sent.add((jsonDecode(request.body) as Map)['p_body'] as String);
      return http.Response(
        jsonEncode('fixture-message-id'),
        200,
        headers: {'content-type': 'application/json'},
        request: request,
      );
    });
    final now = DateTime.utc(2026, 9, 14);
    final first = ChatService(supabase: client, now: () => now);
    final second = ChatService(supabase: client, now: () => now);
    await first.sendMessage(conversationId: _conversationId, body: 'First');
    await second.sendMessage(conversationId: _conversationId, body: 'Second');
    expect(sent, ['First', 'Second']);
  });

  test('an older failure does not reset a newer send cooldown', () async {
    final firstResponse = Completer<http.Response>();
    http.Request? pendingRequest;
    var attempts = 0;
    final client = await _client((request) async {
      attempts++;
      if (attempts == 1) {
        pendingRequest = request;
        return firstResponse.future;
      }
      return http.Response(
        jsonEncode('fixture-message-id'),
        200,
        headers: {'content-type': 'application/json'},
        request: request,
      );
    });
    var now = DateTime.utc(2026, 9, 14);
    final service = ChatService(supabase: client, now: () => now);
    final firstFailure = expectLater(
      service.sendMessage(conversationId: _conversationId, body: 'First'),
      throwsA(isA<app.AppException>()),
    );
    await Future<void>.delayed(Duration.zero);
    now = now.add(const Duration(seconds: 1));
    await service.sendMessage(conversationId: _conversationId, body: 'Second');
    firstResponse.complete(
      http.Response(
        jsonEncode({'message': 'temporary failure', 'code': 'P0001'}),
        503,
        headers: {'content-type': 'application/json'},
        request: pendingRequest,
      ),
    );
    await firstFailure;
    await expectLater(
      service.sendMessage(conversationId: _conversationId, body: 'Too soon'),
      throwsA(isA<app.ValidationException>()),
    );
    expect(attempts, 2);
  });

  test(
    'empty bodies do not use the cooldown and submitted text is trimmed',
    () async {
      final sent = <String>[];
      final client = await _client((request) async {
        sent.add((jsonDecode(request.body) as Map)['p_body'] as String);
        return http.Response(
          jsonEncode('fixture-message-id'),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      });
      final service = ChatService(supabase: client);
      await service.sendMessage(conversationId: _conversationId, body: '  \n ');
      await service.sendMessage(
        conversationId: _conversationId,
        body: ' Message  ',
      );
      expect(sent, ['Message']);
    },
  );
}
