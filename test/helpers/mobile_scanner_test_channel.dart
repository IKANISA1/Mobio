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
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
    ..setMockMethodCallHandler(_mobileScannerMethodChannel, (
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
    })
    ..setMockMethodCallHandler(
      _mobileScannerEventChannel,
      _handleMobileScannerStreamCall,
    )
    ..setMockMethodCallHandler(
      _mobileScannerOrientationChannel,
      _handleMobileScannerStreamCall,
    );
}

void uninstallMobileScannerTestChannel() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
    ..setMockMethodCallHandler(_mobileScannerMethodChannel, null)
    ..setMockMethodCallHandler(_mobileScannerEventChannel, null)
    ..setMockMethodCallHandler(_mobileScannerOrientationChannel, null);
}

Future<Object?> _handleMobileScannerStreamCall(MethodCall call) async {
  return switch (call.method) {
    'listen' || 'cancel' => null,
    _ => null,
  };
}
