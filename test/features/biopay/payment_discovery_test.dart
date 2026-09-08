import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobi_app/features/biopay/application/payment_composer_controller.dart';
import 'package:mobi_app/features/biopay/data/payment_discovery_service.dart';
import 'package:mobi_app/features/biopay/domain/payment_discovery.dart';
import 'package:mobi_app/features/biopay/domain/payment_entry.dart';

const source = PaymentMethod(
  id: 'source',
  ownerId: 'payer',
  provider: 'mtn_rw',
  kind: PaymentMethodKind.mobileWallet,
  identifier: '+250788000001',
  label: 'My MoMo',
  canSend: true,
);
const destination = PaymentMethod(
  id: 'destination',
  ownerId: 'receiver',
  provider: 'bpr_rw',
  kind: PaymentMethodKind.bankAccount,
  identifier: '0012345678',
  label: 'Receiving bank',
);
PaymentOption option(
  String id,
  PaymentFee fee, {
  int? steps,
  String? unavailable,
}) => PaymentOption(
  id: id,
  source: source,
  destination: destination,
  rail: id,
  fee: fee,
  adapterVersion: 1,
  tariffVersion: 1,
  steps: steps,
  unavailableReason: unavailable,
);

void main() {
  group('whole RWF and identifiers', () {
    test('only positive bounded integer francs can become a payment', () {
      for (final value in [
        '',
        '0',
        '-1',
        '1.5',
        '1e3',
        '1,000',
        '10000001',
        '99999999999999999',
      ]) {
        expect(parseRwf(value), isNull, reason: value);
      }
      expect(parseRwf('1000'), 1000);
      expect(parseRwf('10000000'), 10000000);
      expect(legacyMinorFromRwf(1000), 100000);
      expect(rwfFromLegacyMinor(100000), 1000);
      expect(() => rwfFromLegacyMinor(100001), throwsFormatException);
    });
    test('Rwanda phone normalization does not guess bank identifiers', () {
      expect(normalizeRwandaPhone('0788 000 001'), '+250788000001');
      expect(normalizeRwandaPhone('+250788000001'), '+250788000001');
      expect(normalizeRwandaPhone('+254788000001'), isNull);
      expect(normalizeRwandaPhone('text0788000001'), isNull);
      expect(
        PaymentMethod.fromJson(destination.toJson()).identifier,
        '0012345678',
      );
    });
    test('sending and receiving are independent from discovery', () {
      final restored = PaymentMethod.fromJson(source.toJson());
      expect(restored.canSend, isTrue);
      expect(restored.canReceive, isTrue);
      expect(restored.phoneDiscoverable, isFalse);
    });
  });
  group('honest fee comparison', () {
    test('all-in cap20 sorts before exact100, unknown never zero', () {
      final exact = option(
        'exact',
        const PaymentFee(
          certainty: FeeCertainty.exact,
          francs: 100,
          allIn: true,
        ),
      );
      final cap = option(
        'cap',
        const PaymentFee(
          certainty: FeeCertainty.capped,
          francs: 20,
          allIn: true,
        ),
      );
      final unknown = option(
        'unknown',
        const PaymentFee(certainty: FeeCertainty.unknown),
      );
      expect(rankPaymentOptions([unknown, exact, cap]), [cap, exact, unknown]);
      expect(unknown.fee.totalUpperBound(1000), isNull);
      expect(cap.fee.totalUpperBound(1000), 1020);
    });
    test('partial caps cannot create an all-in fee or total', () {
      const partial = PaymentFee(certainty: FeeCertainty.capped, francs: 20);
      expect(partial.upperBound, isNull);
      expect(partial.totalUpperBound(1000), isNull);
    });
    test('equal caps do not claim fewer steps mean equal actual price', () {
      const fee = PaymentFee(
        certainty: FeeCertainty.capped,
        francs: 20,
        allIn: true,
      );
      final a = option('a', fee, steps: 6);
      final b = option('b', fee, steps: 2);
      expect(rankPaymentOptions([b, a]), [a, b]);
    });
    test('verified steps may resolve equal known exact fees', () {
      const fee = PaymentFee(
        certainty: FeeCertainty.exact,
        francs: 20,
        allIn: true,
      );
      final a = option('a', fee, steps: 6);
      final b = option('b', fee, steps: 2);
      expect(rankPaymentOptions([a, b]), [b, a]);
    });
    test('underlying duplicate routes collapse; unavailable never ranks', () {
      final first = option(
        'rail',
        const PaymentFee(certainty: FeeCertainty.unknown),
      );
      const duplicate = PaymentOption(
        id: 'duplicate',
        source: source,
        destination: destination,
        rail: 'rail',
        fee: PaymentFee(
          certainty: FeeCertainty.exact,
          francs: 0,
          allIn: true,
        ),
        adapterVersion: 2,
        tariffVersion: 2,
      );
      final unavailable = option(
        'disabled',
        const PaymentFee(certainty: FeeCertainty.exact, francs: 0, allIn: true),
        unavailable: 'disabled',
      );
      expect(rankPaymentOptions([first, unavailable, duplicate]), [duplicate]);
    });
  });
  group('one safe payment entry parser', () {
    const token = '0123456789abcdef0123456789abcdef0123456789abcdef';
    test('opaque own-domain links roundtrip', () {
      expect(parsePaymentEntry(bioPayShareUri(token).toString())?.token, token);
      expect(parsePaymentEntry(token)?.token, token);
    });
    test(
      'foreign hosts, query injection, fragments and malformed code rejected',
      () {
        for (final value in [
          'https://evil.example/biopay/pay/$token',
          'https://mobio.ikanisa.com.evil/biopay/pay/$token',
          'https://user@mobio.ikanisa.com/biopay/pay/$token',
          'https://mobio.ikanisa.com/biopay/pay/$token?code=*182%23',
          'https://mobio.ikanisa.com/biopay/pay/$token#code',
          'tel:*182*1*1*0788000001*1000*999%23',
          'tel:%not-encoded',
          '123456',
          '{"token":"$token","unexpected":',
          '*182*4*5#',
        ]) {
          expect(parsePaymentEntry(value), isNull, reason: value);
        }
      },
    );
    test(
      'legacy USSD becomes unverified recipient data without executable code',
      () {
        final entry = parsePaymentEntry('tel:*182*8*1*001234*1000%23')!;
        expect(entry.manual?.identifier, '001234');
        expect(entry.manual?.kind, PaymentMethodKind.merchantCode);
        expect(entry.amount, 1000);
        expect(entry.legacy, isTrue);
        expect(entry.token, isNull);
      },
    );
  });
  group('account-bound draft controller', () {
    late FakeGateway gateway;
    late PaymentComposerController controller;
    setUp(() {
      gateway = FakeGateway();
      controller = PaymentComposerController(
        gateway: gateway,
        draft: const PaymentDraft(
          id: 'draft',
          ownerId: 'payer',
          lookup: '+250788000002',
          amount: '1000',
        ),
      );
    });
    tearDown(() => controller.dispose());
    test('failed persistence never shows saved or requests a quote', () async {
      gateway.fail = 'save_draft';
      await controller.quote();
      expect(controller.saved, isFalse);
      expect(controller.quoteId, isNull);
      expect(gateway.calls, ['save_draft']);
      expect(controller.busy, isFalse);
    });
    test('late quote cannot overwrite a newer draft', () async {
      gateway.pendingQuote = Completer();
      final pending = controller.quote();
      await Future<void>.delayed(Duration.zero);
      controller.edit(controller.draft.copyWith(amount: '2000'));
      gateway.pendingQuote!.complete(gateway.quote);
      await pending;
      expect(controller.draft.amount, '2000');
      expect(controller.quoteId, isNull);
      expect(controller.options, isEmpty);
    });
    test('source change invalidates review', () async {
      await controller.quote();
      controller
        ..review(controller.options.single)
        ..edit(controller.draft.copyWith(sourceId: 'different'));
      expect(controller.selected, isNull);
      expect(await controller.prepare(), isNull);
      expect(gateway.calls, isNot(contains('prepare')));
    });
    test(
      'prepare requires explicit review and consumes the reviewed quote once',
      () async {
        await controller.quote();
        expect(await controller.prepare(), isNull);
        controller.review(controller.options.single);
        final prepared = await controller.prepare();
        expect(prepared?['attempt_id'], 'attempt');
        expect(controller.step, ComposerStep.outcome);
        expect(controller.draft.evidence, PaymentEvidence.prepared);
        expect(await controller.prepare(), isNull);
        expect(gateway.calls.where((a) => a == 'prepare').length, 1);
      },
    );
    test('resuming cannot claim completion or resubmit', () async {
      await controller.quote();
      controller.review(controller.options.single);
      await controller.prepare();
      final calls = gateway.calls.length;
      controller.invalidateOnResume();
      expect(controller.draft.evidence, PaymentEvidence.prepared);
      expect(gateway.calls.length, calls);
      expect(controller.step, ComposerStep.outcome);
    });
    test(
      'account switch prevents results from entering another account',
      () async {
        gateway.pendingQuote = Completer();
        final pending = controller.quote();
        await Future<void>.delayed(Duration.zero);
        gateway.ownerId = 'other';
        gateway.pendingQuote!.complete(gateway.quote);
        await pending;
        expect(controller.options, isEmpty);
        expect(await controller.prepare(), isNull);
        expect(controller.accountCurrent, isFalse);
      },
    );
    test(
      'a failed post-prepare save cannot expose instructions or reuse the quote',
      () async {
        await controller.quote();
        controller.review(controller.options.single);
        gateway.fail = 'save_draft';
        expect(await controller.prepare(), isNull);
        expect(controller.prepared, isNull);
        expect(controller.draft.attemptId, 'attempt');
        expect(controller.step, ComposerStep.outcome);
        expect(controller.saved, isFalse);
        expect(await controller.prepare(), isNull);
        expect(gateway.calls.where((a) => a == 'prepare').length, 1);
      },
    );
    test(
      'an open-amount request still pins purpose and recipient reference',
      () async {
        gateway.resolved = {
          ...gateway.quote['recipient'] as Map<String, dynamic>,
          'purpose': 'merchant',
          'reference': 'Lunch',
        };
        await controller.resolve();
        expect(controller.draft.purpose, PaymentPurpose.merchant);
        expect(controller.draft.reference, 'Lunch');
        expect(controller.draft.amount, '1000');
      },
    );
    test(
      'changing to a manual recipient clears the previous link and attempt',
      () {
        final prior = controller.draft.copyWith(
          linkToken: 'old-link',
          attemptId: 'prior',
          evidence: PaymentEvidence.handoffOpened,
        );
        final next = prior.copyWith(
          clearRecipient: true,
          manualMethod: destination,
        );
        expect(next.linkToken, isNull);
        expect(next.manualMethod, destination);
        expect(next.attemptId, isNull);
        expect(next.evidence, PaymentEvidence.draft);
      },
    );
    test('client cannot record provider confirmation', () async {
      await controller.quote();
      controller.review(controller.options.single);
      await controller.prepare();
      await controller.record(PaymentEvidence.providerConfirmed);
      expect(gateway.calls, isNot(contains('record_attempt')));
    });
  });
}

