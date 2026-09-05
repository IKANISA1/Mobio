import 'package:flutter_test/flutter_test.dart';
import 'package:mobi_app/features/biopay/data/biopay_nfc_card_payload.dart';
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
      expect(payload.ussdTelLink, 'tel:*182*1*1*0788123456%23');
      expect(payload.deepLink, contains('type=momo_number'));
      expect(payload.deepLink, contains('receiver=0788123456'));
      expect(payload.appLink, 'tel:*182*1*1*0788123456%23');
      expect(payload.appLink, isNot(contains('mobio.ikanisa.com')));
      expect(payload.toJson()['provider_code'], 'mtn_rw');
      expect(payload.toJson()['ussd_code'], '*182*1*1*0788123456#');
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

    test('rejects invalid MoMo Pay code lengths', () {
      expect(
        normalizeBioPayNfcReceiver(
          '1234',
          receiverType: BioPayNfcReceiverType.momoPayCode,
        ),
        isEmpty,
      );
      expect(
        normalizeBioPayNfcReceiver(
          '1234567',
          receiverType: BioPayNfcReceiverType.momoPayCode,
        ),
        isEmpty,
      );
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
        BioPayNfcCardPayload.fromRawText(payload.appLink)?.ussdCode,
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

    test('compares card payloads semantically after phone normalization', () {
      const expected = BioPayNfcCardPayload(
        receiverType: BioPayNfcReceiverType.momoNumber,
        receiver: '0788123456',
      );
      const readBack = BioPayNfcCardPayload(
        receiverType: BioPayNfcReceiverType.momoNumber,
        receiver: '250788123456',
      );

      expect(readBack.ussdCode, isNot(expected.ussdCode));
      expect(readBack.semanticallyMatches(expected), isTrue);
    });

    test('writes tel USSD URI, MIME JSON fallback, and AAR', () {
      const payload = BioPayNfcCardPayload(
        receiverType: BioPayNfcReceiverType.momoNumber,
        receiver: '0788123456',
      );

      final records = buildBioPayNfcCardRecords(payload);

      expect(records, hasLength(3));
      expect(records[0], isA<ndef.UriRecord>());
      expect(
        (records[0] as ndef.UriRecord).uriString,
        'tel:*182*1*1*0788123456%23',
      );
      expect(
        (records[0] as ndef.UriRecord).uriString,
        isNot(contains('mobio.ikanisa.com')),
      );
      expect(records[1], isA<ndef.MimeRecord>());
      expect(records[2], isA<ndef.AARRecord>());
      expect(
        bioPayNfcCardPayloadFromRecords(records)?.ussdCode,
        payload.ussdCode,
      );
    });

    test('selects a compact NDEF record set for small NFC card capacity', () {
      const payload = BioPayNfcCardPayload(
        receiverType: BioPayNfcReceiverType.momoPayCode,
        receiver: '123456',
      );

      final unknownCapacity = buildBioPayNfcCardRecordsForCapacity(payload);
      final smallCapacity = buildBioPayNfcCardRecordsForCapacity(
        payload,
        capacity: 144,
      );
      final tinyCapacity = buildBioPayNfcCardRecordsForCapacity(
        payload,
        capacity: 48,
      );

      expect(unknownCapacity, hasLength(2));
      expect(smallCapacity.length, lessThanOrEqualTo(2));
      expect(tinyCapacity, hasLength(1));
      expect(
        bioPayNfcCardPayloadFromRecords(smallCapacity)?.ussdCode,
        payload.ussdCode,
      );
      expect(
        bioPayNfcCardPayloadFromRecords(tinyCapacity)?.ussdCode,
        payload.ussdCode,
      );
    });
  });
}
