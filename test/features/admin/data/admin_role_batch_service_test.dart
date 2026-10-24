import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mobi_app/core/auth/admin_session_guard.dart';
import 'package:mobi_app/core/errors/app_exception.dart';
import 'package:mobi_app/features/admin/data/admin_user_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthException;

import '../../../helpers/admin_auth_sdk_fixture.dart' as sdk;
import '../fixtures/admin_user_protocol_fixture.dart';

http.Response response(Object? value) => http.Response(
  jsonEncode(value),
  200,
  headers: {'content-type': 'application/json'},
);

void main() {
  setUp(AdminSessionGuard.resetForTesting);
  tearDown(AdminSessionGuard.resetForTesting);
  Future<SupabaseClient> client(
    Future<http.Response> Function(http.Request) handler,
  ) async {
    final value = SupabaseClient(
      'https://admin-role.invalid',
      'synthetic-public',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: sdk.sdkFixtureHttpClient(handler),
    );
    addTearDown(value.dispose);
    await value.auth.recoverSession(sdk.savedSession());
    return value;
  }

  test(
    'reserve sends immutable tuple revisions, receives server IDs and never executes implicitly',
    () async {
      final review = fixtureReview();
      var calls = 0;
      final value = await client((request) async {
        calls++;
        expect(request.url.path, '/rest/v1/rpc/rpc_admin_role_reserve');
        expect(jsonDecode(request.body), {
          'p_reservation_id': review.reservationId,
          'p_snapshot_id': review.snapshotId,
          'p_targets': review.entries
              .map((entry) => entry.toReserveTarget())
              .toList(),
        });
        return response(fixtureRoleJson(review));
      });
      final envelope = await AdminUserService(
        supabase: value,
      ).reserveRoleChange(review);
      expect(envelope.batch!.batchId, fixtureBatch);
      expect(envelope.operations.length, 3);
      expect(calls, 1);
    },
  );
  test(
    'real SDK execute matches server-owned operation and complete receipt',
    () async {
      final review = fixtureReview();
      final previous = fixtureEnvelope(review);
      var calls = 0;
      final value = await client((request) async {
        calls++;
        expect(jsonDecode(request.body), {
          'p_batch_id': fixtureBatch,
          'p_operation_id': fixtureOperation(1),
        });
        return response(
          fixtureRoleJson(
            review,
            statuses: ['confirmed', 'prepared', 'prepared'],
          ),
        );
      });
      final result = await AdminUserService(
        supabase: value,
      ).executeRoleChange(envelope: previous, operationId: fixtureOperation(1));
      expect(result.operations.first.receipt!.targetId, fixtureTarget(1));
      expect(calls, 1);
    },
  );
  for (final mutation in [
    'missing_receipt',
    'changed_target',
    'driver_flag',
    'batch_expiry',
    'same_audit_changed_time',
  ]) {
    test(
      'malformed or changed successful execute response is unknown: $mutation',
      () async {
        final review = fixtureReview();
        final previous = fixtureEnvelope(
          review,
          statuses: ['confirmed', 'prepared', 'prepared'],
        );
        var calls = 0;
        final raw = fixtureRoleJson(
          review,
          statuses: ['confirmed', 'confirmed', 'prepared'],
        );
        final recipient = (raw['operations'] as List)[1] as Map;
        switch (mutation) {
          case 'missing_receipt':
            recipient['receipt'] = null;
          case 'changed_target':
            (recipient['receipt'] as Map)['target_id'] = fixtureTarget(9);
          case 'driver_flag':
            (recipient['receipt'] as Map)['after_is_driver'] = false;
          case 'batch_expiry':
            (raw['batch'] as Map)['execute_expires_at'] = fixtureNow
                .add(const Duration(minutes: 9))
                .toIso8601String();
          case 'same_audit_changed_time':
            final first = (raw['operations'] as List).first as Map;
            final changed = fixtureNow
                .add(const Duration(seconds: 2))
                .toIso8601String();
            first['decided_at'] = changed;
            (first['receipt'] as Map)['committed_at'] = changed;
        }
        final value = await client((_) async {
          calls++;
          return response(raw);
        });
        await expectLater(
          AdminUserService(supabase: value).executeRoleChange(
            envelope: previous,
            operationId: fixtureOperation(2),
          ),
          throwsA(isA<MutationOutcomeUnknownException>()),
        );
        expect(calls, 1);
      },
    );
  }
  test(
    'successful late reply after replacement SID becomes unknown and cannot bind the new account',
    () async {
      final review = fixtureReview();
      final reply = Completer<http.Response>();
      final sent = Completer<void>();
      final value = await client((_) {
        sent.complete();
        return reply.future;
      });
      final work = AdminUserService(supabase: value).executeRoleChange(
        envelope: fixtureEnvelope(review),
        operationId: fixtureOperation(1),
      );
      final assertion = expectLater(
        work,
        throwsA(isA<MutationOutcomeUnknownException>()),
      );
      await sent.future;
      await value.auth.recoverSession(
        sdk.savedSession(session: fixtureNextSession),
      );
      reply.complete(
        response(
          fixtureRoleJson(
            review,
            statuses: ['confirmed', 'prepared', 'prepared'],
          ),
        ),
      );
      await assertion;
    },
  );
  test(
    'explicit freshness rejection fences SID; status and seal require no step-up client grant',
    () async {
      final review = fixtureReview();
      final paths = <String>[];
      final value = await client((request) async {
        paths.add(request.url.path);
        if (request.url.path.endsWith('rpc_admin_role_execute')) {
          return sdk.rejected();
        }
        return response(
          fixtureEmptyRoleJson(
            reservation: review.reservationId,
            sealed: request.url.path.endsWith('rpc_admin_role_seal'),
          ),
        );
      });
      sdk.lease();
      final service = AdminUserService(supabase: value);
      await expectLater(
        service.executeRoleChange(
          envelope: fixtureEnvelope(review),
          operationId: fixtureOperation(1),
        ),
        throwsA(isA<AdminReauthenticationRequiredException>()),
      );
      expect(AdminSessionGuard.isAdmin, false);
      final absent = await service.roleChangeStatus(
        reservationId: review.reservationId,
      );
      expect(absent.isSealed, false);
      final sealed = await service.sealRoleChange(
        reservationId: review.reservationId,
      );
      expect(sealed.isSealed, true);
      expect(paths.length, 3);
      expect(
        paths.where((path) => path.endsWith('rpc_admin_role_execute')).length,
        1,
      );
    },
  );
  test(
    'real SDK explicit database rejection remains known instead of transport unknown',
    () async {
      final review = fixtureReview();
      final value = await client(
        (_) async =>
            sdk.rejected(code: '42501', message: 'ADMIN_ROLE_MANAGE_REQUIRED'),
      );
      await expectLater(
        AdminUserService(supabase: value).executeRoleChange(
          envelope: fixtureEnvelope(review),
          operationId: fixtureOperation(1),
        ),
        throwsA(isA<PostgrestException>()),
      );
    },
  );
}
