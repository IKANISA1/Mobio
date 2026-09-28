import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import '../../../increment06/chat_protocol_fixture.dart';
import 'package:mobi_app/features/chat/domain/chat_history_page.dart';
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
  test('real SDK request adapter uses the journal protocol and trims text', () async {
    final f=ProtocolFixture();
    final client=await _client((request)async {
      final fn=request.url.path.split('/').last;
      final result=await f.call(fn,Map<String,dynamic>.from(jsonDecode(request.body) as Map));
      return http.Response(jsonEncode(result),200,headers:{'content-type':'application/json'});
    });
    final service=ChatService(supabase:client,deliveryStore:f.store,
      captureAuthority:()=>ChatAuthority(_userId,(){}));
    await service.sendMessage(conversationId:_conversationId,body:' First ');
    await service.sendMessage(conversationId:_conversationId,body:'Second');
    expect(f.effects,2);expect(f.sendIds.toSet().length,2);expect(f.store.pointer,isNull);
  });
  test('HTTP rejection is surfaced and retry retains its recovery id',()async{
    final f=ProtocolFixture();var reject=true;
    final client=await _client((request)async{
      final fn=request.url.path.split('/').last;
      if(fn=='rpc_send_chat_message_v2'&&reject){reject=false;return http.Response(
        jsonEncode({'message':'temporary failure','code':'PT503'}),503,headers:{'content-type':'application/json'});}
      return http.Response(jsonEncode(await f.call(fn,Map<String,dynamic>.from(jsonDecode(request.body) as Map))),
        200,headers:{'content-type':'application/json'});
    });
    final service=ChatService(supabase:client,deliveryStore:f.store,captureAuthority:()=>ChatAuthority(_userId,(){}));
    await expectLater(service.sendMessage(conversationId:_conversationId,body:'Retry'),throwsA(isA<PostgrestException>()));
    final id=f.store.pointer!.clientMessageId;
    await service.sendMessage(conversationId:_conversationId,body:'Retry');expect(f.sendIds,[id]);
  });
  test('read state requires a visible row, not client-now table writes',()async{
    final calls=<String>[];
    final client=await _client((request)async{calls.add(request.url.path);return http.Response('0',200,
      headers:{'content-type':'application/json'});});
    final service=ChatService(supabase:client,captureAuthority:()=>ChatAuthority(_userId,(){}));
    await service.markConversationRead(_conversationId);expect(calls,isEmpty);
    await service.markConversationRead(_conversationId,through:ChatHistoryCursor(DateTime.utc(2026,9,28),messageA));
    expect(calls,['/rest/v1/rpc/rpc_mark_chat_read']);
  });
}
