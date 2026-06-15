import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobi_app/core/theme/app_colors.dart';
import 'package:mobi_app/core/theme/app_theme.dart';
import 'package:mobi_app/features/biopay/biopay_screen.dart';
import 'package:mobi_app/features/biopay/biopay_style.dart';
import 'package:mobi_app/features/biopay/models/biopay_ussd_payment.dart';
import 'package:mobi_app/shared/widgets/mobi_button.dart';
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
    expect(find.text('Pay & Get Paid'), findsOneWidget);
    expect(find.text('Instant & Secure'), findsOneWidget);
    final secondary = tester.widget<Text>(find.text('Instant & Secure'));
    expect(secondary.style?.color, AppColors.primaryFixedDim);
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
    expect(find.byType(BioPayIconBox), findsNothing);

    await tester.enterText(find.byType(TextField).at(0), '0788767816');
    await tester.enterText(find.byType(TextField).at(1), '2500');
    await tester.ensureVisible(find.text('Generate QR Code'));
    await tester.tap(find.text('Generate QR Code'));
    await tester.pumpAndSettle();

    expect(find.text('Generate QR Code'), findsNothing);
    expect(find.text('Save'), findsOneWidget);
    expect(find.text('Share'), findsOneWidget);
    expect(find.text('Share QR Code'), findsNothing);
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

  testWidgets('Device NFC surface does not write physical NFC cards', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: BioPayNfcScreen(onBack: () {}),
        ),
      ),
    );

    expect(find.text('Device NFC'), findsOneWidget);
    expect(find.text('Activate Device NFC'), findsOneWidget);
    expect(find.text('Write NFC Card'), findsNothing);
    expect(find.text('Write NFC'), findsNothing);
    expect(find.text('Receive with NFC'), findsNothing);
    expect(find.byType(BioPayIconBox), findsNothing);
  });

  testWidgets('Write NFC combines receiver mode and input into one card', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: BioPayNfcWriteCardScreen(onBack: () {}),
        ),
      ),
    );

    expect(find.text('Write NFC'), findsWidgets);
    expect(find.text('Write & Lock NFC'), findsNothing);
    expect(find.text('MoMo Number'), findsOneWidget);
    expect(find.text('MoMo Pay'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('NFC card writer'), findsNothing);

    var receiverField = tester.widget<TextField>(find.byType(TextField));
    expect(receiverField.decoration?.hintText, 'MoMo number');
    expect(receiverField.decoration?.border, InputBorder.none);
    expect(receiverField.decoration?.enabledBorder, InputBorder.none);
    expect(receiverField.decoration?.focusedBorder, InputBorder.none);

    await tester.tap(find.text('MoMo Pay'));
    await tester.pump();

    receiverField = tester.widget<TextField>(find.byType(TextField));
    expect(receiverField.decoration?.hintText, 'MoMo Pay code');
    expect(receiverField.decoration?.border, InputBorder.none);
  });

  testWidgets('Face scan surface keeps redundant AWS helper label removed', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

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
    expect(tester.getRect(find.text('Start Face Scan')).bottom, lessThan(844));
    expect(find.text('AMOUNT'), findsNothing);
    expect(find.text('Amount (RWF, optional)'), findsNothing);
    expect(find.text('AWS face match'), findsNothing);
    expect(find.text('Capture with AWS face match'), findsNothing);
    expect(find.byType(BioPayIconBox), findsNothing);
  });

  testWidgets(
    'Face enroll surface keeps redundant AWS liveness label removed',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: BioPayFaceEnrollScreen(onBack: () {}),
          ),
        ),
      );

      expect(find.text('Face enroll'), findsOneWidget);
      expect(find.text('Start Enrollment'), findsOneWidget);
      expect(find.byType(MobiButton), findsOneWidget);
      expect(find.text('AWS liveness session'), findsNothing);
      expect(find.byType(BioPayIconBox), findsNothing);
    },
  );

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
    expect(find.byType(BioPayIconBox), findsNothing);
  });

  test(
    'QR payload uses MoMo tel USSD format and token QR remains readable',
    () {
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
      expect(qrPayload, 'tel:*182*8*1*250788000000*2500%23');
      expect(
        bioPayUssdCodeFromPayload(qrPayload),
        '*182*8*1*250788000000*2500#',
      );
      expect(
        bioPayUssdCodeFromPayload('*182*8*1*250788000000*2500#'),
        '*182*8*1*250788000000*2500#',
      );
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
    },
  );
}
