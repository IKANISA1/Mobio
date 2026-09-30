import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobi_app/core/errors/app_exception.dart';
import 'package:mobi_app/features/profile/data/driver_plus_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  for (final response in [
    null,
    {
      'id': '11111111-1111-4111-8111-111111111111',
      'status': 'pending',
      'payment_method': 'momo_ussd',
      'reference_code': 'SUB-123',
      'amount_tokens': 3000,
      'amount_rwf': 3000,
      'currency': 'RWF',
      'momo_pay_code': '123456',
      'ussd_code': '*182*8*1*123456#',
      'expires_at': '2026-09-30T12:30:00Z',
    },
  ]) {
    test(
      'malformed or mismatched subscription reply retains request identity: $response',
      () async {
        final client = SupabaseClient(
          'https://driver-plus-contract.invalid',
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
        await expectLater(
          DriverPlusService(supabase: client).startSubscription(
            planId: 'plan-1',
            paymentMethod: 'tokens',
            clientRequestId: 'request-1',
          ),
          throwsA(
            isA<MutationOutcomeUnknownException>().having(
              (e) => e.operationId,
              'request ID',
              'request-1',
            ),
          ),
        );
      },
    );
  }
}
