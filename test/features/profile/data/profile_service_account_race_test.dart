import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobi_app/core/async/account_epoch.dart';
import 'package:mobi_app/core/auth/account_context.dart';
import 'package:mobi_app/features/profile/data/profile_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _userId = '11111111-1111-4111-8111-111111111111';

String _jwtPart(Object value) =>
    base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');

Future<void> _signIn(SupabaseClient client) async {
  final expiry = DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600;
  await client.auth.recoverSession(
    jsonEncode({
      'access_token':
          '${_jwtPart({'alg': 'none', 'typ': 'JWT'})}.'
          '${_jwtPart({'sub': _userId, 'exp': expiry, 'role': 'authenticated'})}.'
          'mock-fixture-signature',
      'refresh_token': 'mock-refresh-fixture',
      'token_type': 'bearer',
      'expires_in': 3600,
      'expires_at': expiry,
      'user': {
        'id': _userId,
        'aud': 'authenticated',
        'created_at': '2026-01-01T00:00:00Z',
        'app_metadata': <String, Object?>{},
        'user_metadata': <String, Object?>{},
      },
    }),
  );
}

void main() {
  test(
    'profile save from an old generation cannot start driver-mode write',
    () async {
      final entered = Completer<void>();
      final release = Completer<void>();
      final requests = <String>[];
      final client = SupabaseClient(
        'https://profile-race.invalid',
        'mock-public-key',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((request) async {
          requests.add(request.url.path);
          entered.complete();
          await release.future;
          return http.Response(
            'null',
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }),
      );
      addTearDown(client.dispose);
      await _signIn(client);
      var generation = 0;
      final service = ProfileService(
        supabase: client,
        captureAccount: () => AccountSnapshot(_userId, 'session-a', generation),
        requireCurrent: (snapshot) {
          if (generation != snapshot.generation) throw const StaleAccountWork();
        },
      );

      final pending = service.saveProfileSettings(
        momoNumber: '0788767816',
        momoPayCode: '123456',
        isDriver: true,
        vehicleTypeId: 'cab',
        vehicleNumberPlate: 'RAA 123 A',
        previousIsDriver: false,
      );
      await entered.future;
      generation++;
      release.complete();
      await expectLater(pending, throwsA(isA<StaleAccountWork>()));
      expect(requests, ['/rest/v1/rpc/rpc_update_profile']);
    },
  );
}
