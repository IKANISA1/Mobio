import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobi_app/core/async/account_epoch.dart';
import 'package:mobi_app/core/auth/account_context.dart';
import 'package:mobi_app/features/privacy/data/privacy_service.dart';
import 'package:mobi_app/features/privacy/domain/privacy_request.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const account = AccountSnapshot(
  '11111111-1111-4111-8111-111111111111',
  'session-a',
  0,
);
const requestId = '22222222-2222-4222-8222-222222222222';

void main() {
  Future<SupabaseClient> client({
    String? reply,
    int status = 200,
    void Function()? onRequest,
  }) async {
    final value = SupabaseClient(
      'https://privacy-contract.invalid',
      'mock-public-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((_) async {
        onRequest?.call();
        if (reply == null) throw const SocketException('lost');
        return http.Response(
          reply,
          status,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    addTearDown(value.dispose);
    final expiry = DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600;
    String part(Object data) =>
        base64Url.encode(utf8.encode(jsonEncode(data))).replaceAll('=', '');
    await value.auth.recoverSession(
      jsonEncode({
        'access_token':
            '${part({'alg': 'none'})}.${part({'sub': account.userId, 'exp': expiry})}.fixture',
        'refresh_token': 'fixture-refresh',
        'token_type': 'bearer',
        'expires_at': expiry,
        'expires_in': 3600,
        'user': {
          'id': account.userId,
          'aud': 'authenticated',
          'created_at': '2026-01-01T00:00:00Z',
          'app_metadata': {},
          'user_metadata': {},
        },
      }),
    );
    return value;
  }

  final validRequest = {
    'request_id': requestId,
    'status': 'requested',
    'revision': 0,
    'notice_version': 'v1',
    'requested_at': '2026-09-30T12:00:00Z',
    'updated_at': '2026-09-30T12:00:00Z',
    'can_cancel': true,
    'retained_categories': <String>[],
    'completion_evidence_recorded': false,
  };
  Map<String, Object?> envelope(Object? request) => {
    'protocol': 'mobio.privacy.v1',
    'owner_id': account.userId,
    'request': request,
  };
  for (final body in <Object?>[
    null,
    {},
    envelope(null),
    envelope({}),
    envelope({...validRequest, 'request_id': account.userId}),
    envelope({...validRequest, 'status': 'invented'}),
  ]) {
    for (final action in ['request', 'cancel']) {
      test(
        'malformed $action success retains original request: $body',
        () async {
          var calls = 0;
          final service = PrivacyService(
            client: await client(
              reply: jsonEncode(body),
              onRequest: () => calls++,
            ),
            requireCurrent: (_) {},
          );
          await expectLater(
            action == 'request'
                ? service.request(account, requestId, 'v1')
                : service.cancel(account, requestId),
            throwsA(
              isA<PrivacyOutcomeUnknown>()
                  .having((e) => e.code, 'code', 'OUTCOME_UNKNOWN')
                  .having((e) => e.operationId, 'original identity', requestId),
            ),
          );
          expect(calls, 1);
        },
      );
    }
  }

  test('valid submission receipt is retained', () async {
    final service = PrivacyService(
      client: await client(reply: jsonEncode(envelope(validRequest))),
      requireCurrent: (_) {},
    );
    final result = await service.request(account, requestId, 'v1');
    expect(result.id, requestId);
    expect(result.status, 'requested');
  });

  test('malformed policy read remains known unavailable', () async {
    final service = PrivacyService(
      client: await client(reply: 'null'),
      requireCurrent: (_) {},
    );
    await expectLater(
      service.policy(account),
      throwsA(
        isA<PrivacyFailure>().having(
          (e) => e.code,
          'code',
          'BACKEND_UNAVAILABLE',
        ),
      ),
    );
  });

  test('explicit privacy rejection remains known', () async {
    final service = PrivacyService(
      client: await client(reply: '{"error":"NOT_CANCELLABLE"}', status: 409),
      requireCurrent: (_) {},
    );
    await expectLater(
      service.cancel(account, requestId),
      throwsA(
        isA<PrivacyFailure>().having((e) => e.code, 'code', 'NOT_CANCELLABLE'),
      ),
    );
  });

  test(
    'lost privacy submission preserves an uncertain request outcome',
    () async {
      final service = PrivacyService(
        client: await client(),
        requireCurrent: (_) {},
      );
      await expectLater(
        service.request(account, requestId, 'v1'),
        throwsA(
          isA<PrivacyFailure>().having(
            (e) => e.code,
            'code',
            'OUTCOME_UNKNOWN',
          ),
        ),
      );
    },
  );

  test('uncertain failure from stale account is discarded', () async {
    var checks = 0;
    final service = PrivacyService(
      client: await client(),
      requireCurrent: (_) {
        if (++checks > 1) throw const StaleAccountWork();
      },
    );
    await expectLater(
      service.cancel(account, requestId),
      throwsA(isA<StaleAccountWork>()),
    );
  });
}
