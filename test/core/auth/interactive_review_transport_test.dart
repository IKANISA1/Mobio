import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobi_app/core/auth/account_context.dart';
import 'package:mobi_app/core/auth/auth_session_storage.dart';
import 'package:mobi_app/core/auth/review_session_context.dart';
import 'package:mobi_app/core/constants/app_enums.dart';
import 'package:mobi_app/features/auth/data/whatsapp_login_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const origin = 'https://review-transport.invalid';
const owner = '11111111-1111-4111-8111-111111111111';
const sid = '22222222-2222-4222-8222-222222222222';
const nextSid = '33333333-3333-4333-8333-333333333333';
const challenge = '44444444-4444-4444-8444-444444444444';

/// SDK/queue fixtures, deliberately not valid signed JWTs. Actual Auth/JWT
/// authorization is independently exercised by the local backend fixture.
Map<String, dynamic> session(String provider, {String id = sid}) {
  String encoded(Object value) =>
      base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  return {
    'access_token':
        '${encoded({'alg': 'none'})}.${encoded({'iss': '$origin/auth/v1', 'sub': owner, 'session_id': id, 'role': 'authenticated', 'iat': 1790841600, 'exp': 4102444800})}.synthetic',
    'refresh_token': 'fixture-refresh-$id',
    'token_type': 'bearer',
    'expires_in': 3600,
    'expires_at': 4102444800,
    'user': {
      'id': owner,
      'aud': 'authenticated',
      'is_anonymous': false,
      'created_at': '2026-10-01T00:00:00Z',
      'app_metadata': {'provider': provider, 'role': 'driver'},
      'user_metadata': <String, Object>{},
    },
  };
}

