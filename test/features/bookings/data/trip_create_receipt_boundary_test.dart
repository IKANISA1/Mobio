import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobi_app/core/errors/app_exception.dart';
import 'package:mobi_app/features/bookings/data/trip_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test(
    'update acknowledgement must preserve the requested trip identity',
    () async {
      const tripId = '00000000-0000-4000-8000-000000000010';
      const ownerId = '00000000-0000-4000-8000-000000000001';
      for (final response in [
        'bad-id',
        '00000000-0000-4000-8000-000000000011',
        null,
      ]) {
        var calls = 0;
        final client = SupabaseClient(
          'https://trip-contract.invalid',
          'mock-public-key',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
          httpClient: MockClient((request) async {
            calls++;
            return http.Response(
              jsonEncode(response),
              200,
              headers: {'content-type': 'application/json'},
              request: request,
            );
          }),
        );
        addTearDown(client.dispose);
        final service = TripService(
          supabase: client,
          captureAuthority: () =>
              TripAuthority(userId: ownerId, requireCurrent: () {}),
        );
        await expectLater(
          service.updateTrip(
            tripId: tripId,
            origin: 'Kigali',
            destination: 'Musanze',
            departureDate: '2026-10-01',
            departureTime: '09:00',
            role: 'driver',
          ),
          throwsA(
            isA<MutationOutcomeUnknownException>().having(
              (error) => error.operationId,
              'request identity',
              tripId,
            ),
          ),
        );
        expect(calls, 1);
      }
    },
  );

  test(
    'trip detail and own-list reads reject a mismatched returned identity',
    () async {
      const tripId = '00000000-0000-4000-8000-000000000010';
      const ownerId = '00000000-0000-4000-8000-000000000001';
      const other = '00000000-0000-4000-8000-000000000002';
      final row = <String, dynamic>{
        'id': other,
        'author_id': other,
        'origin': 'Kigali',
        'destination': 'Musanze',
        'departure_date': '2026-10-01',
        'departure_time': '09:00',
        'role': 'driver',
        'vehicle_type': 'cab',
        'status': 'active',
        'is_active': true,
        'is_recurring': false,
        'recurring_days': <int>[],
        'recurrence_skip_dates': <String>[],
      };
      final client = SupabaseClient(
        'https://trip-contract.invalid',
        'mock-public-key',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient(
          (request) async => http.Response(
            jsonEncode([row]),
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          ),
        ),
      );
      addTearDown(client.dispose);
      final service = TripService(
        supabase: client,
        captureAuthority: () =>
            TripAuthority(userId: ownerId, requireCurrent: () {}),
      );
      await expectLater(
        service.getTripById(tripId),
        throwsA(isA<AppException>()),
      );
      await expectLater(service.getMyTrips(), throwsA(isA<AppException>()));
    },
  );
  test(
    'malformed acknowledged create receipt preserves uncertain outcome and cooldown',
    () async {
      var calls = 0;
      final client = SupabaseClient(
        'https://trip-contract.invalid',
        'mock-public-key',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((request) async {
          calls++;
          return http.Response(
            jsonEncode('not-a-trip-id'),
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }),
      );
      addTearDown(client.dispose);
      final service = TripService(
        supabase: client,
        captureAuthority: () =>
            TripAuthority(userId: 'receipt-account', requireCurrent: () {}),
      );
      Future<void> create() async => service.createTrip(
        origin: 'Kigali',
        destination: 'Musanze',
        departureDate: '2026-10-01',
        departureTime: '09:00',
        role: 'driver',
        clientRequestId: 'stable-create-request',
      );
      await expectLater(
        create(),
        throwsA(
          isA<MutationOutcomeUnknownException>().having(
            (error) => error.operationId,
            'original request identity',
            'stable-create-request',
          ),
        ),
      );
      await expectLater(create(), throwsA(isA<ValidationException>()));
      expect(calls, 1);
    },
  );
}
