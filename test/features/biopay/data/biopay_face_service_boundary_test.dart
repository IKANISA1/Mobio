import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobi_app/core/auth/account_context.dart';
import 'package:mobi_app/core/auth/admin_session_guard.dart';
import 'package:mobi_app/core/errors/app_exception.dart';
import 'package:mobi_app/features/biopay/data/biopay_face_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> signIn(SupabaseClient client, {String? provider}) async {
  String part(Object data) =>
      base64Url.encode(utf8.encode(jsonEncode(data))).replaceAll('=', '');
  const userId = '11111111-1111-4111-8111-111111111111';
  final expiry = DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600;
  await client.auth.recoverSession(
    jsonEncode({
      'access_token':
          '${part({'alg': 'none'})}.${part({'sub': userId, 'exp': expiry, 'session_id': '22222222-2222-4222-8222-222222222222'})}.fixture',
      'refresh_token': 'fixture-refresh',
      'token_type': 'bearer',
      'expires_at': expiry,
      'expires_in': 3600,
      'user': {
        'id': userId,
        'aud': 'authenticated',
        'is_anonymous': false,
        'created_at': '2026-01-01T00:00:00Z',
        'app_metadata': {if (provider != null) 'provider': provider},
        'user_metadata': {},
      },
    }),
  );
}

