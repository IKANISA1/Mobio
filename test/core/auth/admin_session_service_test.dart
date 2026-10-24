import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mobi_app/core/auth/account_context.dart';
import 'package:mobi_app/core/auth/admin_session_guard.dart';
import 'package:mobi_app/core/auth/admin_session_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../helpers/admin_auth_sdk_fixture.dart';

void main() {
  setUp(AdminSessionGuard.resetForTesting);
  tearDown(AdminSessionGuard.resetForTesting);

  Future<SupabaseClient> client(
    Future<http.Response> Function(http.Request) handler,
  ) async {
    final value = SupabaseClient(
      'https://admin-status.invalid',
      'synthetic-public',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: sdkFixtureHttpClient(handler),
    );
    addTearDown(value.dispose);
    await value.auth.recoverSession(savedSession());
    return value;
  }

  for (final replacement in ['same-owner-new-session', 'other-owner']) {
    test(
      'new $replacement status does not join old SDK read or get revoked by it',
      () async {
        final oldResponse = Completer<http.Response>();
        final dispatched = Completer<void>();
        var requests = 0, generation = 1;
        final user = replacement == 'other-owner' ? other : owner;
        final value = await client((_) {
          requests++;
          if (requests == 1) {
            dispatched.complete();
            return oldResponse.future;
          }
          return Future.value(leaseResponse(user: user, session: nextSid));
        });
        AccountSnapshot capture() => AccountSnapshot(
          value.auth.currentUser!.id,
          AccountContext.sessionId(value.auth.currentSession)!,
          generation,
        );
        final service = AdminSessionSynchronizer(
          captureAccount: capture,
          isCurrent: (snapshot) =>
              snapshot.identity == capture().identity &&
              snapshot.generation == generation,
          readLease: (activity) => value.rpc<dynamic>(
            'rpc_admin_session',
            params: {'p_action': activity ? 'touch' : 'status'},
          ),
        );
        final old = service.synchronize();
        await dispatched.future;
        generation++;
        await value.auth.recoverSession(
          savedSession(user: user, session: nextSid),
        );
        final current = service.synchronize();
        expect(current, isNot(same(old)));
        expect(await current, isTrue);
        expect(AdminSessionGuard.isAdminFor(user, sessionId: nextSid), isTrue);
        oldResponse.complete(rejected());
        expect(await old, isFalse);
        expect(requests, 2);
        expect(AdminSessionGuard.isAdminFor(user, sessionId: nextSid), isTrue);
      },
    );
  }

  test(
    'same generation status coalesces and a touch join never extends it',
    () async {
      final first = Completer<http.Response>();
      final actions = <String>[];
      final value = await client((request) {
        actions.add((jsonDecode(request.body) as Map)['p_action'] as String);
        return actions.length == 1
            ? first.future
            : Future.value(leaseResponse());
      });
      const snapshot = AccountSnapshot(owner, sid, 1);
      final service = AdminSessionSynchronizer(
        captureAccount: () => snapshot,
        isCurrent: (_) => true,
        readLease: (activity) => value.rpc<dynamic>(
          'rpc_admin_session',
          params: {'p_action': activity ? 'touch' : 'status'},
        ),
      );
      final status = service.synchronize();
      final touchJoin = service.synchronize(userActivity: true);
      expect(touchJoin, same(status));
      first.complete(leaseResponse());
      expect(await status, isTrue);
      expect(actions, ['status']);
      expect(await service.synchronize(userActivity: true), isTrue);
      expect(actions, ['status', 'touch']);
    },
  );

  for (final denial in [
    'inactive',
    'expired',
    'wrong-session',
    'step-up-blocked',
  ]) {
    test('$denial SDK status cannot admit or restore a lease', () async {
      final value = await client(
        (_) async => leaseResponse(
          active: denial != 'inactive',
          session: denial == 'wrong-session' ? nextSid : sid,
          idle: denial == 'expired'
              ? const Duration(seconds: -1)
              : const Duration(minutes: 15),
        ),
      );
      const snapshot = AccountSnapshot(owner, sid, 1);
      final service = AdminSessionSynchronizer(
        captureAccount: () => snapshot,
        isCurrent: (_) => true,
        readLease: (activity) => value.rpc<dynamic>(
          'rpc_admin_session',
          params: {'p_action': activity ? 'touch' : 'status'},
        ),
      );
      lease();
      if (denial == 'step-up-blocked')
        AdminSessionGuard.rejectSession(userId: owner, sessionId: sid);
      expect(await service.synchronize(), isFalse);
      expect(AdminSessionGuard.isAdmin, isFalse);
    });
  }

  test(
    'explicit revoke invalidation discards a late successful status',
    () async {
      final response = Completer<http.Response>();
      final value = await client((_) => response.future);
      const snapshot = AccountSnapshot(owner, sid, 1);
      final service = AdminSessionSynchronizer(
        captureAccount: () => snapshot,
        isCurrent: (_) => true,
        readLease: (activity) => value.rpc<dynamic>(
          'rpc_admin_session',
          params: {'p_action': activity ? 'touch' : 'status'},
        ),
      );
      lease();
      final old = service.synchronize();
      service.invalidate();
      AdminSessionGuard.revoke();
      response.complete(leaseResponse());
      expect(await old, isFalse);
      expect(AdminSessionGuard.isAdmin, isFalse);
    },
  );
}
