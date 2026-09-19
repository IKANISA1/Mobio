import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobi_app/core/errors/app_exception.dart' as app;
import 'package:mobi_app/features/notifications/data/notification_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _user = '00000000-0000-4000-8000-000000000001';
const _peer = '00000000-0000-4000-8000-000000000002';
const _notification = '00000000-0000-4000-8000-000000000010';

String _encode(Object value) =>
    base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');

// Deliberately mocked Auth state and HTTP. No token is accepted by a server;
// these tests exercise the production service's failure and lifecycle behavior.
Future<void> _signIn(SupabaseClient client, String id) async {
  final expiry = DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600;
  await client.auth.recoverSession(
    jsonEncode({
      'access_token':
          '${_encode({'alg': 'none', 'typ': 'JWT'})}.'
          '${_encode({'sub': id, 'exp': expiry, 'role': 'authenticated'})}.'
          'mock-not-a-valid-server-signature',
      'refresh_token': 'mock-refresh-fixture',
      'token_type': 'bearer',
      'expires_in': 3600,
      'expires_at': expiry,
      'user': {
        'id': id,
        'aud': 'authenticated',
        'created_at': '2026-01-01T00:00:00Z',
        'app_metadata': <String, Object?>{},
        'user_metadata': <String, Object?>{},
      },
    }),
  );
}

Map<String, Object?> _row() => {
  'id': _notification,
  'user_id': _user,
  'type': 'general',
  'title': 'Synthetic account alert',
  'is_read': false,
  'visible_in_app': true,
  'created_at': '2026-09-15T00:00:00Z',
};

http.Response _response(
  http.Request request,
  Object body, {
  int status = 200,
}) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json', 'content-range': '0-0/1'},
  request: request,
);

Future<({SupabaseClient client, NotificationService service})> _fixture(
  Future<http.Response> Function(http.Request) respond, {
  bool signedIn = true,
}) async {
  final client = SupabaseClient(
    'https://notifications-fixture.invalid',
    'mock-public-key',
    authOptions: const AuthClientOptions(autoRefreshToken: false),
    httpClient: MockClient((request) {
      expect(request.url.host, 'notifications-fixture.invalid');
      expect(request.url.path, '/rest/v1/notifications');
      return respond(request);
    }),
  );
  if (signedIn) await _signIn(client, _user);
  final service = NotificationService(supabase: client);
  addTearDown(() async {
    service.dispose();
    await client.dispose();
  });
  return (client: client, service: service);
}

void main() {
  final operations = <String, Future<Object?> Function(NotificationService)>{
    'inbox': (service) => service.getNotifications(),
    'unread inbox': (service) => service.getUnreadNotifications(),
    'unread count': (service) => service.getUnreadCount(),
    'mark one read': (service) => service.markAsRead(_notification),
    'mark all read': (service) => service.markAllAsRead(),
  };

  for (final operation in operations.entries) {
    test(
      '${operation.key} reports a rejected request and allows retry',
      () async {
        var attempts = 0;
        final fixture = await _fixture((request) async {
          if (++attempts == 1) {
            return _response(request, {
              'message': 'Synthetic backend failure',
              'code': 'P0001',
            }, status: 503);
          }
          return _response(request, [_row()]);
        });
        await expectLater(
          operation.value(fixture.service),
          throwsA(isA<app.AppException>()),
        );
        await operation.value(fixture.service);
        expect(attempts, 2);
      },
    );
  }

  for (final operation in operations.entries) {
    test(
      '${operation.key} rejects a late result after an account switch',
      () async {
        final entered = Completer<void>();
        final response = Completer<http.Response>();
        late http.Request pending;
        final fixture = await _fixture((request) {
          pending = request;
          entered.complete();
          return response.future;
        });
        final result = operation.value(fixture.service);
        final assertion = expectLater(
          result,
          throwsA(isA<app.AuthException>()),
        );
        await entered.future;
        await _signIn(fixture.client, _peer);
        response.complete(_response(pending, [_row()]));
        await assertion;
      },
    );
  }

  test('mark one read rejects zero affected rows', () async {
    final fixture = await _fixture((request) async => _response(request, []));
    await expectLater(
      fixture.service.markAsRead(_notification),
      throwsA(isA<app.NotFoundException>()),
    );
  });

  test(
    'mark one read scopes and confirms the current visible notification',
    () async {
      late http.Request sent;
      final fixture = await _fixture((request) async {
        sent = request;
        return _response(request, [
          {'id': _notification},
        ]);
      });
      await fixture.service.markAsRead(_notification);
      expect(sent.method, 'PATCH');
      expect(sent.url.queryParameters['id'], 'eq.$_notification');
      expect(sent.url.queryParameters['user_id'], 'eq.$_user');
      expect(sent.url.queryParameters['visible_in_app'], 'eq.true');
      expect(sent.headers['Prefer'], contains('return=representation'));
    },
  );

  test('a signed-out read is empty but writes require an account', () async {
    var requests = 0;
    final fixture = await _fixture((request) async {
      requests++;
      return _response(request, []);
    }, signedIn: false);
    expect(await fixture.service.getNotifications(), isEmpty);
    expect(await fixture.service.getUnreadNotifications(), isEmpty);
    expect(await fixture.service.getUnreadCount(), 0);
    await expectLater(
      fixture.service.markAsRead(_notification),
      throwsA(isA<app.AuthException>()),
    );
    await expectLater(
      fixture.service.markAllAsRead(),
      throwsA(isA<app.AuthException>()),
    );
    expect(requests, 0);
  });

  test('successful reads preserve visible rows and the exact count', () async {
    final fixture = await _fixture((request) async {
      expect(request.url.queryParameters['user_id'], 'eq.$_user');
      expect(request.url.queryParameters['visible_in_app'], 'eq.true');
      return _response(request, [_row()]);
    });
    expect((await fixture.service.getNotifications()).single.id, _notification);
    expect(
      (await fixture.service.getUnreadNotifications()).single.isRead,
      isFalse,
    );
    expect(await fixture.service.getUnreadCount(), 1);
  });
}
