import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mobi_app/core/async/account_epoch.dart';
import 'package:mobi_app/features/admin/data/admin_user_service.dart';
import 'package:mobi_app/features/admin/domain/admin_user_query.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../helpers/admin_auth_sdk_fixture.dart' as sdk;
import '../fixtures/admin_user_protocol_fixture.dart';

void main() {
  test(
    'real SDK sends server sort/page/snapshot parameters and parses exact bound response',
    () async {
      final query = AdminUserQuery(
        role: 'driver',
        search: ' 100001 ',
        sort: 'name_asc',
      );
      var calls = 0;
      final client = SupabaseClient(
        'https://admin-page.invalid',
        'synthetic-public',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: sdk.sdkFixtureHttpClient((request) async {
          calls++;
          expect(request.url.path, '/rest/v1/rpc/rpc_admin_users_page');
          expect(jsonDecode(request.body), query.toRpcParameters());
          return http.Response(
            jsonEncode(fixturePageJson(query)),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      addTearDown(client.dispose);
      await client.auth.recoverSession(sdk.savedSession());
      final service = AdminUserService(supabase: client);
      final page = await service.listUsersPage(query);
      expect(calls, 1);
      expect(page.totalExact, 3);
      expect(page.query.sort, 'name_asc');
      expect(
        service.roleRecoveryOwner.hostIdentity,
        'https://admin-page.invalid',
      );
    },
  );
  test(
    'malformed read response fails validation without claiming empty members',
    () async {
      final query = AdminUserQuery();
      final client = SupabaseClient(
        'https://admin-page.invalid',
        'synthetic-public',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: sdk.sdkFixtureHttpClient(
          (_) async => http.Response(
            jsonEncode({...fixturePageJson(query)}..remove('total_exact')),
            200,
            headers: {'content-type': 'application/json'},
          ),
        ),
      );
      addTearDown(client.dispose);
      await client.auth.recoverSession(sdk.savedSession());
      await expectLater(
        AdminUserService(supabase: client).listUsersPage(query),
        throwsFormatException,
      );
    },
  );
  test(
    'release sends only the captured snapshot and accepts exact idempotent absence',
    () async {
      var calls = 0;
      final client = SupabaseClient(
        'https://admin-page.invalid',
        'synthetic-public',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: sdk.sdkFixtureHttpClient((request) async {
          calls++;
          expect(
            request.url.path,
            '/rest/v1/rpc/rpc_admin_users_release_snapshot',
          );
          expect(jsonDecode(request.body), {'p_snapshot_id': fixtureSnapshot});
          return http.Response(
            jsonEncode(fixtureReleaseJson(fixtureSnapshot, absent: calls > 1)),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      addTearDown(client.dispose);
      await client.auth.recoverSession(sdk.savedSession());
      final service = AdminUserService(supabase: client);
      expect(
        (await service.releaseUsersSnapshot(fixtureSnapshot)).released,
        true,
      );
      expect(
        (await service.releaseUsersSnapshot(fixtureSnapshot)).alreadyAbsent,
        true,
      );
      expect(calls, 2);
    },
  );
  test(
    'foreign snapshot rejection never becomes authoritative release success',
    () async {
      final client = SupabaseClient(
        'https://admin-page.invalid',
        'synthetic-public',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: sdk.sdkFixtureHttpClient(
          (_) async => http.Response(
            jsonEncode({
              'code': '42501',
              'message': 'ADMIN_USERS_SNAPSHOT_BINDING_MISMATCH',
              'details': null,
              'hint': null,
            }),
            403,
            headers: {'content-type': 'application/json'},
          ),
        ),
      );
      addTearDown(client.dispose);
      await client.auth.recoverSession(sdk.savedSession());
      await expectLater(
        AdminUserService(
          supabase: client,
        ).releaseUsersSnapshot(fixtureSnapshot),
        throwsA(
          isA<PostgrestException>().having(
            (e) => e.message,
            'message',
            'ADMIN_USERS_SNAPSHOT_BINDING_MISMATCH',
          ),
        ),
      );
    },
  );
  test(
    'malformed release flags do not permit minting a new snapshot',
    () async {
      final client = SupabaseClient(
        'https://admin-page.invalid',
        'synthetic-public',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: sdk.sdkFixtureHttpClient(
          (_) async => http.Response(
            jsonEncode({
              ...fixtureReleaseJson(fixtureSnapshot),
              'already_absent': true,
            }),
            200,
            headers: {'content-type': 'application/json'},
          ),
        ),
      );
      addTearDown(client.dispose);
      await client.auth.recoverSession(sdk.savedSession());
      await expectLater(
        AdminUserService(
          supabase: client,
        ).releaseUsersSnapshot(fixtureSnapshot),
        throwsFormatException,
      );
    },
  );
  test(
    'late release response after SDK session replacement fails its captured owner guard',
    () async {
      final response = Completer<http.Response>();
      final started = Completer<void>();
      final client = SupabaseClient(
        'https://admin-page.invalid',
        'synthetic-public',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: sdk.sdkFixtureHttpClient((_) {
          started.complete();
          return response.future;
        }),
      );
      addTearDown(client.dispose);
      await client.auth.recoverSession(sdk.savedSession());
      final pending = AdminUserService(
        supabase: client,
      ).releaseUsersSnapshot(fixtureSnapshot);
      await started.future;
      await client.auth.recoverSession(
        sdk.savedSession(session: fixtureNextSession),
      );
      response.complete(
        http.Response(
          jsonEncode(fixtureReleaseJson(fixtureSnapshot)),
          200,
          headers: {'content-type': 'application/json'},
        ),
      );
      await expectLater(pending, throwsA(isA<StaleAccountWork>()));
    },
  );
}
