import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobi_app/core/auth/auth_session_storage.dart';
import 'package:mobi_app/core/auth/session_persistence.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('mobio.test.session.deadline');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test(
    'a hung native read faults storage and a late reply never creates trust',
    () async {
      final reply = Completer<String?>();
      final calls = <String>[];
      messenger.setMockMethodCallHandler(channel, (call) {
        calls.add(call.method);
        return reply.future;
      });
      final persistence = SessionPersistence(
        store: NativeSessionValueStore(
          'synthetic',
          channel: channel,
          readTimeout: const Duration(milliseconds: 2),
        ),
        issuer: 'https://fixture.invalid/auth/v1',
        purgeLegacy: () async {},
      );
      await expectLater(
        persistence.initialize(),
        throwsA(isA<SessionStorageFailure>()),
      );
      expect(persistence.failed, isTrue);
      expect(persistence.isReady, isFalse);
      reply.complete('opaque-late-session');
      await Future<void>.delayed(Duration.zero);
      expect(persistence.failed, isTrue);
      expect(persistence.acceptedIdentity, isNull);
      await expectLater(
        persistence.read(),
        throwsA(isA<SessionStorageFailure>()),
      );
      expect(calls, ['read']);
    },
  );
}
