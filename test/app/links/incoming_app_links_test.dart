import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobi_app/app/incoming_app_links.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('admits generated/legacy invites and both supported NFC origins', () {
    for (final raw in [
      'https://mobio.ikanisa.com/invite/MOBI482913',
      'https://mobio.ikanisa.com/invite/482913',
      'https://mobio.ikanisa.com/?ref=mobi482913',
    ]) {
      expect(parseIncomingAppLink(Uri.parse(raw)), isA<IncomingInvite>());
    }
    for (final raw in [
      'mobio://biopay/nfc?type=momo_pay_code&receiver=123456',
      'https://mobio.ikanisa.com/biopay/nfc?type=momo_number&receiver=0781234567',
      'https://mobio.ikanisa.com/biopay/pay/ABCDEFGHIJKLMNOPQRSTUVWX',
    ]) {
      expect(parseIncomingAppLink(Uri.parse(raw)), isA<IncomingPayment>());
    }
  });
  for (final raw in [
    'https://evil.invalid/invite/MOBI482913',
    'https://mobio.ikanisa.com.evil/invite/MOBI482913',
    'https://user@mobio.ikanisa.com/invite/MOBI482913',
    'https://mobio.ikanisa.com:444/invite/MOBI482913',
    'http://mobio.ikanisa.com/invite/MOBI482913',
    'mobio://invite/MOBI482913',
    'https://mobio.ikanisa.com/invite/MOBI482913/extra',
    'https://mobio.ikanisa.com/invite/MOBI482913#fragment',
    'https://mobio.ikanisa.com/?ref=one&ref=two',
    'https://mobio.ikanisa.com/?ref=one&code=two',
    'https://mobio.ikanisa.com/biopay/pay/ABCDEFGHIJKLMNOPQRSTUVWX?ref=one',
    'mobio://biopay/nfc?type=momo_pay_code&receiver=not-a-code',
  ]) {
    test(
      'rejects $raw',
      () => expect(parseIncomingAppLink(Uri.parse(raw)), isNull),
    );
  }
  test(
    'buffers in order, deduplicates normalized arrival and permits later reopen',
    () async {
      var now = DateTime.utc(2026);
      final links = StreamController<Uri>();
      final coordinator = IncomingAppLinks(
        links: () => links.stream,
        now: () => now,
      );
      coordinator.start();
      coordinator.start();
      coordinator.receive(
        Uri.parse('https://mobio.ikanisa.com/invite/mobi482913'),
      );
      coordinator.receive(
        Uri.parse('https://mobio.ikanisa.com/?ref=MOBI482913'),
      );
      final seen = <String>[];
      final pending = Completer<void>();
      final detach = coordinator.attach((intent) async {
        seen.add(intent.identity);
        if (seen.length == 1) await pending.future;
      });
      coordinator.receive(Uri.parse('https://mobio.ikanisa.com/invite/482914'));
      expect(seen, ['invite:MOBI482913']);
      pending.complete();
      await Future<void>.delayed(Duration.zero);
      expect(seen, ['invite:MOBI482913', 'invite:482914']);
      now = now.add(const Duration(seconds: 3));
      coordinator.receive(
        Uri.parse('https://mobio.ikanisa.com/invite/MOBI482913'),
      );
      await Future<void>.delayed(Duration.zero);
      expect(seen.length, 3);
      detach();
      await coordinator.dispose();
      await links.close();
    },
  );
  testWidgets('one real EventChannel owns cold/warm receipt and cancels once', (
    tester,
  ) async {
    const events = MethodChannel('com.llfbandit.app_links/events');
    final messenger = tester.binding.defaultBinaryMessenger;
    var listens = 0, cancels = 0;
    messenger.setMockMethodCallHandler(events, (call) async {
      if (call.method == 'listen') listens++;
      if (call.method == 'cancel') cancels++;
      return null;
    });
    final coordinator = IncomingAppLinks();
    coordinator.start();
    coordinator.start();
    await tester.pump();
    Future<void> deliver(String path) async {
      messenger.handlePlatformMessage(
        events.name,
        const StandardMethodCodec().encodeSuccessEnvelope(
          'https://mobio.ikanisa.com/$path',
        ),
        (_) {},
      );
      await tester.pump();
    }

    await deliver('invite/MOBI482913');
    final seen = <String>[];
    final detach = coordinator.attach((intent) async {
      seen.add(intent.identity);
    });
    await tester.pump();
    await deliver('invite/MOBI482913');
    await deliver('biopay/pay/ABCDEFGHIJKLMNOPQRSTUVWX');
    expect(listens, 1);
    expect(seen, [
      'invite:MOBI482913',
      'payment:https://mobio.ikanisa.com/biopay/pay/ABCDEFGHIJKLMNOPQRSTUVWX',
    ]);
    detach();
    await tester.runAsync(coordinator.dispose);
    await tester.pump();
    expect(cancels, 1);
    await deliver('invite/482914');
    expect(seen.length, 2);
    messenger.setMockMethodCallHandler(events, null);
  });
  test(
    'bounded queue rejects overflow without replacing retained arrivals',
    () async {
      final coordinator = IncomingAppLinks(
        links: () => const Stream<Uri>.empty(),
      );
      for (var i = 0; i < 33; i++)
        coordinator.receive(Uri.parse('https://mobio.ikanisa.com/invite/C$i'));
      final seen = <String>[];
      coordinator.attach((intent) async {
        seen.add(intent.identity);
      });
      await Future<void>.delayed(Duration.zero);
      expect(coordinator.rejectedArrivals, 1);
      expect(seen.length, 32);
      expect(seen.first, 'invite:C0');
      expect(seen.last, 'invite:C31');
      await coordinator.dispose();
    },
  );
}
