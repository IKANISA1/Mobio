import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mobi_app/app/incoming_app_links.dart';
import 'package:mobi_app/core/async/account_epoch.dart';
import 'package:mobi_app/core/auth/account_context.dart';
import 'package:mobi_app/features/profile/data/referral_attribution_service.dart';
import 'package:mobi_app/features/profile/data/referral_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../helpers/admin_auth_sdk_fixture.dart' as fixture;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'late authority admission completes restored pending once and disposes listener',
    () async {
      SharedPreferences.setMockInitialValues({
        'mobio.pending_referral.v2': jsonEncode({
          'id': 'restored',
          'code': 'MOBI482913',
          'source': 'app_link_stream',
        }),
      });
      final prefs = await SharedPreferences.getInstance();
      final changes = _AuthoritySignal();
      var verified = false;
      const account = AccountSnapshot(fixture.owner, fixture.sid, 1);
      var writes = 0;
      final started = Completer<void>();
      final held = Completer<http.Response>();
      final client = SupabaseClient(
        'https://referral-contract.invalid',
        'fixture-public-key',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: fixture.sdkFixtureHttpClient((request) async {
          writes++;
          if (!started.isCompleted) started.complete();
          return held.future;
        }),
      );
      await client.auth.recoverSession(fixture.savedSession());
      final service = ReferralAttributionService(
        referralService: ReferralService(
          supabase: client,
          captureAccount: () => account,
          requireCurrent: (_) {},
        ),
        preferences: () async => prefs,
        enabled: () => true,
        verified: () => verified,
        captureAccount: () => account,
        requireCurrent: (_) {},
        accountChanges: changes,
      );
      expect(changes.observing, true);
      changes.value++;
      await Future<void>.delayed(Duration.zero);
      expect(writes, 0);
      verified = true;
      changes.value++;
      changes.value++;
      await started.future;
      expect(writes, 1);
      held.complete(
        http.Response('{}', 200, headers: {'content-type': 'application/json'}),
      );
      await Future<void>.delayed(Duration.zero);
      expect(prefs.getString('mobio.pending_referral.v2'), isNull);
      await service.dispose();
      expect(changes.observing, false);
      changes.value++;
      expect(writes, 1);
      changes.dispose();
      await client.dispose();
    },
  );
  test(
    'verified arrival remains bound to A while preferences wait across B login',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final storage = Completer<SharedPreferences>();
      AccountSnapshot current = const AccountSnapshot(
        fixture.owner,
        fixture.sid,
        1,
      );
      void require(AccountSnapshot captured) {
        if (captured.identity != current.identity ||
            captured.generation != current.generation) {
          throw const StaleAccountWork();
        }
      }

      var writes = 0;
      final client = SupabaseClient(
        'https://referral-contract.invalid',
        'fixture-public-key',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: fixture.sdkFixtureHttpClient((request) async {
          if (request.url.path.endsWith('rpc_complete_referral_signup'))
            writes++;
          return http.Response(
            '{}',
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      await client.auth.recoverSession(fixture.savedSession());
      final service = ReferralAttributionService(
        referralService: ReferralService(
          supabase: client,
          captureAccount: () => current,
          requireCurrent: require,
        ),
        preferences: () => storage.future,
        enabled: () => true,
        verified: () => true,
        captureAccount: () => current,
        requireCurrent: require,
      );
      final arrival = service.captureInvite(
        const IncomingInvite('MOBI482913', universalLink: true),
      );
      current = const AccountSnapshot(fixture.other, fixture.nextSid, 2);
      storage.complete(prefs);
      await arrival;
      await service.completePendingSignup();
      final pending =
          jsonDecode(prefs.getString('mobio.pending_referral.v2')!) as Map;
      expect(pending['claimed_by'], fixture.owner);
      expect(
        writes,
        0,
        reason: 'B must not complete an arrival captured under A',
      );
      await service.dispose();
      await client.dispose();
    },
  );
  test(
    'held preferences preserve only the newest uncommitted invite',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final storage = Completer<SharedPreferences>();
      final opens = <String>[];
      final client = SupabaseClient(
        'https://referral-contract.invalid',
        'fixture-public-key',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: fixture.sdkFixtureHttpClient((request) async {
          if (request.url.path.endsWith('rpc_record_referral_open')) {
            opens.add((jsonDecode(request.body) as Map)['p_code'] as String);
          }
          return http.Response(
            '{}',
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      final service = ReferralAttributionService(
        referralService: ReferralService(supabase: client),
        preferences: () => storage.future,
        enabled: () => true,
        verified: () => false,
      );
      final oldArrival = service.captureInvite(
        const IncomingInvite('MOBI482913', universalLink: true),
      );
      final newArrival = service.captureInvite(
        const IncomingInvite('MOBI482914', universalLink: true),
      );
      expect(prefs.getString('mobio.pending_referral.v2'), isNull);
      storage.complete(prefs);
      await Future.wait([oldArrival, newArrival]);
      await Future<void>.delayed(Duration.zero);
      final pending =
          jsonDecode(prefs.getString('mobio.pending_referral.v2')!) as Map;
      expect(pending['code'], 'MOBI482914');
      expect(opens, ['MOBI482914']);
      await service.dispose();
      await client.dispose();
    },
  );
  for (final ending in [
    'new_invite',
    'new_account',
    'logout',
    'unknown',
    'new_account_unknown',
    'logout_unknown',
  ]) {
    test(
      'held real SDK signup cannot lose pending state after $ending',
      () async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        var verified = false;
        AccountSnapshot? current = const AccountSnapshot(
          fixture.owner,
          fixture.sid,
          1,
        );
        void require(AccountSnapshot captured) {
          if (current?.identity != captured.identity ||
              current?.generation != captured.generation) {
            throw const StaleAccountWork();
          }
        }

        final held = Completer<http.Response>();
        final started = Completer<void>();
        var writes = 0;
        final bodies = <Map<String, dynamic>>[];
        final client = SupabaseClient(
          'https://referral-contract.invalid',
          'fixture-public-key',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
          httpClient: fixture.sdkFixtureHttpClient((request) async {
            if (request.url.path.endsWith('rpc_complete_referral_signup')) {
              writes++;
              bodies.add(jsonDecode(request.body) as Map<String, dynamic>);
              if (!started.isCompleted) started.complete();
              return held.future;
            }
            return http.Response(
              '{}',
              200,
              headers: {'content-type': 'application/json'},
            );
          }),
        );
        await client.auth.recoverSession(fixture.savedSession());
        final service = ReferralAttributionService(
          referralService: ReferralService(
            supabase: client,
            captureAccount: () => current!,
            requireCurrent: require,
          ),
          preferences: () async => prefs,
          enabled: () => true,
          verified: () => verified && current != null,
          captureAccount: () => current!,
          requireCurrent: require,
        );
        await service.captureInvite(
          const IncomingInvite('MOBI482913', universalLink: true),
        );
        verified = true;
        final completion = service.completePendingSignup();
        final duplicate = service.completePendingSignup();
        await started.future;
        expect(writes, 1);
        final inFlight =
            jsonDecode(prefs.getString('mobio.pending_referral.v2')!) as Map;
        expect(
          inFlight['unknown_outcome'],
          true,
          reason:
              'a restart while the response is pending cannot replay the write',
        );
        verified = false;
        if (ending == 'new_invite') {
          await service.captureInvite(
            const IncomingInvite('MOBI482914', universalLink: true),
          );
        } else if (ending.startsWith('new_account')) {
          current = const AccountSnapshot(fixture.other, fixture.nextSid, 2);
        } else if (ending.startsWith('logout')) {
          current = null;
        }
        if (ending.endsWith('unknown'))
          held.completeError(http.ClientException('synthetic lost response'));
        else
          held.complete(
            http.Response(
              '{}',
              200,
              headers: {'content-type': 'application/json'},
            ),
          );
        await Future.wait([completion, duplicate]);
        final pending =
            jsonDecode(prefs.getString('mobio.pending_referral.v2')!)
                as Map<String, dynamic>;
        expect(
          pending['code'],
          ending == 'new_invite' ? 'MOBI482914' : 'MOBI482913',
        );
        if (ending != 'new_invite') expect(pending['unknown_outcome'], true);
        if (ending != 'new_invite')
          expect(pending['claimed_by'], fixture.owner);
        expect(
          (bodies.single['p_metadata'] as Map).containsKey('uri'),
          isFalse,
        );
        verified = ending != 'new_invite';
        await service.completePendingSignup();
        expect(writes, 1);
        if (ending != 'new_invite') {
          current = const AccountSnapshot(fixture.owner, fixture.nextSid, 3);
          verified = true;
          await service.completePendingSignup();
          expect(
            writes,
            1,
            reason: 're-login cannot replay an uncertain mutation',
          );
        }
        await service.dispose();
        await client.dispose();
      },
    );
  }
  test(
    'successful current completion clears one atomic pending record and migrates legacy',
    () async {
      SharedPreferences.setMockInitialValues({
        'mobio.pending_referral_code': 'MOBI482913',
        'mobio.pending_referral_install_id': 'iosul_fixture',
        'mobio.pending_referral_attribution_source': 'initial_app_link',
      });
      final prefs = await SharedPreferences.getInstance();
      const account = AccountSnapshot(fixture.owner, fixture.sid, 1);
      var writes = 0;
      final client = SupabaseClient(
        'https://referral-contract.invalid',
        'fixture-public-key',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: fixture.sdkFixtureHttpClient((request) async {
          writes++;
          return http.Response(
            '{}',
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      await client.auth.recoverSession(fixture.savedSession());
      final service = ReferralAttributionService(
        referralService: ReferralService(
          supabase: client,
          captureAccount: () => account,
          requireCurrent: (_) {},
        ),
        preferences: () async => prefs,
        enabled: () => true,
        verified: () => true,
        captureAccount: () => account,
        requireCurrent: (_) {},
      );
      await service.completePendingSignup();
      expect(writes, 1);
      expect(prefs.getString('mobio.pending_referral.v2'), isNull);
      expect(prefs.getString('mobio.pending_referral_code'), isNull);
      await service.dispose();
      await client.dispose();
    },
  );
  test('iOS custom sources cannot create universal-link install proof', () {
    expect(
      ReferralAttributionService.shouldCreateIosUniversalLinkInstallId(
        platform: TargetPlatform.iOS,
        source: 'app_link_stream',
        kIsWeb: false,
        universalLink: false,
      ),
      isFalse,
    );
  });
  test(
    'real SDK explicit SQL rejection retains ordinary retry state',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      const account = AccountSnapshot(fixture.owner, fixture.sid, 1);
      var verified = false;
      var writes = 0;
      final client = SupabaseClient(
        'https://referral-contract.invalid',
        'fixture-public-key',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: fixture.sdkFixtureHttpClient((request) async {
          if (request.url.path.endsWith('rpc_complete_referral_signup')) {
            writes++;
            if (writes == 1) {
              return http.Response(
                jsonEncode({
                  'code': '22023',
                  'message': 'SYNTHETIC_REJECTION',
                  'details': null,
                  'hint': null,
                }),
                400,
                headers: {'content-type': 'application/json'},
              );
            }
          }
          return http.Response(
            '{}',
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      await client.auth.recoverSession(fixture.savedSession());
      final service = ReferralAttributionService(
        referralService: ReferralService(
          supabase: client,
          captureAccount: () => account,
          requireCurrent: (_) {},
        ),
        preferences: () async => prefs,
        enabled: () => true,
        verified: () => verified,
        captureAccount: () => account,
        requireCurrent: (_) {},
      );
      await service.captureInvite(
        const IncomingInvite('MOBI482913', universalLink: true),
      );
      verified = true;
      await service.completePendingSignup();
      expect(writes, 1);
      final pending =
          jsonDecode(prefs.getString('mobio.pending_referral.v2')!) as Map;
      expect(pending['unknown_outcome'], false);
      expect(pending['code'], 'MOBI482913');
      await service.completePendingSignup();
      expect(writes, 2);
      expect(prefs.getString('mobio.pending_referral.v2'), isNull);
      await service.dispose();
      await client.dispose();
    },
  );
}

class _AuthoritySignal extends ValueNotifier<int> {
  _AuthoritySignal() : super(0);
  bool get observing => hasListeners;
}
