import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:mobi_app/core/errors/app_exception.dart';
import 'package:mobi_app/features/profile/data/subscription_plan_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  Map<String, dynamic> requestRow() => {
    'id': '00000000-0000-4000-8000-000000000001',
    'profile_id': '00000000-0000-4000-8000-000000000002',
    'vehicle_type_id': 'moto',
    'payment_method': 'momo_ussd',
    'amount_rwf': 3000,
    'amount_tokens': 3000,
    'currency': 'RWF',
    'reference_code': 'SUB-001',
    'momo_pay_code': '12345',
    'status': 'pending',
    'created_at': '2026-09-30T12:00:00Z',
    'expires_at': '2026-09-30T12:30:00Z',
  };

  test('subscription request retains exact positive amounts', () {
    final row = SubscriptionPaymentRequestOpsRow.fromJson(requestRow());
    expect(row.amountRwf, 3000);
    expect(row.amountTokens, 3000);
  });

  test('missing amount cannot become a zero value', () {
    expect(
      () => SubscriptionPaymentRequestOpsRow.fromJson(
        requestRow()..remove('amount_rwf'),
      ),
      throwsFormatException,
    );
  });

  test('lost admin expiry response remains an unknown mutation', () async {
    final client = SupabaseClient(
      'https://subscription-contract.invalid',
      'mock-public-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((_) async => throw const SocketException('lost')),
    );
    addTearDown(client.dispose);
    await expectLater(
      SubscriptionPlanService(supabase: client).expireStalePaymentRequests(),
      throwsA(isA<MutationOutcomeUnknownException>()),
    );
  });
}
