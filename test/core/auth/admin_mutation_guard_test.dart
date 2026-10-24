import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mobi_app/core/auth/admin_mutation_guard.dart';
import 'package:mobi_app/core/auth/admin_session_guard.dart';
import 'package:mobi_app/core/errors/app_exception.dart';
import 'package:mobi_app/core/errors/app_exception_mapper.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthException;

import '../../helpers/admin_auth_sdk_fixture.dart';

void main() {
  setUp(AdminSessionGuard.resetForTesting);
  tearDown(AdminSessionGuard.resetForTesting);

  Future<SupabaseClient> client(
    Future<http.Response> Function(http.Request) handler,
  ) async {
    final value = SupabaseClient(
      'https://admin-mutation.invalid',
      'synthetic-public',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: sdkFixtureHttpClient(handler),
    );
    addTearDown(value.dispose);
    await value.auth.recoverSession(savedSession());
    return value;
  }

  Future<dynamic> mutate(
    SupabaseClient value, {
    Duration timeout = const Duration(seconds: 20),
  }) => AdminMutationGuard.run(
    value.rpc<dynamic>('rpc_sensitive_fixture'),
    client: value,
    operation: 'sensitive_fixture',
    operationId: 'fixture-operation',
    timeout: timeout,
  );

  test(
    'real SDK admitted response is returned once and retains the current lease',
    () async {
      var requests = 0;
      final value = await client((request) async {
        requests++;
        expect(request.url.path, '/rest/v1/rpc/rpc_sensitive_fixture');
        expect(request.headers['authorization'], startsWith('Bearer '));
        return http.Response(
          '{"accepted":true}',
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      lease();
      expect(await mutate(value), {'accepted': true});
      expect(requests, 1);
      expect(AdminSessionGuard.isAdminFor(owner, sessionId: sid), isTrue);
    },
  );

  test(
    'real SDK freshness rejection locks exact SID through refresh until new verification',
    () async {
      var requests = 0;
      final value = await client((_) async {
        requests++;
        return rejected();
      });
      lease();
      await expectLater(
        mutate(value),
        throwsA(isA<AdminReauthenticationRequiredException>()),
      );
      expect(requests, 1);
      expect(AdminSessionGuard.isAdmin, isFalse);
      AdminSessionGuard.touch(owner);
      AdminSessionGuard.revoke();
      // An SDK access-token refresh keeps the same session_id; it cannot step up.
      await value.auth.recoverSession(savedSession());
      expect(lease, throwsA(isA<AdminReauthenticationRequiredException>()));
      await value.auth.recoverSession(savedSession(session: nextSid));
      lease(session: nextSid);
      expect(AdminSessionGuard.isAdminFor(owner, sessionId: nextSid), isTrue);
      expect(lease, throwsA(isA<AdminReauthenticationRequiredException>()));
      expect(AdminSessionGuard.isAdminFor(owner, sessionId: nextSid), isTrue);
    },
  );

  for (final replacement in ['other-owner', 'same-owner-new-session']) {
    test('late HTTP rejection cannot lock $replacement', () async {
      final response = Completer<http.Response>();
      final dispatched = Completer<void>();
      var requests = 0;
      final value = await client((_) {
        requests++;
        dispatched.complete();
        return response.future;
      });
      lease();
      final work = mutate(value);
      final assertion = expectLater(
        work,
        throwsA(isA<AdminReauthenticationRequiredException>()),
      );
      await dispatched.future;
      final user = replacement == 'other-owner' ? other : owner;
      await value.auth.recoverSession(
        savedSession(user: user, session: nextSid),
      );
      lease(user: user, session: nextSid);
      response.complete(rejected());
      await assertion;
      expect(requests, 1);
      expect(AdminSessionGuard.isAdminFor(user, sessionId: nextSid), isTrue);
      // The outgoing lease was not sticky-blocked by a result for another owner.
      lease();
      expect(AdminSessionGuard.isAdminFor(owner, sessionId: sid), isTrue);
    });
  }

  for (final denial in [
    (code: '42501', message: 'permission denied'),
    (code: '42501', message: 'ADMIN_REAUTHENTICATION_REQUIRED_EXTRA'),
    (code: 'P0001', message: 'ADMIN_REAUTHENTICATION_REQUIRED'),
  ]) {
    test(
      'unrelated ${denial.code} ${denial.message} does not lock a current admin',
      () async {
        final value = await client(
          (_) async => rejected(code: denial.code, message: denial.message),
        );
        lease();
        await expectLater(mutate(value), throwsA(isA<PostgrestException>()));
        expect(AdminSessionGuard.isAdminFor(owner, sessionId: sid), isTrue);
      },
    );
  }

  test('pure exception mapping never alters the guard', () {
    lease();
    final error = AppExceptionMapper.map(
      const PostgrestException(
        code: '42501',
        message: 'ADMIN_REAUTHENTICATION_REQUIRED',
      ),
    );
    expect(error, isA<AdminReauthenticationRequiredException>());
    expect(error, isA<ForbiddenException>());
    expect(AdminSessionGuard.isAdminFor(owner, sessionId: sid), isTrue);
  });

  test(
    'lost SDK response stays unknown, never locks and never replays',
    () async {
      var requests = 0;
      final value = await client((_) async {
        requests++;
        throw const SocketException('Synthetic lost response');
      });
      lease();
      await expectLater(
        mutate(value),
        throwsA(
          isA<MutationOutcomeUnknownException>()
              .having((e) => e.operation, 'operation', 'sensitive_fixture')
              .having((e) => e.operationId, 'operationId', 'fixture-operation'),
        ),
      );
      expect(requests, 1);
      expect(AdminSessionGuard.isAdminFor(owner, sessionId: sid), isTrue);
    },
  );

  test(
    'deadline and late rejection do not replay or emit an unhandled error',
    () async {
      final response = Completer<http.Response>();
      var requests = 0;
      final value = await client((_) {
        requests++;
        return response.future;
      });
      lease();
      await expectLater(
        mutate(value, timeout: const Duration(milliseconds: 5)),
        throwsA(isA<MutationOutcomeUnknownException>()),
      );
      response.complete(rejected());
      await Future<void>.delayed(Duration.zero);
      expect(requests, 1);
      expect(AdminSessionGuard.isAdminFor(owner, sessionId: sid), isTrue);
    },
  );

  test(
    'unauthenticated rejection cannot block an unrelated leased session',
    () async {
      final value = SupabaseClient(
        'https://admin-mutation.invalid',
        'synthetic-public',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: sdkFixtureHttpClient((_) async => rejected()),
      );
      addTearDown(value.dispose);
      lease();
      await expectLater(
        mutate(value),
        throwsA(isA<AdminReauthenticationRequiredException>()),
      );
      expect(AdminSessionGuard.isAdminFor(owner, sessionId: sid), isTrue);
    },
  );
}
