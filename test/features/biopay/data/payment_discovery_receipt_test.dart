import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobi_app/core/auth/account_context.dart';
import 'package:mobi_app/core/errors/app_exception.dart';
import 'package:mobi_app/features/biopay/data/payment_discovery_service.dart';
import 'package:mobi_app/features/biopay/domain/payment_discovery.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'biopay_face_service_boundary_test.dart' show signIn;

void main() {
  const owner = '11111111-1111-4111-8111-111111111111';
  Future<PaymentDiscoveryService> service(Object? response) async {
    final client = SupabaseClient(
      'https://receipt-contract.invalid',
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
    await signIn(client);
    return PaymentDiscoveryService(
      client,
      captureAccount: () => const AccountSnapshot(owner, 'fixture', 0),
      isCurrent: (_) => true,
    );
  }

  for (final action in [
    'save_method',
    'save_draft',
    'quote',
    'prepare',
    'pay_again',
    'record_attempt',
    'acknowledge',
    'create_link',
    'save_template',
  ]) {
    test(
      'malformed successful $action receipt remains unknown with its request ID',
      () async {
        final gateway = await service(<String, dynamic>{});
        await expectLater(
          gateway.call(action, {'id': 'request-1'}),
          throwsA(
            isA<MutationOutcomeUnknownException>().having(
              (error) => error.operationId,
              'original request',
              'request-1',
            ),
          ),
        );
      },
    );
  }
  test(
    'explicit empty SQL mutation receipt is accepted, unexpected fields are unknown',
    () async {
      expect(
        await (await service(
          <String, dynamic>{},
        )).call('remove_method', {'id': 'method'}),
        isEmpty,
      );
      await expectLater(
        (await service({'ok': true})).call('remove_method', {'id': 'method'}),
        throwsA(isA<MutationOutcomeUnknownException>()),
      );
    },
  );
  test('malformed workspace read is unavailable, never preview data', () async {
    await expectLater(
      (await service({'methods': []})).call('workspace', {}),
      throwsFormatException,
    );
  });
  test(
    'link preview requires a boolean availability before any continuation',
    () async {
      await expectLater(
        (await service({'available': 'true'})).previewLink('token'),
        throwsFormatException,
      );
      expect(await (await service({'available': false})).previewLink('token'), {
        'available': false,
      });
    },
  );
  test('malformed route mutation receipt is unknown', () async {
    await expectLater(
      (await service(<String, dynamic>{})).adminCall('save', {}),
      throwsA(isA<MutationOutcomeUnknownException>()),
    );
  });
  test(
    'a full new method receipt accepts its server-assigned ID and version one',
    () async {
      const method = PaymentMethod(
        id: '',
        ownerId: owner,
        provider: 'mtn_rw',
        kind: PaymentMethodKind.mobileWallet,
        identifier: '+250788000001',
        label: 'MoMo',
        canSend: true,
      );
      final response = {...method.toJson(), 'id': 'server-id'};
      expect(
        (await (await service(
          response,
        )).call('save_method', method.toJson()))['id'],
        'server-id',
      );
    },
  );
  test(
    'complete empty workspace is legitimate without fabricated records',
    () async {
      final workspace = {
        for (final key in [
          'methods',
          'links',
          'drafts',
          'recents',
          'templates',
          'activity',
        ])
          key: <Object>[],
      };
      expect(await (await service(workspace)).call('workspace', {}), workspace);
    },
  );
  test(
    'valid prepare receipt retains reviewed instruction and evidence',
    () async {
      final prepared = {
        'attempt_id': 'attempt',
        'mode': 'dial',
        'instruction': '*182#',
        'evidence': 'prepared',
        'source_label': 'MoMo',
        'sim_label': null,
      };
      expect(
        await (await service(prepared)).call('prepare', {'quote_id': 'quote'}),
        prepared,
      );
    },
  );
  test('new method version and persisted label cannot be fabricated', () async {
    const method = PaymentMethod(
      id: '',
      ownerId: owner,
      provider: 'mtn_rw',
      kind: PaymentMethodKind.mobileWallet,
      identifier: '+250788000001',
      label: 'MoMo',
      canSend: true,
    );
    for (final changed in [
      {'version': 2},
      {'label': 'Other'},
      {'sim_label': 'Other SIM'},
      {'active': false},
    ]) {
      final response = {...method.toJson(), 'id': 'server-id', ...changed};
      await expectLater(
        (await service(response)).call('save_method', method.toJson()),
        throwsA(isA<MutationOutcomeUnknownException>()),
      );
    }
  });
  test(
    'action evidence cannot be mistaken for acknowledgment or another attempt',
    () async {
      await expectLater(
        (await service({
          'evidence': 'handoffOpened',
        })).call('acknowledge', {'id': 'attempt'}),
        throwsA(isA<MutationOutcomeUnknownException>()),
      );
      await expectLater(
        (await service({'evidence': 'outcomeUnknown'})).call('record_attempt', {
          'id': 'attempt',
          'evidence': 'handoffOpened',
        }),
        throwsA(isA<MutationOutcomeUnknownException>()),
      );
      expect(
        await (await service({'evidence': 'providerConfirmed'})).call(
          'record_attempt',
          {'id': 'attempt', 'evidence': 'handoffOpened'},
        ),
        {'evidence': 'providerConfirmed'},
      );
    },
  );
  test(
    'pay-again must return a fresh draft rather than a claimed completed attempt',
    () async {
      final response = const PaymentDraft(
        id: 'fresh',
        ownerId: owner,
        revision: 1,
        evidence: PaymentEvidence.providerConfirmed,
      ).toJson();
      await expectLater(
        (await service(response)).call('pay_again', {'id': 'old'}),
        throwsA(isA<MutationOutcomeUnknownException>()),
      );
    },
  );
  test('template receipt must preserve exact submitted data', () async {
    final response = {
      'id': 'template',
      'owner_id': owner,
      'label': 'Lunch',
      'data': {'amount_rwf': 2000},
      'created_at': '2026-09-30T12:00:00Z',
    };
    await expectLater(
      (await service(response)).call('save_template', {
        'label': 'Lunch',
        'data': {'amount_rwf': 1000},
      }),
      throwsA(isA<MutationOutcomeUnknownException>()),
    );
  });
  test('complete template receipt retains nested submitted values', () async {
    final input = {
      'label': ' Lunch ',
      'data': {
        'purpose': 'merchant',
        'method_ids': ['22222222-2222-4222-8222-222222222222'],
        'amount_rwf': 1000,
        'options': {'reference': 'Invoice 7', 'any_amount': false},
      },
    };
    final response = {
      'id': '33333333-3333-4333-8333-333333333333',
      'owner_id': owner,
      'label': input['label'],
      'data': {
        'options': {'any_amount': false, 'reference': 'Invoice 7'},
        'amount_rwf': 1000,
        'method_ids': ['22222222-2222-4222-8222-222222222222'],
        'purpose': 'merchant',
      },
      'created_at': '2026-09-30T12:00:00Z',
    };
    expect(
      await (await service(response)).call('save_template', input),
      response,
    );
  });
  test(
    'new link receipt preserves SQL normalization and expiry instant',
    () async {
      const methodId = '22222222-2222-4222-8222-222222222222';
      final input = {
        'scope': 'request',
        'method_ids': [methodId],
        'label': ' Lunch ',
        'amount_rwf': 1000,
        'purpose': 'merchant',
        'reference': 'Invoice 7',
        'expires_at': '2026-10-02T14:00:00+02:00',
      };
      final response = {
        ...input,
        'id': '33333333-3333-4333-8333-333333333333',
        'owner_id': owner,
        'token': '0123456789abcdef0123456789abcdef0123456789abcdef',
        'method_versions': {methodId: 2},
        'label': 'Lunch',
        'expires_at': '2026-10-02T12:00:00Z',
        'version': 1,
        'revoked_at': null,
        'created_at': '2026-09-30T12:00:00Z',
      };
      expect(
        await (await service(response)).call('create_link', input),
        response,
      );
      for (final changed in [
        {'label': 'Different request'},
        {'reference': 'Invoice 8'},
        {'expires_at': '2026-10-03T12:00:00Z'},
        {'version': 2},
        {'revoked_at': '2026-09-30T13:00:00Z'},
      ]) {
        await expectLater(
          (await service({...response, ...changed})).call('create_link', input),
          throwsA(isA<MutationOutcomeUnknownException>()),
        );
      }
    },
  );
  test(
    'pay-again receipt is a fresh draft with no previous attempt evidence',
    () async {
      final response = const PaymentDraft(
        id: '33333333-3333-4333-8333-333333333333',
        ownerId: owner,
        lookup: '+250788000002',
        amount: '1000',
        reference: 'Invoice 7',
        sourceId: '22222222-2222-4222-8222-222222222222',
      ).toJson();
      final result = await (await service(
        response,
      )).call('pay_again', {'id': '44444444-4444-4444-8444-444444444444'});
      expect(result, response);
      final draft = PaymentDraft.fromJson(result);
      expect(draft.revision, 0);
      expect(draft.evidence, PaymentEvidence.draft);
      expect(draft.attemptId, isNull);
    },
  );
  test(
    'legacy fractional history remains exact and does not disable workspace',
    () async {
      final workspace = {
        for (final key in [
          'methods',
          'links',
          'drafts',
          'recents',
          'templates',
          'activity',
        ])
          key: <Object>[],
      };
      workspace['activity'] = [
        {
          'id': 'legacy',
          'payer_id': owner,
          'payee_id': null,
          'payee_label': 'Merchant',
          'amount_minor': 150050,
          'currency': 'RWF',
          'updated_at': '2026-09-30T12:00:00Z',
          'evidence_kind': 'unclassified',
          'reviewed_snapshot': null,
        },
      ];
      expect(
        (await (await service(workspace)).call('workspace', {}))['activity'],
        workspace['activity'],
      );
      expect(formatHistoricalRwfMinor(150050), '1500.50 RWF');
      expect(formatHistoricalRwfMinor(150000), '1500 RWF');
      expect(formatHistoricalAmountMinor(150050, 'USD'), '1500.50 USD');
    },
  );
}
