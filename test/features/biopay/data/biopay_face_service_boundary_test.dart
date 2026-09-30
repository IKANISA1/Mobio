import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobi_app/core/auth/account_context.dart';
import 'package:mobi_app/features/biopay/data/biopay_face_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> signIn(SupabaseClient client) async {
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
        'app_metadata': {},
        'user_metadata': {},
      },
    }),
  );
}

void main() {
  Future<BioPayFaceService> replyService(
    Object? body, {
    int status = 200,
    void Function()? onRequest,
  }) async {
    final client = SupabaseClient(
      'https://face-contract.invalid',
      'mock-public-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((_) async {
        onRequest?.call();
        return http.Response(
          jsonEncode(body),
          status,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    addTearDown(client.dispose);
    await signIn(client);
    return BioPayFaceService(
      supabase: client,
      captureAccount: () => const AccountSnapshot(
        '11111111-1111-4111-8111-111111111111',
        '22222222-2222-4222-8222-222222222222',
        0,
      ),
      isCurrent: (_) => true,
    );
  }

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
