import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobi_app/core/async/account_epoch.dart';
import 'package:mobi_app/core/auth/account_context.dart';
import 'package:mobi_app/core/errors/app_exception.dart';
import 'package:mobi_app/features/profile/data/favorite_address_service.dart';
import 'package:mobi_app/features/profile/data/referral_service.dart';
import 'package:mobi_shared_types/models/place.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const owner = '11111111-1111-4111-8111-111111111111';

Future<void> signIn(SupabaseClient client) async {
  String part(Object data) =>
      base64Url.encode(utf8.encode(jsonEncode(data))).replaceAll('=', '');
  final expiry = DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600;
  await client.auth.recoverSession(
    jsonEncode({
      'access_token':
          '${part({'alg': 'none'})}.${part({'sub': owner, 'exp': expiry})}.fixture',
      'refresh_token': 'fixture-refresh',
      'token_type': 'bearer',
      'expires_at': expiry,
      'expires_in': 3600,
      'user': {
        'id': owner,
        'aud': 'authenticated',
        'created_at': '2026-01-01T00:00:00Z',
        'app_metadata': {},
        'user_metadata': {},
      },
    }),
  );
}

void main() {
  test(
    'lost address creation retains the exact client-created row ID',
    () async {
      Map<String, dynamic>? payload;
      var sends = 0;
      final client = SupabaseClient(
        'https://account-race.invalid',
        'mock-public-key',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((request) async {
          sends++;
          payload = jsonDecode(request.body) as Map<String, dynamic>;
          throw const SocketException('lost');
        }),
      );
      addTearDown(client.dispose);
      await signIn(client);
      final service = FavoriteAddressService(
        supabase: client,
        captureAccount: () => const AccountSnapshot(owner, 'session-a', 0),
        requireCurrent: (_) {},
      );
      await expectLater(
        service.save(
          label: 'Home',
          addressType: 'home',
          place: const PlaceDetails(
            placeId: 'place-1',
            formattedAddress: 'Kigali',
            latitude: -1.9,
            longitude: 30,
          ),
        ),
        throwsA(
          isA<MutationOutcomeUnknownException>().having(
            (e) => e.operationId,
            'row ID',
            predicate(
              (id) => id == payload?['id'] && id is String && id.length == 36,
            ),
          ),
        ),
      );
      expect(sends, 1);
    },
  );

  for (final operation in ['favorite list', 'referral creation']) {
    test('$operation rejects a late result from an old generation', () async {
      final entered = Completer<void>();
      final release = Completer<void>();
      final client = SupabaseClient(
        'https://account-race.invalid',
        'mock-public-key',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((request) async {
          entered.complete();
          await release.future;
          return http.Response(
            operation == 'favorite list' ? '[]' : '{}',
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }),
      );
      addTearDown(client.dispose);
      await signIn(client);
      var generation = 0;
      AccountSnapshot capture() =>
          AccountSnapshot(owner, 'session-a', generation);
      void require(AccountSnapshot account) {
        if (account.generation != generation) throw const StaleAccountWork();
      }

      final Future<Object?> pending = operation == 'favorite list'
          ? FavoriteAddressService(
              supabase: client,
              captureAccount: capture,
              requireCurrent: require,
            ).list()
          : ReferralService(
              supabase: client,
              captureAccount: capture,
              requireCurrent: require,
            ).getOrCreateCode();
      await entered.future;
      generation++;
      release.complete();
      await expectLater(pending, throwsA(isA<StaleAccountWork>()));
    });
  }
}
