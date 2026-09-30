import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobi_app/core/async/account_epoch.dart';
import 'package:mobi_app/core/auth/account_context.dart';
import 'package:mobi_app/features/biopay/data/biopay_face_service.dart';
import 'package:mobi_app/features/biopay/data/payment_discovery_service.dart';
import 'package:mobi_app/features/notifications/data/notification_consent_service.dart';
import 'package:mobi_shared_types/models/notification_consent_settings.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'biopay_face_service_boundary_test.dart' show signIn;

void main() {
  late SupabaseClient client;
  late Completer<http.Response> reply;
  late Completer<void> started;
  late http.Request request;
  var generation = 0;
  const owner = '11111111-1111-4111-8111-111111111111';
  AccountSnapshot capture() => AccountSnapshot(owner, 'fixture', generation);
  bool current(AccountSnapshot snapshot) => snapshot.generation == generation;
  void require(AccountSnapshot snapshot) {
    if (!current(snapshot)) throw const StaleAccountWork();
  }

  setUp(() async {
    generation = 0;
    reply = Completer<http.Response>();
    started = Completer<void>();
    client = SupabaseClient(
      'https://callback-contract.invalid',
      'mock-public-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((value) {
        request = value;
        if (!started.isCompleted) started.complete();
        return reply.future;
      }),
    );
    await signIn(client);
    addTearDown(client.dispose);
  });
  void respond(String body, {int status = 200}) => reply.complete(
    http.Response(
      body,
      status,
      headers: {'content-type': 'application/json'},
      request: request,
    ),
  );
  for (final action in ['status', 'enroll']) {
    test(
      'Face $action rejects a late reply after same-owner session replacement',
      () async {
        final service = BioPayFaceService(
          supabase: client,
          captureAccount: capture,
          isCurrent: current,
        );
        final pending = service.invoke(action);
        final failure = expectLater(
          pending,
          throwsA(
            isA<FaceServiceException>().having(
              (error) => error.code,
              'code',
              'AUTH_EXPIRED',
            ),
          ),
        );
        await started.future;
        generation++;
        respond('{"success":true,"status":"active","has_face":true}');
        await failure;
      },
    );
  }
  test(
    'discovery rejects an old workspace before parsing or displaying it',
    () async {
      final service = PaymentDiscoveryService(
        client,
        captureAccount: capture,
        isCurrent: current,
      );
      final failure = expectLater(
        service.call('workspace', {}),
        throwsA(isA<StaleAccountWork>()),
      );
      await started.future;
      generation++;
      respond(
        '{"methods":[],"drafts":[],"links":[],"recents":[],"templates":[],"activity":[]}',
      );
      await failure;
    },
  );
  test('discovery rejects a late mutation acknowledgement', () async {
    final service = PaymentDiscoveryService(
      client,
      captureAccount: capture,
      isCurrent: current,
    );
    final failure = expectLater(
      service.call('remove_method', {'id': 'old'}),
      throwsA(isA<StaleAccountWork>()),
    );
    await started.future;
    generation++;
    respond('{}');
    await failure;
  });
  test('consent read rejects settings from the previous session', () async {
    final service = NotificationConsentService(
      supabase: client,
      captureAccount: capture,
      requireCurrent: require,
    );
    final failure = expectLater(
      service.getSettings(),
      throwsA(isA<StaleAccountWork>()),
    );
    await started.future;
    generation++;
    respond(
      '[{"consent_type":"promotional","channel":"push","status":"granted"}]',
    );
    await failure;
  });
  test('consent save rejects an old-session acknowledgement', () async {
    final service = NotificationConsentService(
      supabase: client,
      captureAccount: capture,
      requireCurrent: require,
    );
    final failure = expectLater(
      service.saveSettings(
        const NotificationConsentSettings(promotionalPush: true),
      ),
      throwsA(isA<StaleAccountWork>()),
    );
    await started.future;
    generation++;
    respond('', status: 204);
    await failure;
  });
}
