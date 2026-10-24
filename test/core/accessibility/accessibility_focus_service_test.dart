import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobi_app/core/accessibility/accessibility_focus_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('rw.mobi.app/accessibility_focus');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
  });
  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
    debugDefaultTargetPlatformOverride = null;
  });

  test('native outcome is authoritative for the current virtual ID', () async {
    final calls = <MethodCall>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return calls.length == 1;
    });
    expect(await AccessibilityFocusService.restoreFocus(37), isTrue);
    expect(await AccessibilityFocusService.restoreFocus(38), isFalse);
    expect(calls.map((call) => call.arguments), [
      {'nodeId': 37},
      {'nodeId': 38},
    ]);
  });

  test('unsupported platforms and invalid IDs make no native call', () async {
    var calls = 0;
    messenger.setMockMethodCallHandler(channel, (_) async {
      calls++;
      return true;
    });
    expect(await AccessibilityFocusService.restoreFocus(-1), isFalse);
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    expect(await AccessibilityFocusService.restoreFocus(37), isFalse);
    expect(calls, 0);
  });

  test('absent plugin leaves normal focus handling available', () async {
    expect(await AccessibilityFocusService.restoreFocus(37), isFalse);
  });

  test('platform lifecycle failure declines restoration', () async {
    messenger.setMockMethodCallHandler(channel, (_) async {
      throw PlatformException(code: 'VIEW_DETACHED');
    });
    expect(await AccessibilityFocusService.restoreFocus(37), isFalse);
  });
}
