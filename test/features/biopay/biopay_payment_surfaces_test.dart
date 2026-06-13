import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobi_app/core/theme/app_theme.dart';
import 'package:mobi_app/features/biopay/biopay_screen.dart';
import 'package:mobi_app/features/biopay/models/biopay_ussd_payment.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../helpers/mobile_scanner_test_channel.dart';

void main() {
  setUpAll(installMobileScannerTestChannel);
  tearDownAll(uninstallMobileScannerTestChannel);

  testWidgets('BioPay home uses four two-by-two payment cards', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: BioPayScreen(
          onQr: () {},
          onScan: () {},
          onFace: () {},
          onNfc: () {},
        ),
      ),
    );

    final grid = tester.widget<GridView>(find.byType(GridView).first);
    final delegate =
        grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
    expect(delegate.crossAxisCount, 2);
    expect(find.text('Face Scan'), findsOneWidget);
    expect(find.text('NFC Tap'), findsOneWidget);
    expect(find.text('Get QR'), findsOneWidget);
    expect(find.text('Scan QR'), findsOneWidget);
  });

  testWidgets('QR surface generates a receiver QR code from entered details', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: BioPayQrScreen(onBack: () {}),
        ),
      ),
    );

    expect(find.text('Number'), findsOneWidget);
    expect(find.text('Code'), findsOneWidget);
    expect(find.text('AMOUNT'), findsOneWidget);
    expect(find.text('MoMo number / MoMo Pay code'), findsNothing);
    expect(find.text('Amount (RWF, optional)'), findsNothing);
    expect(find.text('No QR request'), findsNothing);

    await tester.enterText(find.byType(TextField).at(0), '0788767816');
    await tester.enterText(find.byType(TextField).at(1), '2500');
    await tester.ensureVisible(find.text('Generate QR Code'));
    await tester.tap(find.text('Generate QR Code'));
    await tester.pumpAndSettle();

    expect(find.text('Share QR Code'), findsOneWidget);
    expect(find.text('0788767816'), findsWidgets);
    expect(find.text('RWF 2,500'), findsOneWidget);
    expect(find.text('Dial USSD'), findsNothing);
    expect(find.textContaining('Token expires'), findsNothing);

    final request = tester.widgetList(find.byType(BioPayQrScreen)).isNotEmpty;
    expect(request, isTrue);
  });

  testWidgets('QR code tab shows the MoMo Pay code value', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: BioPayQrScreen(onBack: () {}),
        ),
      ),
    );

    await tester.tap(find.text('Code'));
    await tester.pump();

    expect(find.text('123456'), findsOneWidget);
    expect(find.text('+250788767816'), findsNothing);
  });

  testWidgets('QR number tab displays Rwanda local MoMo number format', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: BioPayQrScreen(onBack: () {}),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField).first, '250788767816');
    await tester.pump();

    expect(find.text('0788767816'), findsOneWidget);
    expect(find.text('250788767816'), findsNothing);
    expect(find.text('+250788767816'), findsNothing);
  });

  testWidgets('Face scan surface keeps redundant AWS helper label removed', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: BioPayFaceScanScreen(onBack: () {}),
        ),
      ),
    );

    expect(find.text('Face scan'), findsOneWidget);
    expect(find.text('Start Face Scan'), findsOneWidget);
    expect(find.text('AMOUNT'), findsOneWidget);
    expect(find.text('Amount (RWF, optional)'), findsNothing);
    expect(find.text('AWS face match'), findsNothing);
    expect(find.text('Capture with AWS face match'), findsNothing);
  });

  testWidgets('Scan surface is camera scanner only before QR detection', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: BioPayScanScreen(onBack: () {}),
        ),
      ),
    );

    expect(find.text('Scan'), findsOneWidget);
    expect(find.byType(MobileScanner), findsOneWidget);
    expect(find.text('Preview scan'), findsNothing);
    expect(find.text('Scanning'), findsNothing);
  });

  test('QR payload carries safe metadata and remains token-resolvable', () {
    const request = BioPayUssdPaymentRequest(
      id: 'request-1',
      token: 'mobio-biopay-token-1',
      channel: BioPayRequestChannel.qr,
      providerCode: 'mtn_rw',
      payeeLabel: 'BioPay merchant',
      amountMinor: 250000,
      currency: 'RWF',
      reference: 'BP-1',
      ussdCode: '*182*8*1*250788000000*2500#',
      status: BioPayRequestStatus.readyToDial,
    );
    final qrPayload = buildBioPayQrPayload(request);
    final payload = jsonDecode(qrPayload) as Map<String, dynamic>;
    expect(payload['type'], 'mobio_biopay_request');
    expect(payload['token'], 'mobio-biopay-token-1');
    expect(payload['payee_label'], 'BioPay merchant');
    expect(payload['amount_minor'], 250000);
    expect(payload.containsKey('ussd_code'), isFalse);
    expect(payload.values.join(' '), isNot(contains('*182')));
    expect(bioPayTokenFromPayload(qrPayload), 'mobio-biopay-token-1');
    expect(
      bioPayTokenFromPayload('mobio-biopay-token-1'),
      'mobio-biopay-token-1',
    );
    expect(
      bioPayTokenFromPayload(
        'https://mobi.rw/biopay?token=mobio-biopay-token-1',
      ),
      'mobio-biopay-token-1',
    );
  });
}
