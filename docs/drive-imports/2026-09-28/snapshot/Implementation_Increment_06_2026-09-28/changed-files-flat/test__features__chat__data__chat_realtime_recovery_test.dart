import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobi_app/features/chat/data/chat_service.dart';
import 'package:mobi_app/features/chat/domain/chat_message.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _conversation = '00000000-0000-4000-8000-000000000010';

Map<String, Object?> _message(String body) => {
  'id': '00000000-0000-4000-8000-${({'before':1,'during join':2,'while offline':3,'latest':4}[body]??5).toString().padLeft(12,'0')}',
  'conversation_id': _conversation,
  'sender_id': '00000000-0000-4000-8000-000000000002',
  'message_type': 'text',
  'body': body,
  'created_at': '2026-09-15T00:00:00Z',
  'access_redacted': false,
};

Future<void> _until(bool Function() condition, String reason) async {
  final deadline = DateTime.now().add(const Duration(seconds: 4));
  while (!condition() && DateTime.now().isBefore(deadline)) {
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  expect(condition(), isTrue, reason: reason);
}

// The HTTP responses and websocket protocol are deliberately mocked here.
// These tests exercise the production ChatService and pinned Dart SDK lifecycle;
// they do not qualify authentication, SQL authorization or a real Realtime server.
class _Fixture {
  late HttpServer server;
  late SupabaseClient client;
  final sockets = <WebSocket>[];
  final joins = <({WebSocket socket, Map<String, dynamic> request})>[];
  final snapshots = <List<ChatMessageModel>>[];
  final errors = <Object>[];
  final acknowledgedJoins = <String>{};
  List<Map<String, Object?>> rows = [_message('before')];
  Future<http.Response> Function(http.Request)? respond;
  StreamSubscription<List<ChatMessageModel>>? listener;
  bool closing = false;
  int reads = 0;
  int activeReads = 0;
  int maxConcurrentReads = 0;

  http.Response response(http.Request request, {int status = 200}) =>
      http.Response(
        jsonEncode(
          status == 200 ? rows.reversed.toList() : {'message': 'retry', 'code': 'P0001'},
        ),
        status,
        headers: {'content-type': 'application/json'},
        request: request,
      );

  Future<void> start() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      expect(request.uri.path, '/realtime/v1/websocket');
      final socket = await WebSocketTransformer.upgrade(request);
      sockets.add(socket);
      socket.listen((data) {
        final frame = jsonDecode(data as String) as Map<String, dynamic>;
        if (frame['event'] == 'phx_join') {
          joins.add((socket: socket, request: frame));
        } else if ((frame['event'] == 'phx_leave' ||
                frame['event'] == 'heartbeat') &&
            socket.readyState == WebSocket.open &&
            !closing) {
          socket.add(
            jsonEncode({
              'topic': frame['topic'],
              'event': 'phx_reply',
              'ref': frame['ref'],
              'payload': {'status': 'ok', 'response': <String, Object?>{}},
            }),
          );
        }
      });
    });
    client = SupabaseClient(
      'http://127.0.0.1:${server.port}',
      'mock-public-key-no-server-authentication',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      realtimeClientOptions: const RealtimeClientOptions(
        timeout: Duration(seconds: 10),
      ),
      httpClient: MockClient((request) async {
        expect(request.url.host, '127.0.0.1');
        expect(request.url.path, '/rest/v1/rpc/rpc_list_chat_messages_page');
        reads++;
        activeReads++;
        if (activeReads > maxConcurrentReads) {
          maxConcurrentReads = activeReads;
        }
        try {
          return await (respond?.call(request) ??
              Future.value(response(request)));
        } finally {
          activeReads--;
        }
      }),
    );
    client.realtime.onMessage((dynamic message) {
      if (message is Map &&
          message['event'] == 'phx_reply' &&
          message['payload']['status'] == 'ok' &&
          message['payload']['response']['postgres_changes'] != null) {
        acknowledgedJoins.add(message['ref'] as String);
      }
    });
    listener = ChatService(
      supabase: client,
      captureAuthority: () => ChatAuthority('00000000-0000-4000-8000-000000000001', () {}),
    ).streamMessages(_conversation).listen(snapshots.add, onError: errors.add);
  }

  Future<void> joined(int index) async {
    await _until(() => joins.length > index, 'SDK must send the expected join');
    final join = joins[index];
    final filters =
        (join.request['payload']['config']['postgres_changes'] as List)
            .map((filter) => {...filter as Map, 'id': 17})
            .toList();
    join.socket.add(
      jsonEncode({
        'topic': join.request['topic'],
        'event': 'phx_reply',
        'ref': join.request['ref'],
        'payload': {
          'status': 'ok',
          'response': {'postgres_changes': filters},
        },
      }),
    );
    await _until(
      () => acknowledgedJoins.contains(join.request['ref']),
      'SDK must acknowledge the subscription before inspecting recovery',
    );
  }

  void changed() {
    final join = joins.last;
    join.socket.add(
      jsonEncode({
        'topic': join.request['topic'],
        'event': 'postgres_changes',
        'ref': null,
        'payload': {
          'ids': [17],
          'data': {
            'schema': 'public',
            'table': 'chat_conversations',
            'type': 'UPDATE',
            'columns': [
              {'name': 'id', 'type': 'uuid'},
            ],
            'record': {'id': _conversation},
            'old_record': <String, Object?>{},
            'commit_timestamp': '2026-09-15T00:00:01Z',
            'errors': null,
          },
        },
      }),
    );
  }

  List<String> get bodies => snapshots.last.map((m) => m.body).toList();

  Future<void> dispose() async {
    await listener?.cancel();
    listener = null;
    closing = true;
    await client.dispose();
    for (final socket in sockets) {
      await socket.close();
    }
    await server.close(force: true);
  }
}

