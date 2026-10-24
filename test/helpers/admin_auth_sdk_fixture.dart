import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobi_app/core/auth/admin_session_guard.dart';

const owner = '11111111-1111-4111-8111-111111111111';
const other = '22222222-2222-4222-8222-222222222222';
const sid = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const nextSid = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';

http.Client sdkFixtureHttpClient(
  Future<http.Response> Function(http.Request) handler,
) => MockClient((request) async {
  final response = await handler(request);
  return http.Response.bytes(
    response.bodyBytes,
    response.statusCode,
    headers: response.headers,
    request: request,
  );
});

String savedSession({String user = owner, String session = sid}) {
  final claims = base64Url
      .encode(
        utf8.encode(
          jsonEncode({'sub': user, 'session_id': session, 'exp': 4102444800}),
        ),
      )
      .replaceAll('=', '');
  return jsonEncode({
    'access_token': 'e30.$claims.synthetic-signature',
    'refresh_token': 'synthetic-refresh',
    'token_type': 'bearer',
    'user': {
      'id': user,
      'aud': 'authenticated',
      'app_metadata': {'provider': 'admin_whatsapp_otp'},
      'user_metadata': {},
      'created_at': '2026-10-01T00:00:00Z',
    },
  });
}

void lease({String user = owner, String session = sid}) {
  AdminSessionGuard.acceptServerLease(
    userId: user,
    sessionId: session,
    idleRemaining: const Duration(minutes: 15),
    absoluteRemaining: const Duration(hours: 1),
  );
}

http.Response rejected({
  String code = '42501',
  String message = 'ADMIN_REAUTHENTICATION_REQUIRED',
}) => http.Response(
  jsonEncode({'code': code, 'message': message, 'details': null, 'hint': null}),
  403,
  headers: {'content-type': 'application/json'},
);

http.Response leaseResponse({
  String user = owner,
  String session = sid,
  bool active = true,
  Duration idle = const Duration(minutes: 15),
  Duration absolute = const Duration(hours: 1),
}) {
  final now = DateTime.now().toUtc();
  return http.Response(
    jsonEncode({
      'active': active,
      'user_id': user,
      'session_id': session,
      'server_now': now.toIso8601String(),
      'idle_expires_at': now.add(idle).toIso8601String(),
      'absolute_expires_at': now.add(absolute).toIso8601String(),
    }),
    200,
    headers: {'content-type': 'application/json'},
  );
}