class FakeGateway implements PaymentDiscoveryGateway {
  @override
  String? ownerId = 'payer';
  @override
  String get deviceFamily => 'android';
  String? fail;
  Map<String, dynamic>? resolved;
  Completer<Map<String, dynamic>>? pendingQuote;
  final calls = <String>[];
  Map<String, dynamic> get quote => {
    'quote_id': 'quote',
    'expires_at': DateTime.now()
        .add(const Duration(minutes: 2))
        .toIso8601String(),
    'recipient': {
      'label': 'Shared',
      'assurance': 'shared',
      'methods': [destination.toJson()],
    },
    'options': [
      {
        'id': 'option',
        'source': source.toJson(),
        'destination': destination.toJson(),
        'rail': 'eKash',
        'fee': {'certainty': 'capped', 'francs': 20, 'all_in': true},
        'adapter_version': 1,
        'tariff_version': 1,
      },
    ],
  };
  @override
  Future<Map<String, dynamic>> call(
    String action,
    Map<String, dynamic> data,
  ) async {
    calls.add(action);
    if (fail == action) throw StateError('fixture failure');
    return switch (action) {
      'quote' => pendingQuote == null ? quote : await pendingQuote!.future,
      'resolve' => resolved ?? quote['recipient'] as Map<String, dynamic>,
      'prepare' => {
        'attempt_id': 'attempt',
        'mode': 'instructions',
        'instruction': 'Fixture instructions',
      },
      'record_attempt' => {'evidence': data['evidence']},
      _ => data,
    };
  }

  @override
  Future<void> rememberDraft(String ownerId, String draftId) async {}
  @override
  Future<String?> rememberedDraft(String ownerId) async => null;
}
