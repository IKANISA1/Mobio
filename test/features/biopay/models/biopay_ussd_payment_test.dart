import 'package:flutter_test/flutter_test.dart';
import 'package:mobi_app/features/biopay/models/biopay_ussd_payment.dart';

void main() {
  test('parses token and formats external USSD request amount', () {
    final request = BioPayUssdPaymentRequest.fromJson({
      'id': 'request-1',
      'token': 'scan-token-1',
      'channel': 'qr',
      'provider_code': 'mtn_rw',
      'payee_label': 'Moto driver',
      'amount_minor': 150000,
      'currency': 'RWF',
      'reference': 'BP-123',
      'ussd_code': '*182*8*1*250788000000*1500#',
      'status': 'ready_to_dial',
      'created_at': '2026-06-12T08:30:00Z',
    });

    expect(request.token, 'scan-token-1');
    expect(request.channel, BioPayRequestChannel.qr);
    expect(request.status, BioPayRequestStatus.readyToDial);
    expect(request.amountLabel, 'RWF 1500');
    expect(request.toJson()['token'], 'scan-token-1');

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
