import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobi_app/core/auth/auth_session_storage.dart';
import 'package:mobi_app/core/auth/session_persistence.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('mobio/synthetic-test-only');
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late NativeSessionValueStore store;
  setUp(() { store = NativeSessionValueStore('a' * 64, channel: channel); });
  tearDown(() { messenger.setMockMethodCallHandler(channel, null); });
  test('native read uses the exact namespace', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'read'); expect((call.arguments as Map)['namespace'], 'a' * 64); return 'synthetic';
    }); expect(await store.read(), 'synthetic');
  });
  test('write requires affirmative native acknowledgement', () async {
    messenger.setMockMethodCallHandler(channel, (_) async => false);
    await expectLater(store.write('synthetic'), throwsA(isA<SessionStorageFailure>()));
  });
  test('missing plugin cannot trigger a plaintext fallback', () async {
    await expectLater(store.read(), throwsA(isA<MissingPluginException>()));
  });
  test('native keychain/keystore errors propagate', () async {
    messenger.setMockMethodCallHandler(channel, (_) async { throw PlatformException(code: 'AUTH_STORAGE_UNAVAILABLE'); });
    await expectLater(store.read(), throwsA(isA<PlatformException>()));
  });
  test('clear and reset are distinct explicit scoped calls', () async {
    final calls = <String>[];
    messenger.setMockMethodCallHandler(channel, (call) async { calls.add(call.method); return true; });
    await store.clear(); await store.reset(); expect(calls, ['clear', 'reset']);
  });
}
