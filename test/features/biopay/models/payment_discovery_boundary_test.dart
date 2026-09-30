import 'package:flutter_test/flutter_test.dart';
import 'package:mobi_app/features/biopay/domain/payment_discovery.dart';
import 'package:mobi_app/features/biopay/domain/payment_discovery_response.dart';

void main() {
  const method = PaymentMethod(
    id: 'method',
    ownerId: 'owner',
    provider: 'bpr_rw',
    kind: PaymentMethodKind.bankAccount,
    identifier: '0012345678',
    label: 'Bank',
    canSend: true,
  );
  Map<String, dynamic> receiving() => {
    for (final key in [
      'id',
      'owner_id',
      'provider',
      'kind',
      'identifier',
      'label',
      'can_receive',
      'version',
      'active',
    ])
      key: method.toJson()[key],
  };

  test(
    'receiving projection preserves bank zeros without private sender roles',
    () {
      final value = PaymentMethod.fromReceivingJson(receiving());
      expect(value.identifier, '0012345678');
      expect(value.canSend, isFalse);
      expect(value.loginPhone, isNull);
      expect(value.preferred, isFalse);
      expect(() => PaymentMethod.fromJson(receiving()), throwsFormatException);
    },
  );
  test('fractional versions and missing boolean capabilities are rejected', () {
    for (final field in [
      'can_send',
      'can_receive',
      'active',
      'preferred',
      'phone_discoverable',
    ]) {
      expect(
        () => PaymentMethod.fromJson(method.toJson()..remove(field)),
        throwsFormatException,
        reason: field,
      );
    }
    expect(
      () => PaymentMethod.fromJson(method.toJson()..['version'] = 1.9),
      throwsFormatException,
    );
  });
  test('manual projection is explicitly ownerless version zero', () {
    final row = receiving()
      ..['id'] = 'manual'
      ..['owner_id'] = ''
      ..['version'] = 0;
    expect(PaymentMethod.fromReceivingJson(row).version, 0);
    expect(
      () => PaymentMethod.fromReceivingJson({...row, 'owner_id': 'owner'}),
      throwsFormatException,
    );
    expect(
      () => PaymentMethod.fromReceivingJson({...row, 'version': 1}),
      throwsFormatException,
    );
  });
  test('fees never truncate fractions or invent a known cap', () {
    for (final value in [1.9, -1, '20']) {
      expect(
        () => PaymentFee.fromJson({
          'certainty': 'capped',
          'francs': value,
          'all_in': true,
        }),
        throwsFormatException,
      );
    }
    expect(
      () => PaymentFee.fromJson({
        'certainty': 'exact',
        'francs': null,
        'all_in': true,
      }),
      throwsFormatException,
    );
    expect(
      PaymentFee.fromJson({
        'certainty': 'unknown',
        'francs': null,
        'all_in': true,
      }).upperBound,
      isNull,
    );
  });
  test(
    'recipient empty methods is legitimate, missing methods or assurance is not',
    () {
      final row = {
        'label': 'Shared receiving details',
        'assurance': 'shared',
        'methods': <Object>[],
      };
      expect(PaymentRecipient.fromJson(row).methods, isEmpty);
      expect(
        () => PaymentRecipient.fromJson({...row}..remove('methods')),
        throwsFormatException,
      );
      expect(
        () => PaymentRecipient.fromJson({...row}..remove('assurance')),
        throwsFormatException,
      );
      expect(
        () => PaymentRecipient.fromJson({...row, 'fixed_amount': 1.5}),
        throwsFormatException,
      );
    },
  );
  test(
    'draft receipt compares nested JSON by value despite object key order',
    () {
      const draft = PaymentDraft(
        id: 'draft',
        ownerId: 'owner',
        manualMethod: PaymentMethod(
          id: 'manual',
          ownerId: '',
          provider: 'bpr_rw',
          kind: PaymentMethodKind.bankAccount,
          identifier: '001234',
          label: 'Manual',
          version: 0,
        ),
      );
      final input = draft.toJson();
      final row = {
        ...input,
        'manual_method': Map.fromEntries(
          (input['manual_method'] as Map<String, dynamic>).entries
              .toList()
              .reversed,
        ),
      };
      expect(
        () => PaymentDiscoveryResponse.validate(
          'save_draft',
          row,
          input,
          'owner',
        ),
        returnsNormally,
      );
      row['amount'] = '500';
      expect(
        () => PaymentDiscoveryResponse.validate(
          'save_draft',
          row,
          input,
          'owner',
        ),
        throwsFormatException,
      );
    },
  );
  test('a missing prepared field cannot authorize an external instruction', () {
    expect(
      () => PaymentPreparedInstruction.fromJson({
        'attempt_id': 'attempt',
        'mode': 'dial',
        'instruction': '*182#',
      }),
      throwsFormatException,
    );
  });
}
