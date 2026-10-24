import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_nfc_kit/flutter_nfc_kit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobi_app/core/async/account_epoch.dart';
import 'package:mobi_app/core/errors/app_exception.dart';
import 'package:mobi_app/features/biopay/data/biopay_nfc_card_payload.dart';
import 'package:mobi_app/features/biopay/data/biopay_nfc_service.dart';

const _kit = MethodChannel('flutter_nfc_kit/method');
const _writer = MethodChannel('rw.mobi.app/biopay_nfc_writer');
const _payload = BioPayNfcCardPayload(
  receiverType: BioPayNfcReceiverType.momoNumber,
  receiver: '0788123456',
);
const _service = BioPayNfcService(
  requestTimeout: Duration(milliseconds: 3),
  pollTimeout: Duration(milliseconds: 3),
  nativeMutationTimeout: Duration(milliseconds: 3),
  readBackTimeout: Duration(milliseconds: 3),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  setUp(() => debugDefaultTargetPlatformOverride = TargetPlatform.iOS);
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    messenger.setMockMethodCallHandler(_kit, null);
    messenger.setMockMethodCallHandler(_writer, null);
  });

  Future<Object?> kitDefault(MethodCall call) async => switch (call.method) {
    'getNFCAvailability' => 'available',
    'poll' => jsonEncode({
      'type': 'mifare_ultralight',
      'id': '01',
      'standard': 'ISO 14443',
      'ndefAvailable': true,
      'ndefWritable': true,
      'ndefCanMakeReadOnly': true,
      'ndefCapacity': 4096,
    }),
    'readNDEF' => jsonEncode(
      buildBioPayNfcCardRecords(
        _payload,
      ).map((record) => record.toRaw().toJson()).toList(),
    ),
    _ => null,
  };

  test(
    'a hung availability read releases the caller without a write',
    () async {
      final calls = <String>[];
      messenger.setMockMethodCallHandler(_kit, (call) {
        calls.add(call.method);
        return Completer<Object?>().future;
      });
      await expectLater(
        _service.writeCard(_payload),
        throwsA(isA<TimeoutException>()),
      );
      expect(calls, ['getNFCAvailability']);
    },
  );

  test(
    'the Dart poll deadline also bounds platforms that ignore native timeout',
    () async {
      final calls = <String>[];
      messenger.setMockMethodCallHandler(_kit, (call) {
        calls.add(call.method);
        return call.method == 'poll'
            ? Completer<Object?>().future
            : kitDefault(call);
      });
      await expectLater(
        _service.writeCard(_payload),
        throwsA(isA<TimeoutException>()),
      );
      expect(calls, ['getNFCAvailability', 'poll', 'finish']);
    },
  );

  testWidgets(
    'explicit iOS cancel finishes once and blocks late tag mutation',
    (tester) async {
      try {
        const service = BioPayNfcService();
        final tag = Completer<Object?>();
        final calls = <String>[];
        messenger.setMockMethodCallHandler(_kit, (call) {
          calls.add(call.method);
          return call.method == 'poll' ? tag.future : kitDefault(call);
        });
        Object? error;
        final work = service
            .writeCard(_payload)
            .then<void>((_) {}, onError: (Object e) => error = e);
        await tester.pump();
        expect(calls, ['getNFCAvailability', 'poll']);
        await service.cancelActiveSession();
        await service.cancelActiveSession();
        tag.complete(await kitDefault(const MethodCall('poll')));
        await tester.pump();
        await work;
        expect(error, isA<StaleAccountWork>());
        expect(calls, ['getNFCAvailability', 'poll', 'finish']);
        expect(tester.takeException(), isNull);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );

  testWidgets(
    'cancel during availability cannot open a late iOS reader sheet',
    (tester) async {
      try {
        const service = BioPayNfcService();
        final availability = Completer<Object?>();
        final calls = <String>[];
        messenger.setMockMethodCallHandler(_kit, (call) {
          calls.add(call.method);
          return availability.future;
        });
        Object? error;
        final work = service
            .writeCard(_payload)
            .then<void>((_) {}, onError: (Object e) => error = e);
        await tester.pump();
        await service.cancelActiveSession();
        availability.complete('available');
        await tester.pump();
        await work;
        expect(error, isA<StaleAccountWork>());
        expect(calls, ['getNFCAvailability']);
        expect(tester.takeException(), isNull);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );

  testWidgets('a pending native finish fences replacement iOS sessions', (
    tester,
  ) async {
    try {
      const service = BioPayNfcService();
      final finish = Completer<Object?>();
      final tag = Completer<Object?>();
      final calls = <String>[];
      messenger.setMockMethodCallHandler(_kit, (call) {
        calls.add(call.method);
        return switch (call.method) {
          'poll' => tag.future,
          'finish' => finish.future,
          _ => kitDefault(call),
        };
      });
      final work = service
          .writeCard(_payload)
          .then<void>((_) {}, onError: (Object _) {});
      await tester.pump();
      unawaited(service.cancelActiveSession());
      await tester.pump(const Duration(seconds: 9));
      await expectLater(
        service.writeCard(_payload),
        throwsA(isA<BioPayNfcException>()),
      );
      expect(calls.where((c) => c == 'poll'), hasLength(1));
      expect(calls.where((c) => c == 'finish'), hasLength(1));
      tag.complete(await kitDefault(const MethodCall('poll')));
      finish.complete();
      await tester.pump();
      await work;
      expect(tester.takeException(), isNull);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  test('a lost physical write response is unknown and never retried', () async {
    var writes = 0;
    messenger.setMockMethodCallHandler(_kit, (call) {
      if (call.method == 'writeNDEF') {
        writes++;
        return Completer<Object?>().future;
      }
      return kitDefault(call);
    });
    await expectLater(
      _service.writeCard(_payload),
      throwsA(
        isA<MutationOutcomeUnknownException>().having(
          (e) => e.operation,
          'operation',
          'nfc_write_card',
        ),
      ),
    );
    expect(writes, 1);
  });

  test('a lost lock response is unknown after matching the card', () async {
    var locks = 0;
    messenger.setMockMethodCallHandler(_kit, (call) {
      if (call.method == 'makeNdefReadOnly') {
        locks++;
        return Completer<Object?>().future;
      }
      return kitDefault(call);
    });
    await expectLater(
      _service.lockVerifiedCard(_payload),
      throwsA(
        isA<MutationOutcomeUnknownException>().having(
          (e) => e.operation,
          'operation',
          'nfc_lock_card',
        ),
      ),
    );
    expect(locks, 1);
  });

  test(
    'read-back deadline stops the retry loop while native read may remain active',
    () async {
      var reads = 0;
      messenger.setMockMethodCallHandler(_kit, (call) {
        if (call.method == 'readNDEF') {
          reads++;
          return Completer<Object?>().future;
        }
        return kitDefault(call);
      });
      await expectLater(
        _service.writeCard(_payload),
        throwsA(isA<MutationOutcomeUnknownException>()),
      );
      expect(reads, 1);
    },
  );

  testWidgets('cleanup timeout cannot relabel a verified write as failed', (
    tester,
  ) async {
    try {
      // Keep the real service budgets. Only the deliberately held cleanup phase
      // advances the fake clock, so CPU load cannot time out the preceding write
      // or its required read-back before this assertion is exercised.
      const service = BioPayNfcService();
      final finish = Completer<Object?>();
      final calls = <String>[];
      messenger.setMockMethodCallHandler(_kit, (call) {
        calls.add(call.method);
        return call.method == 'finish' ? finish.future : kitDefault(call);
      });
      BioPayNfcWriteResult? result;
      Object? operationError;
      final observation = service
          .writeCard(_payload)
          .then<void>(
            (value) => result = value,
            onError: (Object error) => operationError = error,
          );
      await tester.pump();
      expect(calls, [
        'getNFCAvailability',
        'poll',
        'writeNDEF',
        'readNDEF',
        'finish',
      ]);
      expect(operationError, isNull);
      expect(result, isNull);
      await tester.pump(const Duration(seconds: 7));
      expect(result, isNull);
      await tester.pump(const Duration(seconds: 1));
      await observation;
      expect(operationError, isNull);
      expect(result!.verified, isTrue);
      expect(result!.readBack!.semanticallyMatches(_payload), isTrue);
      expect(calls.where((method) => method == 'writeNDEF'), hasLength(1));
      expect(calls.where((method) => method == 'finish'), hasLength(1));
      final verifiedResult = result;
      finish.complete();
      await tester.pump();
      expect(result, same(verifiedResult));
      expect(operationError, isNull);
    } finally {
      // Widget tests validate debug globals before ordinary tearDown runs.
      debugDefaultTargetPlatformOverride = null;
    }
  });

  test(
    'Android native timeout stays unknown and never invokes a replacement write',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      var writes = 0;
      messenger.setMockMethodCallHandler(_kit, kitDefault);
      messenger.setMockMethodCallHandler(_writer, (call) {
        writes++;
        return Completer<Object?>().future;
      });
      await expectLater(
        _service.writeCard(_payload),
        throwsA(isA<MutationOutcomeUnknownException>()),
      );
      expect(writes, 1);
    },
  );

  test(
    'Android timeout error may race a physical mutation and stays unknown',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      messenger.setMockMethodCallHandler(_kit, kitDefault);
      messenger.setMockMethodCallHandler(_writer, (_) async {
        throw PlatformException(code: 'NFC_TIMEOUT');
      });
      await expectLater(
        _service.lockVerifiedCard(_payload),
        throwsA(isA<MutationOutcomeUnknownException>()),
      );
    },
  );

  test(
    'Android explicit preflight rejection remains a known unsupported error',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      messenger.setMockMethodCallHandler(_kit, kitDefault);
      messenger.setMockMethodCallHandler(_writer, (_) async {
        throw PlatformException(code: 'NFC_NOT_WRITABLE');
      });
      await expectLater(
        _service.writeCard(_payload),
        throwsA(isA<BioPayNfcException>()),
      );
    },
  );

  test('cancel and finish cleanup both have finite waits', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final calls = <String>[];
    messenger.setMockMethodCallHandler(_writer, (call) {
      calls.add(call.method);
      return Completer<Object?>().future;
    });
    messenger.setMockMethodCallHandler(_kit, (call) {
      calls.add(call.method);
      return Completer<Object?>().future;
    });
    await _service.cancelActiveSession();
    expect(calls, ['cancel', 'finish']);
  });
}
