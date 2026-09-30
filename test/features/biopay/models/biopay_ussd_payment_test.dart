import 'package:flutter_test/flutter_test.dart';
import 'package:mobi_app/features/biopay/domain/biopay_ussd_payment.dart';

void main() {
  test('parses token and formats external USSD request amount', () {
    final request = BioPayUssdPaymentRequest.fromJson({
      'id': '11111111-1111-4111-8111-111111111111',
      'token': 'abcdefghijklmnopqrstuvwx',
      'channel': 'qr',
      'provider_code': 'mtn_rw',
      'payee_label': 'Moto driver',
      'amount_minor': 150000,
      'currency': 'RWF',
      'reference': 'BP-123',
      'ussd_code': '*182*8*1*250788000000*1500#',
      'status': 'ready_to_dial',
      'created_at': '2026-06-12T08:30:00Z',
      'expires_at': '2026-06-12T08:45:00Z',
      'confirmed_at': null,
      'confirmation_source': null,
    });

    expect(request.token, 'abcdefghijklmnopqrstuvwx');
    expect(request.channel, BioPayRequestChannel.qr);
    expect(request.status, BioPayRequestStatus.readyToDial);
    expect(request.amountLabel, 'RWF 1,500');
    expect(request.toJson()['token'], 'abcdefghijklmnopqrstuvwx');

    final markedPaid = request.copyWith(
      status: BioPayRequestStatus.userMarkedPaid,
    );
    expect(markedPaid.status, BioPayRequestStatus.userMarkedPaid);
    expect(markedPaid.toJson()['status'], 'user_marked_paid');
    expect(markedPaid.createdAt?.toUtc().toIso8601String(), contains('2026'));

    final confirmed = markedPaid.copyWith(
      status: BioPayRequestStatus.confirmed,
      confirmedAt: DateTime.utc(2026, 6, 12, 9),
      confirmationSource: 'operator_external_reference',
    );
    expect(confirmed.status, BioPayRequestStatus.confirmed);
    expect(confirmed.confirmationSource, 'operator_external_reference');
    expect(confirmed.toJson()['confirmation_source'], isNotNull);
  });
}
