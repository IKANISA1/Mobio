import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobi_app/core/errors/app_exception.dart';
import 'package:mobi_app/features/ev_chargers/data/ev_charger_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  SupabaseClient client(Object? rows) {
    final value = SupabaseClient(
      'https://charger-contract.invalid',
      'mock-public-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient(
        (request) async => http.Response(
          jsonEncode(rows),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        ),
      ),
    );
    addTearDown(value.dispose);
    return value;
  }

  Map<String, Object?> row() => {
    'id': '11111111-1111-4111-8111-111111111111',
    'name': 'Kigali charger',
    'address': 'Kigali',
    'latitude': -1.95,
    'longitude': 30.06,
    'connector_types': ['CCS'],
    'is_active': true,
    'distance_km': 1.2,
  };

  test('valid nearest response preserves position and distance', () async {
    final service = EvChargerService(supabase: client([row()]));
    final chargers = await service.findNearestChargers(
      latitude: -1.9,
      longitude: 30,
    );
    expect(chargers.single.latitude, -1.95);
    expect(chargers.single.distanceKm, 1.2);
  });

  for (final bad in [
    null,
    [7],
    [row()..remove('latitude')],
    [row()..['distance_km'] = -1],
  ]) {
    test(
      'malformed charger response fails instead of inventing data: $bad',
      () async {
        final service = EvChargerService(supabase: client(bad));
        await expectLater(service.listChargers(), throwsA(isA<AppException>()));
      },
    );
  }

  test('lost activation response remains an unknown write outcome', () async {
    final value = SupabaseClient(
      'https://charger-contract.invalid',
      'mock-public-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((_) async => throw const SocketException('lost')),
    );
    addTearDown(value.dispose);
    await expectLater(
      EvChargerService(supabase: value).setChargerActive('charger-1', false),
      throwsA(isA<MutationOutcomeUnknownException>()),
    );
  });
  test('malformed upsert receipt cannot report a saved charger', () async {
    await expectLater(
      EvChargerService(supabase: client(null)).upsertCharger(
        name: 'Kigali charger',
        address: 'Kigali',
        latitude: -1.95,
        longitude: 30.06,
        connectorTypes: ['CCS'],
      ),
      throwsA(isA<MutationOutcomeUnknownException>()),
    );
  });
  test('upsert reply must match the charger being edited', () async {
    await expectLater(
      EvChargerService(
        supabase: client('22222222-2222-4222-8222-222222222222'),
      ).upsertCharger(
        id: '11111111-1111-4111-8111-111111111111',
        name: 'Kigali charger',
        address: 'Kigali',
        latitude: -1.95,
        longitude: 30.06,
        connectorTypes: ['CCS'],
      ),
      throwsA(isA<MutationOutcomeUnknownException>()),
    );
  });
}
