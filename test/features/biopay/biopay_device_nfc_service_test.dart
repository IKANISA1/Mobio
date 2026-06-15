import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobi_app/features/biopay/biopay_device_nfc_service.dart';
import 'package:mobi_app/features/biopay/models/biopay_ussd_payment.dart';

void main() {
  group('BioPayDeviceNfcService', () {
    test('builds a payment token URI for Android HCE advertisement', () {
      const request = BioPayUssdPaymentRequest(
        id: 'request-1',
        token: 'device-nfc-token-1',
        channel: BioPayRequestChannel.nfc,
        providerCode: 'mtn_rw',
        payeeLabel: 'MoMo receiver',
        amountMinor: 150000,
        currency: 'RWF',
        reference: 'BP-1',
        ussdCode: '*182*1*1*0788123456*1500#',
        status: BioPayRequestStatus.readyToDial,
      );

      final payload = buildDeviceNfcPaymentPayload(request);

      expect(
        payload,
        'https://mobio.ikanisa.com/biopay/nfc?token=device-nfc-token-1',
      );
      expect(payload, isNot(contains('receiver=')));
      expect(payload, isNot(contains('*182')));
    });

    test('extracts token from APDU response payload', () {
      const uri = 'https://mobio.ikanisa.com/biopay/nfc?token=token-123';
      final payloadHex = utf8
          .encode(uri)
          .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
          .join();
      final response = '${payloadHex}9000';

      expect(deviceNfcPayloadFromApduResponse(response), uri);
      expect(deviceNfcTokenFromApduResponse(response), 'token-123');
    });
  });
}