void main() {
  setUp(AdminSessionGuard.resetForTesting);
  tearDown(AdminSessionGuard.resetForTesting);
  Future<BioPayFaceService> replyService(
    Object? body, {
    int status = 200,
    void Function()? onRequest,
    void Function(Map<String, dynamic>)? onPayload,
    String? provider,
    bool Function(AccountSnapshot)? isCurrent,
    AccountSnapshot Function()? captureAccount,
  }) async {
    final client = SupabaseClient(
      'https://face-contract.invalid',
      'mock-public-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((request) async {
        onRequest?.call();
        if (request.body.isNotEmpty) {
          onPayload?.call(
            Map<String, dynamic>.from(jsonDecode(request.body) as Map),
          );
        }
        return http.Response(
          jsonEncode(body),
          status,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    addTearDown(client.dispose);
    await signIn(client, provider: provider);
    return BioPayFaceService(
      supabase: client,
      captureAccount:
          captureAccount ??
          () => const AccountSnapshot(
            '11111111-1111-4111-8111-111111111111',
            '22222222-2222-4222-8222-222222222222',
            0,
          ),
      isCurrent: isCurrent ?? (_) => true,
    );
  }

  test(
    'preparation sends only lookup identity and reads the current shortcut',
    () async {
      const requestId = '33333333-3333-4333-8333-333333333333';
      Map<String, dynamic>? payload;
      final service = await replyService({
        'success': true,
        'status': 'dial_ready',
        'request_id': requestId,
        'payee_id': '66666666-6666-4666-8666-666666666666',
        'receiving_method_id': '44444444-4444-4444-8444-444444444444',
        'receiving_method_version': 3,
        'provider': 'mtn_rw',
        'route_id': '55555555-5555-4555-8555-555555555555',
        'route_version': 2,
        'ussd_code': '*182*1*1*0700000000#',
        'expires_at': DateTime.now()
            .toUtc()
            .add(const Duration(seconds: 30))
            .toIso8601String(),
      }, onPayload: (value) => payload = value);
      final prepared = await service.prepareHandoff(requestId);
      expect(payload, {'action': 'prepare_handoff', 'request_id': requestId});
      expect(prepared.requestId, requestId);
      expect(prepared.receivingMethodVersion, 3);
      expect(prepared.ussdCode, '*182*1*1*0700000000#');
      expect(prepared.isCurrent(DateTime.now()), isTrue);
    },
  );

  test(
    'unproved identity cannot issue a Face provider health request',
    () async {
      var calls = 0;
      final service = await replyService(
        {'production_ready': true},
        onRequest: () => calls++,
        captureAccount: () => throw StateError('NO_INTERACTIVE_PROOF'),
      );
      await expectLater(
        service.health(),
        throwsA(
          isA<FaceServiceException>().having(
            (e) => e.code,
            'code',
            'AUTH_EXPIRED',
          ),
        ),
      );
      expect(calls, 0);
    },
  );

  test(
    'malformed preparation is a known read failure with no mutation',
    () async {
      var calls = 0;
      final service = await replyService({
        'success': true,
        'status': 'dial_ready',
      }, onRequest: () => calls++);
      await expectLater(
        service.prepareHandoff('request'),
        throwsA(
          isA<FaceServiceException>()
              .having((e) => e.code, 'code', 'SERVICE_UNAVAILABLE')
              .having((e) => e.operation, 'no mutation identity', isNull),
        ),
      );
      expect(calls, 1);
    },
  );

  const adminUser = '11111111-1111-4111-8111-111111111111';
  const adminSession = '22222222-2222-4222-8222-222222222222';
  void acceptLease(String session) => AdminSessionGuard.acceptServerLease(
    userId: adminUser,
    sessionId: session,
    idleRemaining: const Duration(minutes: 5),
    absoluteRemaining: const Duration(hours: 1),
  );
  test(
    'exact Face freshness rejection permanently fences this Admin SID',
    () async {
      acceptLease(adminSession);
      final service = await replyService(
        {'success': false, 'code': 'ADMIN_REAUTHENTICATION_REQUIRED'},
        status: 403,
        provider: 'admin_whatsapp_otp',
      );
      await expectLater(
        service.prepareHandoff('request'),
        throwsA(
          isA<FaceServiceException>().having(
            (e) => e.code,
            'code',
            'ADMIN_REAUTHENTICATION_REQUIRED',
          ),
        ),
      );
      expect(
        AdminSessionGuard.isAdminFor(adminUser, sessionId: adminSession),
        isFalse,
      );
      expect(
        () => acceptLease(adminSession),
        throwsA(isA<AdminReauthenticationRequiredException>()),
      );
      acceptLease('33333333-3333-4333-8333-333333333333');
      expect(AdminSessionGuard.isAdmin, isTrue);
    },
  );

  test(
    'generic Face forbidden response cannot reject an Admin lease',
    () async {
      acceptLease(adminSession);
      final service = await replyService(
        {'success': false, 'code': 'RECIPIENT_UNAVAILABLE'},
        status: 403,
        provider: 'admin_whatsapp_otp',
      );
      await expectLater(
        service.prepareHandoff('request'),
        throwsA(isA<FaceServiceException>()),
      );
      expect(
        AdminSessionGuard.isAdminFor(adminUser, sessionId: adminSession),
        isTrue,
      );
    },
  );

  test(
    'late Face freshness rejection cannot fence a replacement SID',
    () async {
      var current = true;
      const nextSession = '33333333-3333-4333-8333-333333333333';
      acceptLease(adminSession);
      final service = await replyService(
        {'success': false, 'code': 'ADMIN_REAUTHENTICATION_REQUIRED'},
        status: 403,
        provider: 'admin_whatsapp_otp',
        isCurrent: (_) => current,
        onRequest: () {
          current = false;
          acceptLease(nextSession);
        },
      );
      await expectLater(
        service.prepareHandoff('request'),
        throwsA(
          isA<FaceServiceException>().having(
            (e) => e.code,
            'code',
            'AUTH_EXPIRED',
          ),
        ),
      );
      expect(
        AdminSessionGuard.isAdminFor(adminUser, sessionId: nextSession),
        isTrue,
      );
      acceptLease(adminSession);
      expect(
        AdminSessionGuard.isAdminFor(adminUser, sessionId: adminSession),
        isTrue,
      );
    },
  );

  for (final malformed in <Object?>[
    null,
    [],
    {'success': true},
    {'success': true, 'status': 'invented'},
    {'success': true, 'status': 1},
    {'status': 'active'},
  ]) {
    test('unusable enrollment reply stays unknown: $malformed', () async {
      var calls = 0;
      final service = await replyService(malformed, onRequest: () => calls++);
      await expectLater(
        service.enrollFace(
          imageBytes: [1, 2],
          methodId: 'method-1',
          idempotencyKey: 'enroll-1',
          consent: true,
        ),
        throwsA(
          isA<FaceServiceException>()
              .having((e) => e.code, 'code', 'OUTCOME_UNKNOWN')
              .having((e) => e.operation, 'operation', 'biopay_face:enroll')
              .having((e) => e.operationId, 'original identity', 'enroll-1'),
        ),
      );
      expect(calls, 1);
    });
  }

  for (final status in ['active', 'processing', 'cancelled']) {
    test('explicit server enrollment state $status is retained', () async {
      final service = await replyService({'success': true, 'status': status});
      expect(
        await service.enrollFace(
          imageBytes: [1, 2],
          methodId: 'method-1',
          idempotencyKey: 'enroll-1',
          consent: true,
        ),
        status,
      );
    });
  }

  test('unusable status read remains known unavailable', () async {
    final service = await replyService(null);
    await expectLater(
      service.enrollmentStatus(),
      throwsA(
        isA<FaceServiceException>().having(
          (e) => e.code,
          'code',
          'SERVICE_UNAVAILABLE',
        ),
      ),
    );
  });

  test('explicit provider rejection remains known', () async {
    final service = await replyService({
      'success': false,
      'code': 'CONSENT_REQUIRED',
    }, status: 400);
    await expectLater(
      service.enrollFace(
        imageBytes: [1, 2],
        methodId: 'method-1',
        idempotencyKey: 'enroll-1',
        consent: true,
      ),
      throwsA(
        isA<FaceServiceException>().having(
          (e) => e.code,
          'code',
          'CONSENT_REQUIRED',
        ),
      ),
    );
  });

  test(
    'invalid dial-ready mutation keeps its original lookup identity',
    () async {
      final service = await replyService({
        'success': true,
        'status': 'dial_ready',
      });
      await expectLater(
        service.resolveShortcut(
          imageBytes: [1, 2],
          idempotencyKey: 'resolve-1',
        ),
        throwsA(
          isA<FaceServiceException>()
              .having((e) => e.code, 'code', 'OUTCOME_UNKNOWN')
              .having((e) => e.operationId, 'original identity', 'resolve-1'),
        ),
      );
    },
  );

  test(
    'lost enrollment response exposes uncertainty instead of absence',
    () async {
      final client = SupabaseClient(
        'https://face-contract.invalid',
        'mock-public-key',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient(
          (_) async => throw const SocketException('lost'),
        ),
      );
      addTearDown(client.dispose);
      await signIn(client);
      await expectLater(
        BioPayFaceService(
          supabase: client,
          captureAccount: () => const AccountSnapshot(
            '11111111-1111-4111-8111-111111111111',
            '22222222-2222-4222-8222-222222222222',
            0,
          ),
          isCurrent: (_) => true,
        ).enrollFace(
          imageBytes: [1, 2],
          methodId: 'method-1',
          idempotencyKey: 'enroll-1',
          consent: true,
        ),
        throwsA(
          isA<FaceServiceException>().having(
            (e) => e.code,
            'code',
            'OUTCOME_UNKNOWN',
          ),
        ),
      );
    },
  );
}