Map<String, Object> reviewStatus({
  String sessionId = sid,
  int generation = 3,
}) => {
  'active': true,
  'mode': 'synthetic_review',
  'user_id': owner,
  'session_id': sessionId,
  'role': 'driver',
  'generation': generation,
  'fixture_version': ReviewSessionLease.supportedFixtureVersion,
  'authenticated_at': '2026-10-01T10:00:00Z',
  'server_now': '2026-10-01T10:01:00Z',
  'expires_at': '2026-10-01T10:30:00Z',
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AuthSessionStorage storage;
  Map<String, dynamic> next = session('whatsapp_cloud_otp');
  Object proof = {'user_id': owner, 'session_id': sid};
  var proofCalls = 0;
  Completer<http.Response>? heldProof;
  Completer<void>? proofStarted;
  var first = true;

  http.Response response(Object value, [int code = 200]) => http.Response(
    jsonEncode(value),
    code,
    headers: {'content-type': 'application/json'},
  );

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    final platform = debugDefaultTargetPlatformOverride;
    try {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      storage = AuthSessionStorage.configure(origin);
    } finally {
      debugDefaultTargetPlatformOverride = platform;
    }
    await storage.persistence.initialize();
    await Supabase.initialize(
      url: origin,
      anonKey: 'fixture-public-key',
      authOptions: FlutterAuthClientOptions(
        localStorage: storage,
        autoRefreshToken: false,
      ),
      httpClient: MockClient((request) async {
        http.Response value;
        if (request.url.path == '/auth/v1/token') {
          value = response(next);
        } else if (request.url.path ==
            '/rest/v1/rpc/rpc_verified_interactive_session') {
          proofCalls++;
          proofStarted?.complete();
          proofStarted = null;
          value = heldProof == null ? response(proof) : await heldProof!.future;
        } else if (request.url.path == '/auth/v1/logout') {
          value = response({});
        } else {
          throw StateError('UNEXPECTED_FIXTURE_REQUEST');
        }
        return http.Response.bytes(
          value.bodyBytes,
          value.statusCode,
          headers: value.headers,
          request: request,
        );
      }),
    );
  });
  setUp(() async {
    if (!first) {
      await AccountContext.beginExit();
      await AccountContext.signOutSdkLocally();
    }
    first = false;
    next = session('whatsapp_cloud_otp');
    proof = {'user_id': owner, 'session_id': sid};
    proofCalls = 0;
    heldProof = null;
    proofStarted = null;
  });
  tearDownAll(() async {
    await AccountContext.beginExit();
    await Supabase.instance.dispose();
  });

  Future<LoginAttempt> restored(String provider, {String id = sid}) async {
    next = session(provider, id: id);
    final ticket = AccountContext.beginLoginAttempt(provider: provider);
    await AccountContext.prepareLogin(ticket);
    await AccountContext.restoreServerSession(ticket, next);
    return ticket;
  }

  test(
    'saved provider/JWT shape stays quarantined until exact server proof',
    () async {
      await Supabase.instance.client.auth.recoverSession(jsonEncode(next));
      await storage.persistence.acceptVerified(
        jsonEncode(next),
        expectedGeneration: storage.persistence.generation,
      );
      expect(AccountContext.hasVerifiedSession, false);
      expect(await AccountContext.validateInteractiveSession(), true);
      expect(AccountContext.hasVerifiedSession, true);
      expect(AccountContext.capture().sessionId, sid);
      expect(proofCalls, 1);
    },
  );
  test(
    'consumer commit checks real RPC before saving and enabling work',
    () async {
      final ticket = await restored('whatsapp_cloud_otp');
      expect(AccountContext.hasVerifiedSession, false);
      await AccountContext.completeVerifiedLogin(ticket);
      expect(AccountContext.hasVerifiedSession, true);
      expect(storage.persistence.accepts(owner, sid), true);
      expect(proofCalls, 1);
    },
  );
  for (final bad in [
    <String, Object>{},
    {'user_id': owner, 'session_id': nextSid},
  ]) {
    test('mismatched proof prevents consumer persistence ($bad)', () async {
      proof = bad;
      final ticket = await restored('whatsapp_cloud_otp');
      await expectLater(
        AccountContext.completeVerifiedLogin(ticket),
        throwsA(anything),
      );
      expect(AccountContext.hasVerifiedSession, false);
      expect(storage.persistence.accepts(owner, sid), false);
      await AccountContext.abortLogin(ticket);
    });
  }
  test(
    'failed revalidation removes previously accepted production authority',
    () async {
      await AccountContext.completeVerifiedLogin(
        await restored('whatsapp_cloud_otp'),
      );
      heldProof = Completer<http.Response>();
      proofStarted = Completer<void>();
      final started = proofStarted!.future;
      final check = AccountContext.validateInteractiveSession();
      await started;
      expect(AccountContext.hasVerifiedSession, false);
      heldProof!.complete(
        response({'code': '42501', 'message': 'UNVERIFIED_SESSION'}, 403),
      );
      expect(await check, false);
      expect(AccountContext.hasVerifiedSession, false);
    },
  );
  test('late proof after logout cannot resurrect authority', () async {
    final ticket = await restored('whatsapp_cloud_otp');
    heldProof = Completer<http.Response>();
    proofStarted = Completer<void>();
    final started = proofStarted!.future;
    final commit = AccountContext.completeVerifiedLogin(ticket);
    final assertion = expectLater(commit, throwsA(anything));
    await started;
    await AccountContext.beginExit();
    heldProof!.complete(response(proof));
    await assertion;
    expect(AccountContext.hasVerifiedSession, false);
    expect(storage.persistence.acceptedIdentity, null);
  });
  test(
    'late proof for old SID cannot clear or authorize a replacement login',
    () async {
      final oldTicket = await restored('whatsapp_cloud_otp');
      final oldReply = Completer<http.Response>();
      heldProof = oldReply;
      proofStarted = Completer<void>();
      final started = proofStarted!.future;
      final oldCommit = AccountContext.completeVerifiedLogin(oldTicket);
      final assertion = expectLater(oldCommit, throwsA(anything));
      await started;
      await AccountContext.beginExit();
      await AccountContext.signOutSdkLocally();
      heldProof = null;
      proof = {'user_id': owner, 'session_id': nextSid};
      final replacement = await restored('whatsapp_cloud_otp', id: nextSid);
      await AccountContext.completeVerifiedLogin(replacement);
      oldReply.complete(response({'user_id': owner, 'session_id': sid}));
      await assertion;
      expect(AccountContext.hasVerifiedSession, true);
      expect(AccountContext.capture().sessionId, nextSid);
      expect(storage.persistence.accepts(owner, nextSid), true);
    },
  );
  test(
    'review can persist transport but never captures production authority',
    () async {
      final ticket = await restored('store_review');
      await AccountContext.completeReviewLogin(
        ticket,
        status: reviewStatus(),
        elapsedTime: () => Duration.zero,
      );
      expect(AccountContext.hasReviewTransport, true);
      expect(AccountContext.reviewSession.hasAccess, true);
      expect(AccountContext.hasVerifiedSession, false);
      expect(AccountContext.capture, throwsA(anything));
      expect(proofCalls, 0);
      final action = AccountContext.reviewSession.capture();
      await AccountContext.beginExit();
      expect(action.isCurrent, false);
      expect(AccountContext.hasReviewTransport, false);
    },
  );
  test(
    'review cannot use the production commit even if RPC would accept',
    () async {
      final ticket = await restored('store_review');
      await expectLater(
        AccountContext.completeVerifiedLogin(ticket),
        throwsA(anything),
      );
      expect(proofCalls, 0);
      expect(storage.persistence.acceptedIdentity, null);
      expect(AccountContext.reviewSession.hasAccess, false);
      await AccountContext.abortLogin(ticket);
    },
  );
  test('invalid review status cannot persist restored transport', () async {
    final ticket = await restored('store_review');
    await expectLater(
      AccountContext.completeReviewLogin(
        ticket,
        status: reviewStatus(sessionId: nextSid),
        elapsedTime: () => Duration.zero,
      ),
      throwsA(anything),
    );
    expect(storage.persistence.acceptedIdentity, null);
    expect(AccountContext.reviewSession.hasAccess, false);
    await AccountContext.abortLogin(ticket);
  });

  for (final scenario in [
    'active',
    'inactive',
    'different-generation',
    'different-SID',
  ]) {
    test(
      'actual login service restores review Auth then checks status: $scenario',
      () async {
        next = session('store_review');
        final calls = <String>[];
        final dio = Dio();
        addTearDown(dio.close);
        dio.interceptors.add(
          InterceptorsWrapper(
            onRequest: (request, handler) {
              calls.add(request.path);
              final Object data;
              if (request.path == '/send-login-otp') {
                data = {
                  'success': true,
                  'deliveryMode': 'review_code',
                  'challengeId': challenge,
                };
              } else if (request.path == '/verify-login-otp') {
                expect((request.data as Map)['challengeId'], challenge);
                data = {
                  'success': true,
                  'mode': 'synthetic_review',
                  'role': 'driver',
                  'session': next,
                  'reviewSession': reviewStatus(),
                };
              } else if (request.path == '/store-review-session') {
                expect(
                  request.headers['Authorization'],
                  'Bearer ${next['access_token']}',
                );
                expect(request.data, {'action': 'status'});
                data = {
                  'success': true,
                  'reviewSession': switch (scenario) {
                    'inactive' => {'active': false},
                    'different-generation' => reviewStatus(generation: 4),
                    'different-SID' => reviewStatus(sessionId: nextSid),
                    _ => reviewStatus(),
                  },
                };
              } else {
                throw StateError('UNEXPECTED_EDGE_FIXTURE_REQUEST');
              }
              handler.resolve(
                Response(requestOptions: request, statusCode: 200, data: data),
              );
            },
          ),
        );
        final service = WhatsAppLoginService(dio: dio);
        expect(
          (await service.sendLoginOtp(
            phone: '0789 000 123',
            countryCode: '+250',
            role: AppRole.passenger,
          )).usesReviewCode,
          true,
        );
        final result = await service.verifyLoginOtp(
          phone: '0789 000 123',
          code: '654321',
          countryCode: '+250',
          role: AppRole.passenger,
        );
        expect(result.success, scenario == 'active');
        expect(AccountContext.reviewSession.hasAccess, scenario == 'active');
        expect(AccountContext.hasVerifiedSession, false);
        expect(proofCalls, 0);
        expect(calls, [
          '/send-login-otp',
          '/verify-login-otp',
          '/store-review-session',
        ]);
        if (scenario == 'active') expect(result.role, AppRole.passenger);
      },
    );
  }
}
