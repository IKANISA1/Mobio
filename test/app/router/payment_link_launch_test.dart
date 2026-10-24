import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mobi_app/app/app.dart';
import 'package:mobi_app/app/incoming_app_links.dart';
import 'package:mobi_app/app/app_providers.dart';
import 'package:mobi_app/app/theme_provider.dart';
import 'package:mobi_app/features/biopay/application/biopay_providers.dart';
import 'package:mobi_app/features/biopay/presentation/payment_composer_screen.dart';
import 'package:mobi_app/features/biopay/presentation/payment_link_arrival_screen.dart';
import 'package:mobi_app/features/biopay/presentation/payment_widgets.dart';

import '../../helpers/payment_discovery_fixture.dart';

class _PublicPreview extends PaymentDiscoveryFixture {
  _PublicPreview({required this.readFailure}) {
    ownerId = null;
  }

  final bool readFailure;
  final tokens = <String>[];

  @override
  Future<Map<String, dynamic>> previewLink(String token) async {
    tokens.add(token);
    if (readFailure) throw TimeoutException('Synthetic offline request');
    return {'available': false};
  }
}

void main() {
  for (final readFailure in [false, true]) {
    testWidgets(
      'cold-start app link keeps ${readFailure ? 'read failure' : 'unavailable request'} on the public preview',
      (tester) async {
        tester.view
          ..devicePixelRatio = 1
          ..physicalSize = const Size(390, 844);
        addTearDown(tester.view.reset);
        const link =
            'https://mobio.ikanisa.com/biopay/pay/ABCDEFGHIJKLMNOPQRSTUVWX';
        final preview = _PublicPreview(readFailure: readFailure);
        const messages = MethodChannel('com.llfbandit.app_links/messages');
        const events = MethodChannel('com.llfbandit.app_links/events');
        const nfcWriter = MethodChannel('rw.mobi.app/biopay_nfc_writer');
        const nfcKit = MethodChannel('flutter_nfc_kit/method');
        const nfcReader = MethodChannel('rw.mobi.app/biopay_native_nfc_reader');
        const deviceNfc = MethodChannel('rw.mobi.app/biopay_device_nfc');
        final messenger = tester.binding.defaultBinaryMessenger;
        messenger
          ..setMockMethodCallHandler(messages, (call) async {
            return call.method == 'getInitialLink' ? link : null;
          })
          ..setMockMethodCallHandler(events, (call) async {
            if (call.method == 'listen') {
              Future<void>.microtask(
                () => messenger.handlePlatformMessage(
                  events.name,
                  const StandardMethodCodec().encodeSuccessEnvelope(link),
                  (_) {},
                ),
              );
            }
            return null;
          })
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
        final links = IncomingAppLinks();
        addTearDown(links.dispose);
        final theme = ThemeProvider();
        addTearDown(theme.dispose);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              themeProviderProvider.overrideWithValue(theme),
              incomingAppLinksProvider.overrideWithValue(links),
              paymentDiscoveryServiceProvider.overrideWithValue(preview),
            ],
            child: const MobiMainApp(),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(PaymentLinkArrivalScreen), findsOneWidget);
        expect(find.byType(PaymentComposerScreen), findsNothing);
        final arrivalContext = tester.element(
          find.byType(PaymentLinkArrivalScreen),
        );
        final copy = paymentCopy(arrivalContext);
        expect(
          GoRouter.of(arrivalContext).routeInformationProvider.value.uri.path,
          '/biopay/pay/ABCDEFGHIJKLMNOPQRSTUVWX',
        );
        expect(preview.tokens, isNotEmpty);
        expect(preview.tokens, everyElement('ABCDEFGHIJKLMNOPQRSTUVWX'));
        expect(find.byType(PaymentError), findsOneWidget);
        expect(
          find.text(copy.bpLinkUnavailable),
          readFailure ? findsNothing : findsOneWidget,
        );
        expect(
          find.text(copy.errorGeneric),
          readFailure ? findsOneWidget : findsNothing,
        );
        expect(
          find.text(copy.tryAgain),
          readFailure ? findsOneWidget : findsNothing,
        );
        expect(find.text(copy.bpContinue), findsNothing);
        expect(find.text(copy.bpSignIn), findsNothing);
        expect(find.text(copy.bpManual), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      },
    );
  }
}
