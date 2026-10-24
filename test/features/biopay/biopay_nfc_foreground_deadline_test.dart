import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobi_app/features/biopay/presentation/biopay_nfc_foreground_listener.dart';

void main() {
  testWidgets('iOS launch, every routed child and resume stay NFC passive', (
    tester,
  ) async {
    const reader = MethodChannel('rw.mobi.app/biopay_native_nfc_reader');
    const device = MethodChannel('rw.mobi.app/biopay_device_nfc');
    const kit = MethodChannel('flutter_nfc_kit/method');
    const links = MethodChannel('com.llfbandit.app_links/messages');
    const events = MethodChannel('com.llfbandit.app_links/events');
    final calls = <String>[];
    final messenger = tester.binding.defaultBinaryMessenger;
    for (final channel in [reader, device, kit]) {
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add('${channel.name}:${call.method}');
        return null;
      });
    }
    messenger.setMockMethodCallHandler(links, (_) async => null);
    messenger.setMockMethodCallHandler(events, (_) async => null);
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      for (final route in [
        '/login',
        '/home',
        '/profile',
        '/admin',
        '/biopay',
      ]) {
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: BioPayNfcForegroundListener(child: Text(route)),
            ),
          ),
        );
        await tester.pump();
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        await tester.pump();
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pump();
        expect(find.text(route), findsOneWidget);
        expect(calls, isEmpty);
      }
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      expect(calls, isEmpty);
      expect(tester.takeException(), isNull);
    } finally {
      debugDefaultTargetPlatformOverride = null;
      for (final channel in [reader, device, kit, links, events]) {
        messenger.setMockMethodCallHandler(channel, null);
      }
    }
  });

  test('old route cleanup cannot release a newer NFC suspension', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(
      bioPayNfcForegroundSuspendedProvider.notifier,
    );
    final old = notifier.acquireSuspension();
    final current = notifier.acquireSuspension();
    expect(notifier.ownsSuspension(old), isFalse);
    expect(notifier.ownsSuspension(current), isTrue);
    notifier.releaseSuspension(old);
    expect(container.read(bioPayNfcForegroundSuspendedProvider), isTrue);
    notifier.releaseSuspension(current);
    expect(container.read(bioPayNfcForegroundSuspendedProvider), isFalse);
    expect(notifier.ownsSuspension(current), isFalse);
    expect(notifier.isCurrentSuspensionLease(current), isTrue);
    final replacement = notifier.acquireSuspension();
    expect(notifier.isCurrentSuspensionLease(current), isFalse);
    expect(notifier.isCurrentSuspensionLease(replacement), isTrue);
  });

  for (final end in ['background', 'dispose']) {
    testWidgets(
      'late native reader start respects $end after observer deadline',
      (tester) async {
        const reader = MethodChannel('rw.mobi.app/biopay_native_nfc_reader');
        const device = MethodChannel('rw.mobi.app/biopay_device_nfc');
        const kit = MethodChannel('flutter_nfc_kit/method');
        const links = MethodChannel('com.llfbandit.app_links/messages');
        const events = MethodChannel('com.llfbandit.app_links/events');
        final pending = Completer<void>();
        var starts = 0;
        var stops = 0;
        final messenger = tester.binding.defaultBinaryMessenger;
        messenger.setMockMethodCallHandler(reader, (call) {
          if (call.method == 'start') {
            starts++;
            return pending.future;
          }
          if (call.method == 'stop') stops++;
          return Future<Object?>.value();
        });
        messenger.setMockMethodCallHandler(
          device,
          (_) async => {'supported': false, 'enabled': false},
        );
        messenger.setMockMethodCallHandler(
          kit,
          (call) async =>
              call.method == 'getNFCAvailability' ? 'not_supported' : null,
        );
        messenger.setMockMethodCallHandler(links, (_) async => null);
        messenger.setMockMethodCallHandler(events, (_) async => null);
        addTearDown(() {
          for (final channel in [reader, device, kit, links, events]) {
            messenger.setMockMethodCallHandler(channel, null);
          }
        });
        await tester.pumpWidget(
          const ProviderScope(
            child: MaterialApp(
              home: BioPayNfcForegroundListener(child: SizedBox.shrink()),
            ),
          ),
        );
        await tester.pump();
        expect(starts, 1);
        await tester.pump(const Duration(seconds: 5));
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pump();
        expect(starts, 1);
        if (end == 'dispose') {
          await tester.pumpWidget(const SizedBox.shrink());
        } else {
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.inactive,
          );
        }
        await tester.pump();
        final stopsBeforeLateReply = stops;
        pending.complete();
        await tester.pumpAndSettle();
        expect(starts, 1);
        expect(stops, stopsBeforeLateReply + 1);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
      },
    );
  }
}
