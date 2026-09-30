import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobi_app/app/app.dart';
import 'package:mobi_app/app/app_providers.dart';
import 'package:mobi_app/app/theme_provider.dart';
import 'package:mobi_app/features/biopay/presentation/payment_composer_screen.dart';
import 'package:mobi_app/features/biopay/presentation/payment_link_arrival_screen.dart';

void main() {
  testWidgets('cold-start app link stays on the public request preview', (
    tester,
  ) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    const link =
        'https://mobio.ikanisa.com/biopay/pay/ABCDEFGHIJKLMNOPQRSTUVWX';
    const messages = MethodChannel('com.llfbandit.app_links/messages');
    const events = MethodChannel('com.llfbandit.app_links/events');
    const nfcWriter = MethodChannel('rw.mobi.app/biopay_nfc_writer');
    const nfcKit = MethodChannel('flutter_nfc_kit/method');
    const nfcReader = MethodChannel('rw.mobi.app/biopay_native_nfc_reader');
    const deviceNfc = MethodChannel('rw.mobi.app/biopay_device_nfc');
    final messenger = tester.binding.defaultBinaryMessenger
      ..setMockMethodCallHandler(messages, (call) async {
        return call.method == 'getInitialLink' ? link : null;
      })
      ..setMockMethodCallHandler(events, (_) async => null)
      ..setMockMethodCallHandler(nfcWriter, (_) async => null)
      ..setMockMethodCallHandler(
        nfcKit,
        (call) async =>
            call.method == 'getNFCAvailability' ? 'not_supported' : null,
      )
      ..setMockMethodCallHandler(nfcReader, (_) async => null)
      ..setMockMethodCallHandler(
        deviceNfc,
        (_) async => {'supported': false, 'enabled': false},
      );
    addTearDown(() {
      messenger
        ..setMockMethodCallHandler(messages, null)
        ..setMockMethodCallHandler(events, null)
        ..setMockMethodCallHandler(nfcWriter, null)
        ..setMockMethodCallHandler(nfcKit, null)
        ..setMockMethodCallHandler(nfcReader, null)
        ..setMockMethodCallHandler(deviceNfc, null);
    });
    final theme = ThemeProvider();
    addTearDown(theme.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [themeProviderProvider.overrideWithValue(theme)],
        child: const MobiMainApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(PaymentLinkArrivalScreen), findsOneWidget);
    expect(find.byType(PaymentComposerScreen), findsNothing);
    expect(find.textContaining('Request unavailable'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}
