import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobi_app/features/biopay/data/payment_discovery_service.dart';
import 'package:mobi_app/features/biopay/domain/face_shortcut.dart';

PreparedFaceUssdShortcut shortcut({
  String request = '33333333-3333-4333-8333-333333333333',
  DateTime? expires,
}) => PreparedFaceUssdShortcut(
  requestId: request,
  payeeId: '22222222-2222-4222-8222-222222222222',
  receivingMethodId: '44444444-4444-4444-8444-444444444444',
  receivingMethodVersion: 2,
  provider: 'mtn_rw',
  routeId: '55555555-5555-4555-8555-555555555555',
  routeVersion: 1,
  ussdCode: '*182*1*1*0788767816#',
  expiresAt: expires ?? DateTime.now().add(const Duration(seconds: 30)),
);

class AndroidGateway extends PaymentDiscoveryService {
  AndroidGateway() : super(null);
  @override
  String get deviceFamily => 'android';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('launch is claimed before awaiting and at most once per request', () {
    final gate = FaceHandoffGate();
    final ticket = gate.begin('payer')!;
    final value = shortcut();
    expect(gate.begin('payer'), isNull);
    expect(gate.claim(ticket, 'payer', value, DateTime.now()), isTrue);
    expect(gate.claim(ticket, 'payer', value, DateTime.now()), isFalse);
    gate.finish(ticket);
    final retry = gate.begin('payer')!;
    expect(gate.claim(retry, 'payer', value, DateTime.now()), isFalse);
  });
  for (final reason in ['cancel', 'background', 'account', 'expired']) {
    test('$reason rejects late dialer launch', () {
      final gate = FaceHandoffGate();
      final ticket = gate.begin('payer')!;
      if (reason == 'cancel') gate.cancel();
      if (reason == 'background') {
        gate
          ..foreground(false)
          ..foreground(true);
      }
      expect(
        gate.claim(
          ticket,
          reason == 'account' ? 'other' : 'payer',
          shortcut(
            expires: reason == 'expired'
                ? DateTime.now().subtract(const Duration(seconds: 1))
                : null,
          ),
          DateTime.now(),
        ),
        isFalse,
      );
    });
  }
  test('Android bridge receives exactly one encoded trailing hash', () async {
    MethodCall? received;
    const channel = MethodChannel('rw.mobi.app/biopay_ussd_dialer');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          received = call;
          return {'launched': true};
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );
    expect(
      await AndroidGateway().openReviewedInstruction({
        'mode': 'dial',
        'instruction': shortcut().ussdCode,
      }),
      isTrue,
    );
    expect(received!.method, 'launchUssd');
    expect(received!.arguments, {'uri': 'tel:*182*1*1*0788767816%23'});
    received = null;
    expect(
      await AndroidGateway().openReviewedInstruction({
        'mode': 'dial',
        'instruction': '*182%23',
      }),
      isFalse,
    );
    expect(received, isNull);
  });
  test('malformed or old payment DTO cannot launch a face shortcut', () {
    for (final data in [
      <String, dynamic>{},
      <String, dynamic>{'status': 'dial_ready', 'ussd_code': 'tel:*182%2523'},
      <String, dynamic>{'amount_minor': 150000},
    ]) {
      expect(
        () => PreparedFaceUssdShortcut.fromJson(data),
        throwsFormatException,
      );
    }
  });
}
