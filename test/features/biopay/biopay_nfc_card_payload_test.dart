import 'package:flutter_test/flutter_test.dart';
import 'package:mobi_app/features/biopay/biopay_nfc_card_payload.dart';
import 'package:ndef/ndef.dart' as ndef;

void main() {
  group('BioPayNfcCardPayload', () {
    test('normalizes MoMo numbers and builds the cash-in USSD code', () {
      final receiver = normalizeBioPayNfcReceiver(
        '+250 788 123 456',
        receiverType: BioPayNfcReceiverType.momoNumber,
      );
      final payload = BioPayNfcCardPayload(
        receiverType: BioPayNfcReceiverType.momoNumber,
        receiver: receiver,
        label: 'Driver 12',
      );

      expect(receiver, '0788123456');
      expect(payload.ussdCode, '*182*1*1*0788123456#');
      expect(payload.deepLink, contains('type=momo_number'));
      expect(payload.deepLink, contains('receiver=0788123456'));
      expect(payload.toJson()['provider_code'], 'mtn_rw');
    });

    test('normalizes MoMo Pay codes and builds the merchant USSD code', () {
      final receiver = normalizeBioPayNfcReceiver(
        ' 123-456 ',
        receiverType: BioPayNfcReceiverType.momoPayCode,
      );
      final payload = BioPayNfcCardPayload(
        receiverType: BioPayNfcReceiverType.momoPayCode,
        receiver: receiver,
      );

      expect(receiver, '123456');
      expect(payload.ussdCode, '*182*8*1*123456#');
      expect(payload.deepLink, contains('type=momo_pay_code'));
    });

    test('parses JSON, app deep links, tel URIs, and raw USSD codes', () {
      const payload = BioPayNfcCardPayload(
        receiverType: BioPayNfcReceiverType.momoPayCode,
        receiver: '456789',
        label: 'Shop counter',
      );

      expect(
        BioPayNfcCardPayload.fromRawText(payload.toJsonString())?.ussdCode,
        '*182*8*1*456789#',
      );
      expect(
        BioPayNfcCardPayload.fromRawText(payload.deepLink)?.ussdCode,
        '*182*8*1*456789#',
      );
      expect(
        BioPayNfcCardPayload.fromRawText('tel:*182*8*1*456789%23')?.ussdCode,
        '*182*8*1*456789#',
      );
      expect(
        BioPayNfcCardPayload.fromRawText('*182*1*1*250788123456#')?.ussdCode,
        '*182*1*1*0788123456#',
      );
    });

    test('writes app deep link, JSON fallback, and Android app record', () {
      const payload = BioPayNfcCardPayload(
        receiverType: BioPayNfcReceiverType.momoNumber,
        receiver: '0788123456',
      );

      final records = buildBioPayNfcCardRecords(payload);

      expect(records, hasLength(3));
      expect(records[0], isA<ndef.UriRecord>());
      expect(records[1], isA<ndef.TextRecord>());
      expect(records[2], isA<ndef.AARRecord>());
    });
  });
}
