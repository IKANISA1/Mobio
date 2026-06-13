import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const MethodChannel _mobileScannerMethodChannel = MethodChannel(
  'dev.steenbakker.mobile_scanner/scanner/method',
);

const MethodChannel _mobileScannerEventChannel = MethodChannel(
  'dev.steenbakker.mobile_scanner/scanner/event',
);

const MethodChannel _mobileScannerOrientationChannel = MethodChannel(
  'dev.steenbakker.mobile_scanner/scanner/deviceOrientation',
);

void installMobileScannerTestChannel() {
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(_mobileScannerMethodChannel, (
    MethodCall call,
  ) async {
    return switch (call.method) {
      'state' => 0,
      'request' => false,
      'getSupportedLenses' => <int>[],
      'analyzeImage' => null,
      'start' => null,
      'pause' ||
      'stop' ||
      'toggleTorch' ||
      'setScale' ||
      'resetScale' ||
      'updateScanWindow' ||
      'setFocus' => null,
      _ => null,
    };
  });
  for (final channel in [
    _mobileScannerEventChannel,
    _mobileScannerOrientationChannel,
  ]) {
    messenger.setMockMethodCallHandler(channel, (MethodCall call) async {
      return switch (call.method) {
        'listen' || 'cancel' => null,
        _ => null,
      };
    });
  }
}

void uninstallMobileScannerTestChannel() {
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  for (final channel in [
    _mobileScannerMethodChannel,
    _mobileScannerEventChannel,
    _mobileScannerOrientationChannel,
  ]) {
    messenger.setMockMethodCallHandler(channel, null);
  }
}
