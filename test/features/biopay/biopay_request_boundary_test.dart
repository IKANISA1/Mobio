import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobi_app/core/errors/app_exception.dart';
import 'package:mobi_app/features/biopay/data/biopay_admin_service.dart';
import 'package:mobi_app/features/biopay/data/biopay_ussd_service.dart';
import 'package:mobi_app/features/biopay/domain/biopay_ussd_payment.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

SupabaseClient fixture(http.Client httpClient) {
  final client = SupabaseClient(
    'https://biopay-contract.invalid',
    'mock-public-key',
    authOptions: const AuthClientOptions(autoRefreshToken: false),
    httpClient: httpClient,
  );
  addTearDown(client.dispose);
  return client;
}

void main() {
  test('lost create response is an unknown BioPay request outcome', () async {
    final service = BioPayUssdService(
      supabase: fixture(
        MockClient((_) async => throw const SocketException('lost')),
      ),
    );
    await expectLater(
      service.createPaymentRequest(
        channel: BioPayRequestChannel.qr,
        amountMinor: 150000,
        payeeLabel: 'Merchant',
      ),
      throwsA(isA<MutationOutcomeUnknownException>()),
    );
  });

  test('malformed BioPay activity cannot appear empty', () async {
    final client = fixture(
      MockClient(
        (request) async => http.Response(
          jsonEncode([7]),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        ),
      ),
    );
    await expectLater(
      BioPayUssdService(supabase: client).listPaymentRequests(),
      throwsFormatException,
    );
    await expectLater(
      BioPayAdminService(supabase: client).listRequests(),
      throwsFormatException,
    );
  });
}
