import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobi_app/core/auth/account_context.dart';
import 'package:mobi_app/core/errors/app_exception.dart';
import 'package:mobi_app/features/biopay/data/payment_discovery_service.dart';
import 'package:mobi_app/features/biopay/domain/payment_discovery_response.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'biopay_face_service_boundary_test.dart' show signIn;

const _owner = '11111111-1111-4111-8111-111111111111';
const _id = '22222222-2222-4222-8222-222222222222';

Map<String, dynamic> _configuration() => {
  'source_provider': 'mtn_rw',
  'source_kind': 'mobileWallet',
  'destination_provider': 'bpr_rw',
  'destination_kind': 'bankAccount',
  'rail': 'eKash',
  'purpose': 'transfer',
  'min_rwf': 1,
  'max_rwf': 1000000,
  'fee_certainty': 'unknown',
  'fee_rwf': null,
  'steps': 2,
  'handoff_mode': 'instructions',
  'instruction_template': '',
  'device_families': ['android', 'ios'],
  'valid_from': '2026-09-30T10:00:00Z',
  'valid_until': null,
  'evidence_url': null,
  'tariff_evidence_url': null,
  'test_evidence_url': null,
};

Map<String, dynamic> _receipt({String state = 'draft', int version = 1}) => {
  ..._configuration(),
  'id': _id,
  'currency': 'RWF',
  'state': state,
  'adapter_version': version,
  'tariff_version': version,
  'instruction_template': null,
  'recipient_format': 'raw',
  'requires_sim': true,
  'requires_login_phone': false,
  'fee_all_in': false,
  'tested_at': null,
  'tested_by': null,
  'reviewed_at': null,
  'reviewed_by': null,
};

void main() {
  test(
    'new route receipt accepts the explicit SQL defaults and version one',
    () {
      PaymentDiscoveryResponse.admin('save', _receipt(), _configuration());
    },
  );

  test('existing save advances both versions and resets review state', () {
    PaymentDiscoveryResponse.admin('save', _receipt(version: 8), {
      ..._configuration(),
      'id': _id,
      'adapter_version': 7,
      'tariff_version': 7,
    });
  });

  test(
    'route timestamp correlation accepts equal instants in different zones',
    () {
      PaymentDiscoveryResponse.admin('save', {
        ..._receipt(),
        'valid_from': '2026-09-30T12:00:00+02:00',
      }, _configuration());
    },
  );

  for (final action in ['tested', 'approve', 'disable']) {
    final state = {
      'tested': 'tested',
      'approve': 'approved',
      'disable': 'disabled',
    }[action]!;
    test('$action accepts only its SQL version transition', () {
      PaymentDiscoveryResponse.admin(
        action,
        _receipt(state: state, version: action == 'disable' ? 8 : 7),
        {'id': _id, 'adapter_version': 7},
      );
      expect(
        () => PaymentDiscoveryResponse.admin(
          action,
          _receipt(state: state, version: action == 'disable' ? 7 : 8),
          {'id': _id, 'adapter_version': 7},
        ),
        throwsFormatException,
      );
    });
  }

  for (final change in <String, dynamic>{
    'adapter_version': 2,
    'tariff_version': 2,
    'rail': 'unexpected',
    'min_rwf': 2,
    'device_families': ['web'],
    'requires_sim': false,
    'fee_all_in': true,
    'recipient_format': 'e164Digits',
    'instruction_template': 'changed',
    'valid_from': '2026-10-01T10:00:00Z',
    'tested_by': _owner,
  }.entries) {
    test('new save rejects altered persisted ${change.key}', () {
      expect(
        () => PaymentDiscoveryResponse.admin('save', {
          ..._receipt(),
          change.key: change.value,
        }, _configuration()),
        throwsFormatException,
      );
    });
  }

  test(
    'successful but stale route receipt remains unknown with original ID',
    () async {
      final client = SupabaseClient(
        'https://route-receipt.invalid',
        'mock-public-key',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient(
          (request) async => http.Response(
            jsonEncode(_receipt(state: 'disabled', version: 7)),
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          ),
        ),
      );
      addTearDown(client.dispose);
      await signIn(client);
      final service = PaymentDiscoveryService(
        client,
        captureAccount: () => const AccountSnapshot(_owner, 'fixture', 0),
        isCurrent: (_) => true,
      );
      await expectLater(
        service.adminCall('disable', {'id': _id, 'adapter_version': 7}),
        throwsA(
          isA<MutationOutcomeUnknownException>().having(
            (error) => error.operationId,
            'original route ID',
            _id,
          ),
        ),
      );
    },
  );
}
