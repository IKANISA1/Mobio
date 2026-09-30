import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobi_app/core/async/account_epoch.dart';
import 'package:mobi_app/core/errors/app_exception.dart';
import 'package:mobi_app/features/bookings/data/trip_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _tripId = '11111111-1111-4111-8111-111111111111';

void main() {
  test('late trip detail from a previous generation is discarded', () async {
    final entered = Completer<void>();
    final release = Completer<void>();
    final client = SupabaseClient(
      'https://trip-race.invalid',
      'mock-public-key',
      httpClient: MockClient((request) async {
        entered.complete();
        await release.future;
        return http.Response(
          '{}',
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }),
    );
    addTearDown(client.dispose);
    var generation = 0;
    final service = TripService(
      supabase: client,
      captureAuthority: () {
        final captured = generation;
        return TripAuthority(
          userId: 'account-a',
          requireCurrent: () {
            if (generation != captured) throw const StaleAccountWork();
          },
        );
      },
    );

    final pending = service.getTripById(_tripId);
    await entered.future;
    generation++;
    release.complete();
    await expectLater(pending, throwsA(isA<StaleAccountWork>()));
  });

  test(
    'old account uncertain create does not cool down a new account',
    () async {
      var account = 'account-a';
      final client = SupabaseClient(
        'https://trip-race.invalid',
        'mock-public-key',
        httpClient: MockClient((_) async {
          throw const SocketException('lost reply');
        }),
      );
      addTearDown(client.dispose);
      final service = TripService(
        supabase: client,
        captureAuthority: () {
          final captured = account;
          return TripAuthority(
            userId: captured,
            requireCurrent: () {
              if (account != captured) throw const StaleAccountWork();
            },
          );
        },
      );

      Future<void> create() async {
        await service.createTrip(
          origin: 'Kigali',
          destination: 'Musanze',
          departureDate: '2026-10-01',
          departureTime: '09:00',
          role: 'driver',
          clientRequestId: _tripId,
        );
      }

      await expectLater(
        create(),
        throwsA(isA<MutationOutcomeUnknownException>()),
      );
      account = 'account-b';
      await expectLater(
        create(),
        throwsA(isA<MutationOutcomeUnknownException>()),
      );
    },
  );

  test(
    'late cancellation acknowledgement cannot update a new account',
    () async {
      final entered = Completer<void>();
      final release = Completer<void>();
      final client = SupabaseClient(
        'https://trip-race.invalid',
        'mock-public-key',
        httpClient: MockClient((request) async {
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
      var generation = 0;
      final service = TripService(
        supabase: client,
        captureAuthority: () {
          final captured = generation;
          return TripAuthority(
            userId: 'account-a',
            requireCurrent: () {
              if (generation != captured) throw const StaleAccountWork();
            },
          );
        },
      );

      final pending = service.cancelTrip(_tripId);
      await entered.future;
      generation++;
      release.complete();
      await expectLater(pending, throwsA(isA<StaleAccountWork>()));
    },
  );
}
