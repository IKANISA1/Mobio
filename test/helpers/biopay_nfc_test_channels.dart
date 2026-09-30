import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _writer = MethodChannel('rw.mobi.app/biopay_nfc_writer');
const _reader = MethodChannel('rw.mobi.app/biopay_native_nfc_reader');
const _device = MethodChannel('rw.mobi.app/biopay_device_nfc');
const _kit = MethodChannel('flutter_nfc_kit/method');

/// Acknowledge native lifecycle work in visual fixtures. Dedicated NFC tests
/// provide their own held/lost replies; presentation tests have no NFC device.
void installBioPayNfcTestChannels() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
    ..setMockMethodCallHandler(_writer, (_) async => null)
    ..setMockMethodCallHandler(_reader, (_) async => null)
    ..setMockMethodCallHandler(
      _device,
      (_) async => {'supported': false, 'enabled': false},
    )
    ..setMockMethodCallHandler(
      _kit,
      (call) async =>
          call.method == 'getNFCAvailability' ? 'not_supported' : null,
    );
}

void uninstallBioPayNfcTestChannels() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
    ..setMockMethodCallHandler(_writer, null)
    ..setMockMethodCallHandler(_reader, null)
    ..setMockMethodCallHandler(_device, null)
    ..setMockMethodCallHandler(_kit, null);
}
