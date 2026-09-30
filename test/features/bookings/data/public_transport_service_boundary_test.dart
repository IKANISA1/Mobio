import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobi_app/core/errors/app_exception.dart';
import 'package:mobi_app/features/bookings/data/public_transport_service.dart';
import 'package:mobi_shared_types/models/public_transport.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  PublicTransportService service(Object? response) {
    final client = SupabaseClient(
      'https://transport-contract.invalid',
      'mock-public-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient(
        (request) async => http.Response(
          jsonEncode(response),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        ),
      ),
    );
    addTearDown(client.dispose);
    return PublicTransportService(supabase: client);
  }

  test(
    'missing hold reply cannot establish an unpaid or free booking',
    () async {
      await expectLater(
        service([]).holdSeats(
          const BusSeatHoldRequest(scheduleId: 'schedule-1', seatCount: 1),
        ),
        throwsA(isA<MutationOutcomeUnknownException>()),
      );
    },
  );

  test('malformed successful confirmation stays unconfirmed', () async {
    await expectLater(
      service([
        {'booking_id': 'booking-1'},
      ]).confirmBooking(
        bookingId: 'booking-1',
        paymentProvider: 'provider',
        providerReference: 'reference-1',
      ),
      throwsA(
        isA<MutationOutcomeUnknownException>().having(
          (e) => e.operationId,
          'operation id',
          'booking-1',
        ),
      ),
    );
  });

  test(
    'malformed agency response cannot be replaced by preview data',
    () async {
      await expectLater(
        service([
          {'name': 'Agency'},
        ]).getAgencies(),
        throwsFormatException,
      );
    },
  );
}
