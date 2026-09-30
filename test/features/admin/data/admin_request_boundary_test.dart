import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobi_app/core/errors/app_exception.dart';
import 'package:mobi_app/features/admin/data/admin_trip_service.dart';
import 'package:mobi_app/features/admin/data/admin_user_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

SupabaseClient clientWithResponse(Object? response) {
  final client = SupabaseClient(
    'https://admin-contract.invalid',
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
  return client;
}

void main() {
  test('malformed admin user rows cannot appear as an empty list', () async {
    final service = AdminUserService(supabase: clientWithResponse([7]));
    await expectLater(service.listUsers(), throwsFormatException);
  });

  test('null trip list cannot appear as no trips', () async {
    final service = AdminTripService(supabase: clientWithResponse(null));
    await expectLater(service.listTrips(), throwsFormatException);
  });

  test('lost response to admin cancellation has unknown outcome', () async {
    final client = SupabaseClient(
      'https://admin-contract.invalid',
      'mock-public-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((_) async => throw const SocketException('lost')),
    );
    addTearDown(client.dispose);
    final service = AdminTripService(supabase: client);
    await expectLater(
      service.cancelTrip(tripId: 'trip-1'),
      throwsA(isA<MutationOutcomeUnknownException>()),
    );
  });
}