void main() {
  test(
    'subscription catches messages committed after the initial fetch',
    () async {
      final fixture = _Fixture();
      await fixture.start();
      addTearDown(fixture.dispose);
      await _until(
        () => fixture.snapshots.isNotEmpty,
        'Initial history must load',
      );
      expect(fixture.bodies, ['before']);
      fixture.rows.add(_message('during join'));
      await fixture.joined(0);
      await _until(
        () => fixture.bodies.contains('during join'),
        'Joining must fetch messages that arrived before changes were subscribed',
      );
      expect(fixture.errors, isEmpty);
    },
  );

  test('rejoining catches missed messages without needing a new event', () async {
    final fixture = _Fixture();
    await fixture.start();
    addTearDown(fixture.dispose);
    await fixture.joined(0);
    await _until(
      () => fixture.snapshots.isNotEmpty,
      'Initial history must load',
    );
    await fixture.sockets.last.close(
      WebSocketStatus.goingAway,
      'fixture outage',
    );
    await _until(
      () => !fixture.client.realtime.isConnected,
      'Socket must close',
    );
    fixture.rows.add(_message('while offline'));
    await fixture.joined(1);
    await _until(
      () => fixture.bodies.contains('while offline'),
      'A successful rejoin must reconcile history without a later change event',
    );
    expect(fixture.errors, isEmpty);
  });

  test(
    'join and duplicate changes coalesce behind an in-flight fetch',
    () async {
      final pending = Completer<http.Response>();
      final initialRequest = Completer<http.Request>();
      final fixture = _Fixture();
      fixture.respond = (request) {
        if (!initialRequest.isCompleted) {
          initialRequest.complete(request);
          return pending.future;
        }
        return Future.value(fixture.response(request));
      };
      await fixture.start();
      addTearDown(fixture.dispose);
      final request = await initialRequest.future;
      final oldResponse = fixture.response(request);
      fixture.rows.add(_message('latest'));
      await fixture.joined(0);
      fixture
        ..changed()
        ..changed();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      pending.complete(oldResponse);
      await _until(
        () => fixture.snapshots.isNotEmpty && fixture.bodies.contains('latest'),
        'Queued changes must reconcile the latest snapshot after the first read',
      );
      expect(fixture.maxConcurrentReads, 1);
      expect(fixture.reads, 2);
      expect(fixture.bodies, ['before', 'latest']);
    },
  );

  test('cancelling drops an in-flight result and queued refreshes', () async {
    final pending = Completer<http.Response>();
    final initialRequest = Completer<http.Request>();
    final fixture = _Fixture()
      ..respond = (request) {
        if (!initialRequest.isCompleted) initialRequest.complete(request);
        return pending.future;
      };
    await fixture.start();
    addTearDown(fixture.dispose);
    final request = await initialRequest.future;
    await fixture.joined(0);
    fixture.changed();
    await Future<void>.delayed(const Duration(milliseconds: 30));
    await fixture.listener!.cancel();
    fixture.listener = null;
    pending.complete(fixture.response(request));
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(fixture.snapshots, isEmpty);
    expect(fixture.errors, isEmpty);
    expect(fixture.reads, 1);
    expect(fixture.client.getChannels(), isEmpty);
  });

  test(
    'a failed refresh does not prevent a later successful reconciliation',
    () async {
      final fixture = _Fixture();
      var reject = true;
      fixture.respond = (request) async =>
          fixture.response(request, status: reject ? 503 : 200);
      await fixture.start();
      addTearDown(fixture.dispose);
      await _until(() => fixture.errors.isNotEmpty, 'Failure must be surfaced');
      reject = false;
      fixture.rows.add(_message('recovered'));
      await fixture.joined(0);
      await _until(
        () =>
            fixture.snapshots.isNotEmpty &&
            fixture.bodies.contains('recovered'),
        'Joining must retry the failed initial history read',
      );
      expect(fixture.maxConcurrentReads, 1);
    },
  );
}
