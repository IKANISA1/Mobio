import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobi_app/core/async/account_epoch.dart';
import 'package:mobi_app/core/errors/app_exception.dart';
import 'package:mobi_app/features/biopay/data/biopay_device_nfc_service.dart';
import 'package:mobi_app/features/biopay/domain/biopay_ussd_payment.dart';

void main() {
  const channel = MethodChannel('rw.mobi.app/biopay_device_nfc');
  const service = BioPayDeviceNfcService();
  BioPayUssdPaymentRequest request(String id) => BioPayUssdPaymentRequest(
    id: id,
    token: id,
    channel: BioPayRequestChannel.nfc,
    providerCode: 'mtn_rw',
    payeeLabel: 'Receiver',
    amountMinor: 150000,
    currency: 'RWF',
    reference: id,
    ussdCode: '*182*1*1*0788123456*1500#',
    status: BioPayRequestStatus.readyToDial,
    expiresAt: DateTime.now().add(const Duration(minutes: 30)),
  );
  Future<Object> observed(Future<BioPayDeviceNfcStatus> work) =>
      work.then<Object>((value) => value, onError: (Object error) => error);

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  group('BioPayDeviceNfcService', () {
    for (final clamp in [false, true]) {
      testWidgets(
        'active start correlates token and ${clamp ? 'native clamped' : 'requested'} expiry',
        (tester) async {
          final original = request('A');
          final expiry = clamp
              ? DateTime.now().add(const Duration(minutes: 5))
              : DateTime.fromMillisecondsSinceEpoch(
                  original.expiresAt!.millisecondsSinceEpoch,
                  isUtc: true,
                );
          tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            channel,
            (call) async => {
              'supported': true,
              'enabled': true,
              'token': original.token,
              'expiresAt': expiry.toIso8601String(),
            },
          );
          final result = observed(service.startPaymentRequest(original));
          await tester.pump();
          expect((await result as BioPayDeviceNfcStatus).canAdvertise, isTrue);
        },
      );
    }
    for (final invalid in [
      'missing token',
      'wrong token',
      'missing expiry',
      'invalid expiry',
      'mistyped expiry',
      'extended expiry',
      'expired expiry',
      'unsupported active',
    ]) {
      testWidgets('unusable active start remains uncertain: $invalid', (
        tester,
      ) async {
        final original = request('A');
        final reply = <String, Object?>{
          'supported': true,
          'enabled': true,
          'token': original.token,
          'expiresAt': DateTime.now()
              .add(const Duration(minutes: 5))
              .toIso8601String(),
        };
        switch (invalid) {
          case 'missing token':
            reply.remove('token');
          case 'wrong token':
            reply['token'] = 'B';
          case 'missing expiry':
            reply.remove('expiresAt');
          case 'invalid expiry':
            reply['expiresAt'] = 'unparseable';
          case 'mistyped expiry':
            reply['expiresAt'] = 42;
          case 'extended expiry':
            reply['expiresAt'] = original.expiresAt!
                .add(const Duration(seconds: 1))
                .toIso8601String();
          case 'expired expiry':
            reply['expiresAt'] = DateTime.now()
                .subtract(const Duration(seconds: 1))
                .toIso8601String();
          case 'unsupported active':
            reply['supported'] = false;
        }
        var calls = 0;
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          (call) async {
            calls++;
            return reply;
          },
        );
        final result = observed(service.startPaymentRequest(original));
        await tester.pump();
        expect(
          await result,
          isA<MutationOutcomeUnknownException>().having(
            (error) => error.operationId,
            'original request ID',
            original.id,
          ),
        );
        expect(calls, 1);
      });
    }
    testWidgets('stop acknowledgement must confirm advertisement disabled', (
      tester,
    ) async {
      var calls = 0;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
        call,
      ) async {
        calls++;
        return {
          'supported': true,
          'enabled': true,
          'token': 'A',
          'expiresAt': DateTime.now()
              .add(const Duration(minutes: 5))
              .toIso8601String(),
        };
      });
      final stopped = observed(service.stop());
      await tester.pump();
      expect(await stopped, isA<MutationOutcomeUnknownException>());
      expect(calls, 1);
    });
    testWidgets('known unsupported or disabled native state stays known', (
      tester,
    ) async {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        (call) async => {
          'supported': false,
          'enabled': false,
          'token': null,
          'expiresAt': null,
        },
      );
      final result = observed(service.startPaymentRequest(request('A')));
      await tester.pump();
      expect((await result as BioPayDeviceNfcStatus).supported, isFalse);
      final stopped = observed(service.stop());
      await tester.pump();
      expect((await stopped as BioPayDeviceNfcStatus).enabled, isFalse);
    });
    for (final reply in [
      null,
      42,
      <Object>[],
      <String, Object?>{},
      <String, Object?>{'supported': 'true', 'enabled': false},
    ]) {
      testWidgets(
        'unusable mutation acknowledgement remains uncertain: $reply',
        (tester) async {
          var calls = 0;
          tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            channel,
            (call) async {
              calls++;
              return reply;
            },
          );
          final result = observed(service.startPaymentRequest(request('A')));
          await tester.pump();
          expect(
            await result,
            isA<MutationOutcomeUnknownException>().having(
              (error) => error.operationId,
              'original request ID',
              'A',
            ),
          );
          expect(calls, 1);
          final stopped = observed(service.stop());
          await tester.pump();
          expect(await stopped, isA<MutationOutcomeUnknownException>());
          expect(calls, 2);
        },
      );
    }

    testWidgets('late timed out start stays ahead of stop and newer start', (
      tester,
    ) async {
      final heldStart = Completer<Map<String, Object?>>();
      final calls = <String>[];
      String? advertised;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
        call,
      ) async {
        if (call.method == 'start') {
          final token = (call.arguments as Map)['token'] as String;
          calls.add('start:$token');
          if (token == 'A') await heldStart.future;
          advertised = token;
        } else {
          calls.add(call.method);
          advertised = null;
        }
        return {
          'supported': true,
          'enabled': advertised != null,
          'token': advertised,
          'expiresAt': advertised == null
              ? null
              : DateTime.now()
                    .add(const Duration(minutes: 5))
                    .toIso8601String(),
        };
      });
      final old = observed(service.startPaymentRequest(request('A')));
      await tester.pump();
      await tester.pump(const Duration(seconds: 6));
      expect(await old, isA<MutationOutcomeUnknownException>());
      final stopped = observed(service.stop());
      final newer = observed(service.startPaymentRequest(request('B')));
      await tester.pump();
      expect(calls, ['start:A']);
      heldStart.complete({});
      await tester.pump();
      expect(await stopped, isA<BioPayDeviceNfcStatus>());
      expect((await newer as BioPayDeviceNfcStatus).token, 'B');
      expect(calls, ['start:A', 'stop', 'start:B']);
      expect(advertised, 'B');
    });

    testWidgets(
      'stop still retires late start after its own observer expires',
      (tester) async {
        final heldStart = Completer<void>();
        final calls = <String>[];
        var advertising = false;
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          (call) async {
            calls.add(call.method);
            if (call.method == 'start') {
              await heldStart.future;
              advertising = true;
            } else {
              advertising = false;
            }
            return {'supported': true, 'enabled': true};
          },
        );
        final start = observed(service.startPaymentRequest(request('A')));
        await tester.pump();
        final stop = observed(service.stop());
        await tester.pump(const Duration(seconds: 6));
        expect(await start, isA<MutationOutcomeUnknownException>());
        expect(await stop, isA<MutationOutcomeUnknownException>());
        expect(calls, ['start']);
        heldStart.complete();
        await tester.pump();
        expect(calls, ['start', 'stop']);
        expect(advertising, isFalse);
      },
    );

    testWidgets('queued start whose observer expired never reaches native', (
      tester,
    ) async {
      final heldStart = Completer<void>();
      final calls = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
        call,
      ) async {
        calls.add('${call.method}:${(call.arguments as Map?)?['token']}');
        if (call.method == 'start') await heldStart.future;
        return {'supported': true, 'enabled': false};
      });
      final old = observed(service.startPaymentRequest(request('A')));
      await tester.pump();
      final queued = observed(service.startPaymentRequest(request('B')));
      final stop = observed(service.stop());
      await tester.pump(const Duration(seconds: 6));
      expect(await old, isA<MutationOutcomeUnknownException>());
      expect(await queued, isA<MutationOutcomeUnknownException>());
      expect(await stop, isA<MutationOutcomeUnknownException>());
      heldStart.complete();
      await tester.pump();
      expect(calls, ['start:A', 'stop:null']);
    });

    testWidgets('queued mutation rechecks its original authority at dispatch', (
      tester,
    ) async {
      final heldStart = Completer<void>();
      final calls = <String>[];
      var current = true;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
        call,
      ) async {
        calls.add('${call.method}:${(call.arguments as Map?)?['token']}');
        if ((call.arguments as Map?)?['token'] == 'A') await heldStart.future;
        return {
          'supported': true,
          'enabled': true,
          'token': (call.arguments as Map?)?['token'],
          'expiresAt': DateTime.now()
              .add(const Duration(minutes: 5))
              .toIso8601String(),
        };
      });
      final old = observed(service.startPaymentRequest(request('A')));
      await tester.pump();
      final staleStart = observed(
        service.startPaymentRequest(request('B'), canDispatch: () => current),
      );
      final staleStop = observed(service.stop(canDispatch: () => current));
      current = false;
      heldStart.complete();
      await tester.pump();
      expect(await old, isA<BioPayDeviceNfcStatus>());
      expect(await staleStart, isA<StaleAccountWork>());
      expect(await staleStop, isA<StaleAccountWork>());
      expect(calls, ['start:A']);
    });

    test('builds a direct MoMo USSD tel URI for Android HCE advertisement', () {
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

      expect(payload, 'tel:*182*1*1*0788123456*1500%23');
      expect(payload, isNot(contains('receiver=')));
      expect(payload, isNot(contains('mobio.ikanisa.com')));
    });

    test('extracts tel USSD payload from APDU response payload', () {
      const uri = 'tel:*182*1*1*0788123456*1500%23';
      final payloadHex = utf8
          .encode(uri)
          .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
          .join();
      final response = '${payloadHex}9000';

      expect(deviceNfcPayloadFromApduResponse(response), uri);
      expect(deviceNfcTokenFromApduResponse(response), isEmpty);
    });
  });
}
